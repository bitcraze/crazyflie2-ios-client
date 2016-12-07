//
//  Bootloader.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 29/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation

func decodeUint16(_ data:[UInt8], offset:Int) -> Int {
    let lsb = Int(data[offset])
    let msb = Int(data[offset+1])
    return (msb<<8)+lsb
}

class Bootloader {
    func formatTimeInterval(_ interval: TimeInterval) -> String {
        var result  = ""
        var scaledInterval: TimeInterval
        
        if interval > 3600 {
            result += "\(Int(interval/3600)):"
            scaledInterval = interval.truncatingRemainder(dividingBy: 3600)
        } else {
            scaledInterval = interval
        }
        
        result += NSString(format: "%02d:%02d", Int(scaledInterval/60), Int(scaledInterval.truncatingRemainder(dividingBy: 60))) as String
        
        return result
    }
    
    enum State {
        case idle
        case fetchingNrfInfo
        case fetchingStmInfo
        case flashing (Target, Int, Double, String, Int, Int)
        
        var description: String {
            get {
                switch self {
                case .idle:
                    return "doing nothing(!)"
                case .fetchingNrfInfo:
                    return "fetching NRF51 Info"
                case .fetchingStmInfo:
                    return "fetching STM32 Info"
                case .flashing(let target, _, let progress, let timeleft, let totalfw, let currentfw):
                    let percent = NSString(format: "%.2f", 100*progress)
                    return "Flashing target \(currentfw)/\(totalfw) \(target.name): \(percent)% Time left: \(timeleft)"
                }
            }
        }
    }
    
    enum FlashState {
        case load, flash (Int)
    }
    
    var state = State.idle {
        didSet {
            switch state {
            case .flashing(_,  _, let progress, _, _, _):
                self.callback?(false, Float(progress), self.state.description, nil)
            default:
                self.callback?(false, 0, self.state.description, nil)
            }
        }
    }
    
    var flashState: FlashState = .load
    
    var link: BluetoothLink
    
    lazy var wd: Watchdog = {
        return Watchdog(period: 1) {
            self.fail("Timeout while \(self.state.description)")
        }
    }()
    
    // process state
    var curr_fw = 0
    var total_fw = 0
    var curr_byte = 0
    var total_byte = 0
    var start_time = Date()
    
    fileprivate func calculateTimeLeft() -> String {
        let time = Date().timeIntervalSince(self.start_time)
        
        if time < 5 {
            return "Calculating ..."
        }
        
        let totalTime = (time * Double(self.total_byte)) / Double(self.curr_byte)
        
        return formatTimeInterval(totalTime - time)
    }
    
    init(link: BluetoothLink) {
        self.link = link
        self.link.rxCallback = self.onLinkRx
    }
    
