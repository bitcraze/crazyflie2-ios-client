//
//  MotionLink.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 22.01.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import Foundation
import CoreMotion

public class MotionLink : NSObject {
    
    private let motionManager: CMMotionManager = CMMotionManager()
    private let queue: NSOperationQueue = NSOperationQueue()
    private var _motionUpdateActive:Bool = false;
    private var _accelerationUpdateActive:Bool = false;
    private var _accelerationDataCalibrate:CMAcceleration = CMAcceleration();
    
    public var canAccessAccelerometer: Bool { get{return motionManager.accelerometerAvailable } }
    public var canAccessMotion: Bool { get{return motionManager.deviceMotionAvailable } }
    public var accelerometerData: CMAccelerometerData? { get{return motionManager.accelerometerData } }
    public var deviceMotion: CMDeviceMotion? { get{return motionManager.deviceMotion} }
    public var state:String?
    public var motionUpdateActive: Bool { get{return _motionUpdateActive} }
    public var accelerationUpdateActive: Bool { get{return _accelerationUpdateActive} }
    
    override init() {
        super.init()
        
        motionManager.deviceMotion
        motionManager.accelerometerUpdateInterval = 0.1
        state = "idle"
    }
    
    func calibratedAcceleration() -> CMAcceleration {
        let a:CMAcceleration =  (motionManager.deviceMotion?.gravity)!
        var pitch:Double = ((_accelerationDataCalibrate.y - a.y) * 4);
        var roll:Double = ((a.x - _accelerationDataCalibrate.x) * 4);
        pitch = pitch < -25 ? -25 : pitch;
        roll = roll < -25 ? -25 : roll;
        roll = roll > 25 ? 25 : roll;
        return CMAcceleration(x: pitch, y: roll, z: (_accelerationDataCalibrate.z - a.z))
    }
    
    func calibrate() -> Void {
        state = "calibrating"
        _accelerationDataCalibrate = (motionManager.deviceMotion?.gravity)!;
    }
    
    func startDeviceMotionUpdates(handler:CMDeviceMotionHandler?) -> Void {
        state = "starting device motion updates"
        self.motionManager.startDeviceMotionUpdatesToQueue(self.queue , withHandler:{
            (data, error) in
            if (handler != nil) {
                handler!(data, error)
            }
        })
        _motionUpdateActive = true
    }
    
    func startAccelerometerUpdates(handler:CMAccelerometerHandler?) -> Void {
        state = "starting accelerometer updates"
        motionManager.startAccelerometerUpdatesToQueue(self.queue, withHandler:{
            (data, error) in
            if (handler != nil) {
                handler!(data, error)
            }
        })
        _accelerationUpdateActive = true
    }
    
    func stopAccelerometerUpdates() -> Void {
        state = "stopping accelerometer updates"
        motionManager.stopAccelerometerUpdates();
        _accelerationUpdateActive = false;
    }
    
    func stopDeviceMotionUpdates() -> Void {
        state = "stopping device motion updates"
        motionManager.stopDeviceMotionUpdates();
        _motionUpdateActive = false;
    }
}
