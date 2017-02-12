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

enum CrazyFlieState {
    case idle, connected , scanning, connecting, services, characteristics
}

protocol CrazyFlieDelegate {
    func didSend()
    func didUpdate(state: CrazyFlieState)
    func didFail(with title: String, message: String?)
}

open class CrazyFlie: NSObject {
    
    struct CommanderPacket {
        var header: __uint8_t;
        var pitch: Float;
        var roll: Float;
        var yaw: Float;
        var thrust:Float;
    }
    
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
        super.init()
    
        bluetoothLink?.onStateUpdated{[weak self] (state) in
            if state.isEqual(to: "idle") {
                self?.state = .idle
            } else if state.isEqual(to: "connected") {
                self?.state = .connected
            } else if state.isEqual(to: "scanning") {
                self?.state = .scanning
            } else if state.isEqual(to: "connecting") {
                self?.state = .connecting
            } else if state.isEqual(to: "services") {
                self?.state = .services
            } else if state.isEqual(to: "characteristics") {
                self?.state = .characteristics
            }
        }
        
        startTimer()
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
                if self?.bluetoothLink.getError() == "Bluetooth disabled" {
                    title = "Bluetooth disabled"
                    body = "Please enable Bluetooth to connect a Crazyflie"
                } else if self?.bluetoothLink.getError() == "Timeout" {
                    title = "Connection timeout"
                    body = "Could not find Crazyflie"
                } else {
                    title = "Error";
                    body = self?.bluetoothLink.getError()
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
    
    @objc private func updateData(_ timter:Timer){
        guard timer != nil, let commander = commander else {
            return
        }

        commander.prepareData()
        sendData(commander.roll, pitch: commander.pitch, thrust: commander.thrust, yaw: commander.yaw)
    }
    
    private func sendData(_ roll:Float, pitch:Float, thrust:Float, yaw:Float) {
        var commandPacket = CommanderPacket(header: 0x30, pitch: pitch, roll: roll, yaw: yaw, thrust: thrust)
        print("thrust: ", thrust, ", pitch: ", pitch, ", roll: ", roll, ", yaw: ", yaw)
        let data = Data(bytes: &commandPacket, count:MemoryLayout<CommanderPacket>.size)
        bluetoothLink.sendPacket(data, callback: nil)
    }
}