    fileprivate func fail(_ message: String) {
        self.state = .idle
        self.wd.stop()
        let error = NSError(domain: "CrazyflieBoorloader", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        OperationQueue.main.addOperation() {
            self.callback?(true, 0.0, "Canceled", error)
        }
    }
    
    fileprivate func done() {
        self.state = .idle
        self.wd.stop()
        OperationQueue.main.addOperation() {
            self.callback?(true, 0.0, "Done", nil)
        }
    }
    
    func cancel() {
        self.fail("Update canceled")
    }

    // MARK: Bootloader data structures
    
    /**
        Bootloader info packet structure.
    */
    struct Info {
        let pageSize: Int
        let nBuffPage: Int
        let nFlashPage: Int
        let flashStart: Int
        let cpuId: [UInt8]
        let version: Int
        
        /**
            Decode the info packet into an info structure
            
            - parameter packet: Raw data packet including CRTP 0xFF and target number
        */
        init!(packet: [UInt8]) {
            let headerLength = 2
            
            if packet[headerLength+0] != 0x10 || packet.count < 23 {
                self.pageSize = 0
                self.nBuffPage = 0
                self.nFlashPage = 0
                self.flashStart = 0
                self.cpuId = []
                self.version = 0
                return nil
            }
            
            self.pageSize = decodeUint16(packet, offset: headerLength + 1)
            self.nBuffPage = decodeUint16(packet, offset: headerLength + 3)
            self.nFlashPage = decodeUint16(packet, offset: headerLength + 5)
            self.flashStart = decodeUint16(packet, offset: headerLength + 7)
            self.cpuId = Array(packet[(headerLength+9)..<(headerLength+21)])
            
            if packet.count > 23 {
                self.version = Int(packet[23])
            } else if packet[1] == 0xfe {
                self.version = 0x10
            } else {
                self.version = 0
            }
            
        }
    }
    
    // Targets
    enum Target: UInt8 {
        case nrf51 = 0xfe
        case stm32 = 0xff
        
        var name :String {
            get {
                switch self {
                case .nrf51:
                    return "nrf51"
                case .stm32:
                    return "stm32"
                }
            }
        }
    }
    
    // Bootloader messages
    let getInfo: UInt8 = 0x10
    let loadBuffer: UInt8 = 0x14
    let writeFlash: UInt8 = 0x18
    
    var infos: [Target: Info] = [:]
    // MARK: Bootloader logic
    
    typealias CallbackType = (_ done: Bool, _ progress: Float, _ status: String, _ error: NSError?)->()
    
    fileprivate var callback: CallbackType? = nil
    
    var firmware: FirmwareImage! = nil
    
    func update(_ firmware: FirmwareImage, callback: @escaping CallbackType) {
        self.callback = callback
        self.firmware = firmware
        
        self.start_time = Date()
        self.total_fw = 0
        self.total_byte = 0
        if let fw = firmware.targetFirmwares["cf2-\(Target.nrf51.name)-fw"] {
            self.total_fw += 1
            self.total_byte += fw.count
        }
        if let fw = firmware.targetFirmwares["cf2-\(Target.stm32.name)-fw"] {
            self.total_fw += 1
            self.total_byte += fw.count
        }
        
        self.curr_byte = 0
        self.curr_fw = 0
        
        self.state = .fetchingNrfInfo
        let pk: [UInt8] = [0xff, 0xfe, 0x10]
        self.link.sendPacket(Data(bytes: UnsafePointer<UInt8>(pk), count: pk.count), callback: nil)
        
        self.wd.start()
    }
    
    func onLinkRx(_ packet: Data) {
        print("Packet received by bootloader \(packet.count) bytes")
        var packetArray = [UInt8](repeating: 0, count: packet.count)
        (packet as NSData).getBytes(&packetArray, length:packetArray.count)
        print(packetArray)
        
        if packetArray[0] != 255 {
            return
        }
        
        switch (Target(rawValue: packetArray[1]), packetArray[2], state) {
        case (.some(.nrf51), getInfo, .fetchingNrfInfo):
            print("Got NRF51 info")
            
            self.infos[.nrf51] = Info(packet: packetArray)
            if self.infos[.nrf51] == nil {
                self.fail("Malformed protocol answer (nrf51 info)")
            }
            
            
            self.wd.reset()
            self.state = .fetchingStmInfo
            let pk: [UInt8] = [0xff, Target.stm32.rawValue, getInfo]
            self.link.sendPacket(Data(bytes: UnsafePointer<UInt8>(pk), count: pk.count), callback: nil)
        case (.some(.stm32), getInfo, .fetchingStmInfo):
            print("Got STM32 info")
            
            self.infos[.stm32] = Info(packet: packetArray)
            if self.infos[.stm32] == nil {
                self.fail("Malformed protocol answer (stm32 info)")
            }
            
            self.state = .flashing(.nrf51, 0, 0.0, calculateTimeLeft(), self.total_fw, self.curr_fw)
            self.wd.reset()
            
            // Reset the timer to get an accurate measurement of the flash time
            self.start_time = Date()
            
            // Start flashing the first image ...
            self.startFlashing(.nrf51)
        case (.some, writeFlash, .flashing(let target, let pos, _, _, _, _)):
            print("Received flash status: \(packetArray[4])")
            if packetArray[3] != UInt8(1) {
                self.fail("Fail to flash. Error code: \(packetArray[4]).")
            } else {
                if pos >= self.currentFw.count {
                    if target == .nrf51 {
                        state = .flashing(.stm32, 0, 0.0, calculateTimeLeft(), self.total_fw, self.curr_fw)
                        self.startFlashing(.stm32)
                    } else {
                        self.done()
                    }
                } else {
                    self.flashState = .load
                    self.continueFlashing()
                }
            }
        default:
            break
        }
    }
    
    var currentFw: [UInt8] = []
    fileprivate func startFlashing(_ target: Target) {
        
        let data = self.firmware.targetFirmwares["cf2-\(target.name)-fw"]
        self.flashState = .load
        
        if data == nil {
            if target == .nrf51 {
                state = .flashing(.stm32, 0, 0.0, calculateTimeLeft(), self.total_fw, self.curr_fw)
                self.startFlashing(.stm32)
                return
            } else {
                self.done()
            }
        }
        
        self.curr_fw += 1
        
        self.currentFw = [UInt8](repeating: 0, count: data!.count)
        (data! as NSData).getBytes(&self.currentFw, length: self.currentFw.count)
        
        self.continueFlashing()
    }
    
    func continueFlashing() {
        switch self.state {
        case .flashing(let target, let pos, _, _,  _, _):
            let currentPage = pos / self.infos[target]!.pageSize
            let currentBufferPage = 0
            let posInPage  = pos % self.infos[target]!.pageSize
            let currentPageSize = min(self.infos[target]!.pageSize, self.currentFw.count-(currentPage*self.infos[target]!.pageSize))
            let leftInPage = currentPageSize - posInPage
            let byteToSend = min(leftInPage, 13)
            
            switch self.flashState {
            case .load:
                print("Loading page from \(leftInPage)")
                
                var packet: [UInt8] = [0xff, target.rawValue, loadBuffer]
                packet = packet + [UInt8(currentBufferPage&0x00ff), UInt8(currentBufferPage>>8)]
                packet = packet + [UInt8(posInPage&0x00ff), UInt8(posInPage>>8)]
                packet = packet + Array(self.currentFw[pos..<(pos+byteToSend)])
                
                print(packet)
                if leftInPage-byteToSend == 0 {
                    self.flashState = .flash(currentPage)
                }
                
                let newPos = pos+byteToSend
                self.state = .flashing(target, newPos, Double(newPos)/Double(self.currentFw.count),
                                       calculateTimeLeft(), self.total_fw, self.curr_fw)
                
                self.curr_byte += byteToSend
                
                self.link.sendPacket(Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count)) { (success) in
                    print("Page loaded, continuing")
                    
                    self.wd.reset()
                    self.continueFlashing()
                }
            case .flash(let page):
                let pageToFlash = page + self.infos[target]!.flashStart
                
                print("Flashing to page \(page)")
                
                var packet: [UInt8] = [0xff, target.rawValue, writeFlash]
                packet = packet + [0, 0]
                packet = packet + [UInt8(pageToFlash&0x00ff), UInt8(pageToFlash>>8)]
                packet = packet + [1, 0]
                
                self.wd.reset(2)
                self.link.sendPacket(Data(bytes: UnsafePointer<UInt8>(packet), count: packet.count), callback: nil)
                
                self.flashState = .load
            }
            
        default:
            break
        }
    }
}
