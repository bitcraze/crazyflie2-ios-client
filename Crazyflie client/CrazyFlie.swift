//
//  CrazyFlie.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 15.07.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import UIKit

open class CrazyFlie: NSObject {
    @objc enum State:Int {
        case idle, connected , scanning, connecting, services, characteristics
    }
    
    struct CommanderPacket {
        var header: __uint8_t;
        var pitch: Float;
        var roll: Float;
        var yaw: Float;
        var thrust:Float;
    }
    
    var state:State {
        get{
            return internalState
        }
        set {
            internalState = newValue
            callback?(state)
        }
    }
    
    var pitch:Float = 0
    var roll:Float = 0
    var thrust:Float = 0
    var yaw:Float = 0
    var automaticCommandSending:Bool {
        get {
            return internalAutomaticCommandSending
        }
        set {
            internalAutomaticCommandSending = newValue
            if newValue {
                invalidateTimer()
            }
            else if sent {
                startTimer()
            }
        }
    }
    
    fileprivate var internalAutomaticCommandSending:Bool = true
    fileprivate var internalState:State = .idle
    fileprivate var sent:Bool = false
    fileprivate var callback:((_ state:State) -> Void)?
    fileprivate var fetchData:((_ crazyFlie:CrazyFlie) -> Void)?
    fileprivate(set) var bluetoothLink:BluetoothLink!
    fileprivate var timer:Timer?
    
    override init() {
        super.init()
        
        self.bluetoothLink = BluetoothLink()
        bluetoothLink.onStateUpdated{[weak self] (state) in
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
    }
    
    func onStateUpdated(_ callback:@escaping (_ state:State) -> Void) {
        self.callback = callback
    }
    
    func fetchData(_ callback:@escaping (_ crazyFlie:CrazyFlie) -> Void) {
        self.fetchData = callback
    }
    
    func connect(_ callback:((Bool) -> ())?) {
        guard state == .idle else {
            self.disconnect()
            return
        }
        
        self.bluetoothLink.connect(nil, callback: {[weak self](connected) in
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
                
                // Display the message
                let alert = UIAlertView(title: title, message:body, delegate: nil, cancelButtonTitle: "OK")
                alert.show()
                
                return
            }
            
            self?.sent = true;
            
            if ((self?.automaticCommandSending) != nil) {
                self?.startTimer()
            }
            })
    }
    
    func disconnect() {
        bluetoothLink.disconnect()
        invalidateTimer()
    }
    
    func sendCommander(_ roll:Float, pitch:Float, thrust:Float, yaw:Float) {
        
        var commandPacket = CommanderPacket(header: 0x30, pitch: pitch, roll: roll, yaw: yaw, thrust: thrust)
        let data = Data(bytes: &commandPacket, count:MemoryLayout<CommanderPacket>.size)
        
        bluetoothLink.sendPacket(data, callback: {[weak self] (success) in
            self?.sent = true
            })
    }
    
    fileprivate func startTimer() {
        if timer != nil {
            invalidateTimer()
        }
        
        self.timer = Timer.scheduledTimer(timeInterval: 0.05, target: self, selector: #selector(self.sendTimer), userInfo:nil, repeats:true)
    }
    
    fileprivate func invalidateTimer() {
        self.timer?.invalidate()
        self.timer = nil
    }
    
    @objc fileprivate func sendTimer(_ timter:Timer){
        guard sent else {
            print("Missing command update")
            return
        }
        
        print("Send commander!")
        
        fetchData?(self)
        sendCommander(self.roll, pitch: self.pitch, thrust: self.thrust, yaw: self.yaw)
    }
}
