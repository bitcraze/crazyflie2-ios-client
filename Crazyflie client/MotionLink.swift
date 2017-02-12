//
//  MotionLink.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 22.01.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import Foundation
import CoreMotion

final class MotionLink: CrazyFlieYProvideable, CrazyFlieXProvideable {
    
    private let motionManager = CMMotionManager()
    private let queue = OperationQueue()
    private var accelerationDataCalibrate = CMAcceleration()
    
    private(set) var accelerationUpdateActive = false
    private(set) var motionUpdateActive = false
    private(set) var state:String?
    
    init() {
        motionManager.accelerometerUpdateInterval = 0.1
        state = "idle"
    }
    
    var x: Float {
        return Float(calibratedAcceleration?.x ?? 0)
    }
    
    var y: Float {
        return Float(calibratedAcceleration?.y ?? 0)
    }
    
    var canAccessAccelerometer: Bool { return motionManager.isAccelerometerAvailable }
    var canAccessMotion: Bool { return motionManager.isDeviceMotionAvailable }
    var accelerometerData: CMAccelerometerData? { return motionManager.accelerometerData }
    var deviceMotion: CMDeviceMotion? { return motionManager.deviceMotion }
    
    private var calibratedAcceleration: CMAcceleration? {
        guard let a =  motionManager.accelerometerData?.acceleration else {
            return nil
        }
        
        var pitch:Double = ((accelerationDataCalibrate.y - a.y) * 4);
        var roll:Double = ((a.x - accelerationDataCalibrate.x) * 4);
        pitch = pitch < -25 ? -25 : pitch;
        roll = roll < -25 ? -25 : roll;
        roll = roll > 25 ? 25 : roll;
        return CMAcceleration(x: pitch, y: roll, z: (accelerationDataCalibrate.z - a.z))
    }
    
    func calibrate() {
        state = "calibrating"
        accelerationDataCalibrate = (motionManager.deviceMotion?.gravity)!;
    }
    
    func startDeviceMotionUpdates(_ handler:CMDeviceMotionHandler?) -> Void {
        state = "starting device motion updates"
        self.motionManager.startDeviceMotionUpdates(to: self.queue , withHandler:{
            (data, error) in
            if (handler != nil) {
                handler!(data, error)
            }
        })
        motionUpdateActive = true
    }
    
    func startAccelerometerUpdates(_ handler:CMAccelerometerHandler?) -> Void {
        state = "starting accelerometer updates"
        motionManager.startAccelerometerUpdates(to: self.queue, withHandler:{
            (data, error) in
            if (handler != nil) {
                handler!(data, error)
            }
        })
        accelerationUpdateActive = true
    }
    
    func stopAccelerometerUpdates() {
        state = "stopping accelerometer updates"
        motionManager.stopAccelerometerUpdates();
        accelerationUpdateActive = false;
    }
    
    func stopDeviceMotionUpdates() {
        state = "stopping device motion updates"
        motionManager.stopDeviceMotionUpdates();
        motionUpdateActive = false;
    }
}
