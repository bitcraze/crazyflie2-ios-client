//
//  CrazyFlie.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 15.07.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import UIKit

@objc class CrazyFlie: NSObject {
    enum State {
        case Idle, Connected , Scanning, Connecting, Services, Characteristics
    }
    
    var state:State {
        get{
            return state
        }
        set {
            state = newValue
            onStateUpdated(state)
        }
    }
    var onStateUpdated:(state:State) -> Void
    
    private let bluetoothLink:BluetoothLink
    
    init() {
        super.init()

        bluetoothLink = BluetoothLink()
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
    
    
}
