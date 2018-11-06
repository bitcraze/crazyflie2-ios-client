//
//  MotionLink.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 22.01.16.
//  Copyright © 2016 Bitcraze. All rights reserved.
//

import Foundation
import CoreMotion

enum MotionLinkState {
    case idle, calibrating, startingDeviceMotionUpdates, startingAccelerometerUpdates, stoppingDeviceMotionUpdates, stoppingAccelerometerUpdates
}

final class MotionLink: CrazyFlieYProvideable, CrazyFlieXProvideable {
    
    private let motionManager = CMMotionManager()
    private var accelerationDataCalibrate = CMAcceleration()
    
    private(set) var accelerationUpdateActive = false
    private(set) var motionUpdateActive = false
    private(set) var state: MotionLinkState
    
    init() {
        state = .idle
    }
    
    var x: Float {
        return Float(calibratedAcceleration?.x ?? 0)
    }
    
    var y: Float {
        return Float(calibratedAcceleration?.y ?? 0)
    }
    
    var canAccessAccelerometer: Bool { return motionManager.isAccelerometerAvailable }
    var canAccessMotion: Bool { return motionManager.isDeviceMotionAvailable }
    
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
        guard let deviceMotionData = motionManager.deviceMotion else {
            return
        }
        
        state = .calibrating
        accelerationDataCalibrate = deviceMotionData.gravity;
    }
    
    func startDeviceMotionUpdates() -> Void {
        state = .startingDeviceMotionUpdates
        self.motionManager.startDeviceMotionUpdates()
        motionUpdateActive = true
    }
    
    func startAccelerometerUpdates() -> Void {
        state = .startingAccelerometerUpdates
        motionManager.startAccelerometerUpdates()
        accelerationUpdateActive = true
    }
    
    func stopAccelerometerUpdates() {
        state = .stoppingAccelerometerUpdates
        motionManager.stopAccelerometerUpdates();
        accelerationUpdateActive = false;
    }
    
    func stopDeviceMotionUpdates() {
        state = .stoppingDeviceMotionUpdates
        motionManager.stopDeviceMotionUpdates();
        motionUpdateActive = false;
    }
}
