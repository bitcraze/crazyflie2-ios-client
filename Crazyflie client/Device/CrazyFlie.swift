//
//  CrazyFlie.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 15.07.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import UIKit

protocol CrazyFlieCommander {
    var pitch: Float { get }
    var roll: Float { get }
    var thrust: Float { get }
    var yaw: Float { get }
    
    func prepareData()
}

enum CrazyFlieHeader: UInt8 {
    case commander = 0x30
}

enum CrazyFlieState {
    case idle, connected , scanning, connecting, services, characteristics
}

protocol CrazyFlieDelegate {
    func didSend()
    func didUpdate(state: CrazyFlieState)
    func didFail(with title: String, message: String?)
}

final class CrazyFlie {
    
    private(set) var state:CrazyFlieState {
        didSet {
            delegate?.didUpdate(state: state)
        }
    }
    private var timer:Timer?
    private var delegate: CrazyFlieDelegate?
    private(set) var bluetoothLink:BluetoothLink!

    var commander: CrazyFlieCommander?
    
    init(bluetoothLink:BluetoothLink? = BluetoothLink(), delegate: CrazyFlieDelegate?) {
        
        state = .idle
        self.delegate = delegate
        
        self.bluetoothLink = bluetoothLink
    
        bluetoothLink?.onStateUpdated { [weak self] state in
            self?.state = state
        }
    }
    
    func connect(_ callback:((Bool) -> Void)?) {
        guard state == .idle else {
            self.disconnect()
            return
        }
        
        self.bluetoothLink.connect(nil, callback: {[weak self] (connected) in
            callback?(connected)
            guard connected else {
                if self?.timer != nil {
                    self?.timer?.invalidate()
                    self?.timer = nil
                }
                
                var title:String
                var body:String?
                
                // Find the reason and prepare a message
                if self?.bluetoothLink.error == "Bluetooth disabled" {
                    title = "Bluetooth disabled"
                    body = "Please enable Bluetooth to connect a Crazyflie"
                } else if self?.bluetoothLink.error == "Timeout" {
                    title = "Connection timeout"
                    body = "Could not find Crazyflie"
                } else {
                    title = "Error"
                    body = self?.bluetoothLink.error
                }
                
                self?.delegate?.didFail(with: title, message: body)
                return
            }
            
            self?.startTimer()
        })
    }
    
    func disconnect() {
        bluetoothLink.disconnect()
        stopTimer()
    }
    
    // MARK: - Private Methods 
    
    private func startTimer() {
        stopTimer()
        
        self.timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(self.updateData), userInfo:nil, repeats:true)
    }
    
    private func stopTimer() {
        if timer != nil {
            timer?.invalidate()
            timer = nil
        }
    }
    
    @objc
    private func updateData(timer: Timer) {
        guard let commander = commander else {
            return
        }

        commander.prepareData()
        sendFlightData(commander.roll, pitch: commander.pitch, thrust: commander.thrust, yaw: commander.yaw)
    }
    
    private func sendFlightData(_ roll:Float, pitch:Float, thrust:Float, yaw:Float) {
        let commanderPacket = CommanderPacket(header: CrazyFlieHeader.commander.rawValue, roll: roll, pitch: pitch, yaw: yaw, thrust: UInt16(thrust))
        bluetoothLink.sendPacket(commanderPacket.data, callback: nil)
        //print("pitch: \(pitch) roll: \(roll) thrust: \(thrust) yaw: \(yaw)")
    }
}
