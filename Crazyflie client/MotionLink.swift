//
//  MotionLink.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 22.01.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import Foundation
import CoreMotion

class MotionLink: NSObject {
    
    private var motionManager: CMMotionManager?
    private var crtpMotion:CMDeviceMotion! = nil
    
    private var btQueue: dispatch_queue_t
    
    var canMotion = false
    var state = ""
    
    override init() {
        self.btQueue = dispatch_queue_create("se.bitcraze.crazyfliecontrol.motion", DISPATCH_QUEUE_SERIAL)
        
        super.init()
        
        motionManager = CMMotionManager()
        canMotion = motionManager!.accelerometerActive && motionManager!.accelerometerAvailable;
        
        state = "idle"
    }
}
