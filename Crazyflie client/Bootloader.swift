//
//  Bootloader.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 29/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation

class Bootloader {
    enum State {
        case Idle
    }
    
    var state = State.Idle
    
    var link: BluetoothLink
    
    init(link: BluetoothLink) {
        self.link = link
    }
    
    typealias CallbackType = (done: Bool, progress: Float, status: String, error: NSError?)->()
    
    private var callback: CallbackType? = nil
    
    func update(firmware: FirmwareImage, callback: CallbackType) {
        self.callback = callback
    }
    
    func cancel() {
        self.state = .Idle
        let error = NSError(domain: "CrazyflieBoorloader", code: -1, userInfo: [NSLocalizedDescriptionKey: "Update canceled"])
        NSOperationQueue.mainQueue().addOperationWithBlock() {
            self.callback?(done: true, progress: 0.0, status: "Canceled", error: error)
        }
    }
}