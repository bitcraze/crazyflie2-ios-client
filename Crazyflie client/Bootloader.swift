//
//  Bootloader.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 29/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation

func decodeUint16(data:[UInt8], offset:Int) -> Int {
    let lsb = Int(data[offset])
    let msb = Int(data[offset+1])
    return (msb<<8)+lsb
}

class Bootloader {
    enum State {
        case Idle
        case FetchingNrfInfo
        case FetchingStmInfo
        case Flashing (Target, Int, Double)
        
        var description: String {
            get {
                switch self {
                case .Idle:
                    return "doing nothing(!)"
                case .FetchingNrfInfo:
                    return "fetching NRF51 Info"
                case .FetchingStmInfo:
                    return "fetching STM32 Info"
                case .Flashing(let target, let offset, let progress):
                    let percent = NSString(format: "%.2f", 100*progress)
                    return "Flashing target \(target.name): \(percent)%"
                }
            }
        }
    }
    
    enum FlashState {
        case Load, Flash (Int)
    }
    
    var state = State.Idle {
        didSet {
            switch state {
            case .Flashing(let _, let _, let progress):
                self.callback?(done: false, progress: Float(progress), status: self.state.description, error: nil)
            default:
                self.callback?(done: false, progress: 0, status: self.state.description, error: nil)
            }
        }
    }
    
    var flashState: FlashState = .Load
    
    var link: BluetoothLink
    
    lazy var wd: Watchdog = {
        return Watchdog(period: 1) {
            self.fail("Timeout while \(self.state.description)")
        }
    }()
    
    init(link: BluetoothLink) {
        self.link = link
        self.link.rxCallback = self.onLinkRx
    }
    
    private func fail(message: String) {
        self.state = .Idle
        self.wd.stop()
        let error = NSError(domain: "CrazyflieBoorloader", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.callback?(done: true, progress: 0.0, status: "Canceled", error: error)
        }
    }
    
    private func done() {
        self.state = .Idle
        self.wd.stop()
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.callback?(done: true, progress: 0.0, status: "Done", error: nil)
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
            
            :param: packet Raw data packet including CRTP 0xFF and target number
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
            
            self.pageSize = decodeUint16(packet, headerLength + 1)
            self.nBuffPage = decodeUint16(packet, headerLength + 3)
            self.nFlashPage = decodeUint16(packet, headerLength + 5)
            self.flashStart = decodeUint16(packet, headerLength + 7)
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
                case nrf51:
                    return "nrf51"
                case stm32:
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
    
    typealias CallbackType = (done: Bool, progress: Float, status: String, error: NSError?)->()
    
    private var callback: CallbackType? = nil
    
    var firmware: FirmwareImage! = nil
    
    func update(firmware: FirmwareImage, callback: CallbackType) {
        self.callback = callback
        self.firmware = firmware
        
        self.state = .FetchingNrfInfo
        let pk: [UInt8] = [0xff, 0xfe, 0x10]
        self.link.sendPacket(NSData(bytes: pk, length: pk.count), callback: nil)
        
        self.wd.start()
    }
    
    func onLinkRx(packet: NSData) {
        println("Packet received by bootloader \(packet.length) bytes")
        var packetArray = [UInt8](count: packet.length, repeatedValue: 0)
        packet.getBytes(&packetArray, length:packetArray.count)
        println(packetArray)
        
        if packetArray[0] != 255 {
            return
        }
        
        switch (Target(rawValue: packetArray[1]), packetArray[2], state) {
        case (.Some(.nrf51), getInfo, .FetchingNrfInfo):
            println("Got NRF51 info")
            
            self.infos[.nrf51] = Info(packet: packetArray)
            if self.infos[.nrf51] == nil {
                self.fail("Malformed protocol answer (nrf51 info)")
            }
            
            
            self.wd.reset()
            self.state = .FetchingStmInfo
            let pk: [UInt8] = [0xff, Target.stm32.rawValue, getInfo]
            self.link.sendPacket(NSData(bytes: pk, length: pk.count), callback: nil)
        case (.Some(.stm32), getInfo, .FetchingStmInfo):
            println("Got STM32 info")
            
            self.infos[.stm32] = Info(packet: packetArray)
            if self.infos[.stm32] == nil {
                self.fail("Malformed protocol answer (stm32 info)")
            }
            
            self.state = .Flashing(.nrf51, 0, 0.0)
            self.wd.reset()
            // Start flashing the first image ...
            self.startFlashing(.nrf51)
        case (.Some, writeFlash, .Flashing(let target, let pos, let percent)):
            println("Received flash status: \(packetArray[4])")
            if packetArray[3] != UInt8(1) {
                self.fail("Fail to flash. Error code: \(packetArray[4]).")
            } else {
                if pos >= self.currentFw.count {
                    if target == .nrf51 {
                        state = .Flashing(.stm32, 0, 0.0)
                        self.startFlashing(.stm32)
                    } else {
                        self.done()
                    }
                } else {
                    self.flashState = .Load
                    self.continueFlashing()
                }
            }
        default:
            break
        }
    }
    
    var currentFw: [UInt8] = []
    private func startFlashing(target: Target) {
        
        let data = self.firmware.targetFirmwares["cf2-\(target.name)-fw"]
        self.flashState = .Load
        
        if data == nil {
            if target == .nrf51 {
                state = .Flashing(.stm32, 0, 0.0)
                self.startFlashing(.stm32)
                return
            } else {
                self.done()
            }
        }
        
        self.currentFw = [UInt8](count: data!.length, repeatedValue: 0)
        data!.getBytes(&self.currentFw, length: self.currentFw.count)
        
        self.continueFlashing()
    }
    
    func continueFlashing() {
        switch self.state {
        case .Flashing(let target, let pos, let percent):
            let currentPage = pos / self.infos[target]!.pageSize
            let currentBufferPage = 0
            let posInPage  = pos % self.infos[target]!.pageSize
            let currentPageSize = min(self.infos[target]!.pageSize, self.currentFw.count-(currentPage*self.infos[target]!.pageSize))
            let leftInPage = currentPageSize - posInPage
            let byteToSend = min(leftInPage, 13)
            
            switch self.flashState {
            case .Load:
                println("Loading page from \(leftInPage)")
                
                var packet: [UInt8] = [0xff, target.rawValue, loadBuffer]
                packet = packet + [UInt8(currentBufferPage&0x00ff), UInt8(currentBufferPage>>8)]
                packet = packet + [UInt8(posInPage&0x00ff), UInt8(posInPage>>8)]
                packet = packet + Array(self.currentFw[pos..<(pos+byteToSend)])
                
                println(packet)
                if leftInPage-byteToSend == 0 {
                    self.flashState = .Flash(currentPage)
                }
                
                let newPos = pos+byteToSend
                self.state = .Flashing(target, newPos, Double(newPos)/Double(self.currentFw.count))
                
                self.link.sendPacket(NSData(bytes: packet, length: packet.count)) { (success) in
                    println("Page loaded, continuing")
                    
                    self.wd.reset()
                    self.continueFlashing()
                }
            case .Flash(let page):
                let pageToFlash = page + self.infos[target]!.flashStart
                
                println("Flashing to page \(page)")
                
                var packet: [UInt8] = [0xff, target.rawValue, writeFlash]
                packet = packet + [0, 0]
                packet = packet + [UInt8(pageToFlash&0x00ff), UInt8(pageToFlash>>8)]
                packet = packet + [1, 0]
                
                self.wd.reset(period: 2)
                self.link.sendPacket(NSData(bytes: packet, length: packet.count), callback: nil)
                
                self.flashState = .Load
            }
            
        default:
            break
        }
    }
}