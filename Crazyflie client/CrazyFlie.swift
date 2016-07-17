//
//  CrazyFlie.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 15.07.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import UIKit

public class CrazyFlie: NSObject {
    @objc enum State:Int {
        case Idle, Connected , Scanning, Connecting, Services, Characteristics
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
            callback?(state: state)
        }
    }
    
    var pitch:Float = 0
    var roll:Float = 0
    var thrust:Float = 0
    var yaw:Float = 0
    
    private var internalState:State = .Idle
    private var sent:Bool = false
    private var callback:((state:State) -> Void)?
    private var fetchData:((crazyFlie:CrazyFlie) -> Void)?
    private var bluetoothLink:BluetoothLink!
    private var timer:NSTimer?
    
    override init() {
        super.init()

        self.bluetoothLink = BluetoothLink()
        bluetoothLink.onStateUpdated{[weak self] (state) in
            if state.isEqualToString("idle") {
                self?.state = .Idle
            } else if state.isEqualToString("connected") {
                self?.state = .Connected
            } else if state.isEqualToString("scanning") {
                self?.state = .Scanning
            } else if state.isEqualToString("connecting") {
                self?.state = .Connecting
            } else if state.isEqualToString("services") {
                self?.state = .Services
            } else if state.isEqualToString("characteristics") {
                self?.state = .Characteristics
            }
        }
    }
    
    func onStateUpdated(callback:(state:State) -> Void) {
        self.callback = callback
    }
    
    func fetchData(callback:(crazyFlie:CrazyFlie) -> Void) {
        self.fetchData = callback
    }
    
    func connect(callback:((Bool) -> ())?) {
        guard state == .Idle else {
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
            self?.timer = NSTimer.scheduledTimerWithTimeInterval(0.05, target: self!, selector: #selector(self?.sendCommander), userInfo:nil, repeats:true)
            })
    }
    
    func disconnect() {
        bluetoothLink.disconnect()
        self.timer?.invalidate()
        self.timer = nil
    }
    
    @objc private func sendCommander(timter:NSTimer){
        guard sent else {
            print("Missing command update")
            return
        }
        
        print("Send commander!")
        
        fetchData?(crazyFlie: self)
       
        var commandPacket = CommanderPacket(header: 0x30, pitch: self.pitch, roll: self.roll, yaw: self.yaw, thrust: self.thrust)
        
        var data = NSData(bytes: &commandPacket, length:sizeof(CommanderPacket))
        bluetoothLink.sendPacket(data, callback: {[weak self] (success) in
            self?.sent = true
            })
    }
}