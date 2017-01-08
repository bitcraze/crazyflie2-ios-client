//
//  MotionLink.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 22.01.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import Foundation
import CoreMotion

open class MotionLink : NSObject {
    
    fileprivate let motionManager: CMMotionManager = CMMotionManager()
    fileprivate let queue: OperationQueue = OperationQueue()
    fileprivate var _motionUpdateActive:Bool = false;
    fileprivate var _accelerationUpdateActive:Bool = false;
    fileprivate var _accelerationDataCalibrate:CMAcceleration = CMAcceleration();
    
    open var canAccessAccelerometer: Bool { get{return motionManager.isAccelerometerAvailable } }
    open var canAccessMotion: Bool { get{return motionManager.isDeviceMotionAvailable } }
    open var accelerometerData: CMAccelerometerData? { get{return motionManager.accelerometerData } }
    open var deviceMotion: CMDeviceMotion? { get{return motionManager.deviceMotion} }
    open var state:String?
    open var motionUpdateActive: Bool { get{return _motionUpdateActive} }
    open var accelerationUpdateActive: Bool { get{return _accelerationUpdateActive} }
    
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
    
    func startDeviceMotionUpdates(_ handler:CMDeviceMotionHandler?) -> Void {
        state = "starting device motion updates"
        self.motionManager.startDeviceMotionUpdates(to: self.queue , withHandler:{
            (data, error) in
            if (handler != nil) {
                handler!(data, error)
            }
        })
        _motionUpdateActive = true
    }
    
    func startAccelerometerUpdates(_ handler:CMAccelerometerHandler?) -> Void {
        state = "starting accelerometer updates"
        motionManager.startAccelerometerUpdates(to: self.queue, withHandler:{
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
