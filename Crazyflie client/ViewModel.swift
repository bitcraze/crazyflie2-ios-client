//
//  ViewModel.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 23.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

protocol ViewModelDelegate {
    func signalUpdate()
}

final class ViewModel {
    var delegate: ViewModelDelegate?
    
    private let motionLink: MotionLink?
    private let crazyFlie: CrazyFlie
    private var lastBothThumbsOn
    
    private(set) var leftJoystickHorizontalTitle: String?
    private(set) var leftJoystickVerticalTitle: String?
    private(set) var rightJoystickHorizontalTitle: String?
    private(set) var rightJoystickVerticalTitle: String?
    
    init() {
        crazyFlie = CrazyFlie(delegate: self)
        loadDefaults()
    }
    
    var bothThumbsOnJoystick: Bool {
        didSet {
            if oldValue != bothThumbsOnJoystick {
                if bothThumbsOnJoystick {
                    motionLink?.calibrate()
                }
                delegate?.signalUpdate()
            }
        }
    }
    
    // MARK: - Public Methods
    
    func connect() {
        crazyFlie.connect(nil)
    }
    
    // MARK: - Private MEthods
    
    private func startMotionUpdate() {
        if motionLink == nil {
            motionLink = MotionLink()
        }
        motionLink?.startDeviceMotionUpdates(nil)
        motionLink?.startAccelerometerUpdates(nil)
    }
    
    private func stopMotionUpdate() {
        motionLink?.stopDeviceMotionUpdates()
        motionLink?.stopAccelerometerUpdates(nil)
    }
    
    private func loadDefaults() {
        guard let url = Bundle.main.url(forResource: "DefaultPreferences", withExtension: "plist"),
            let defaultPrefs = NSDictionary(contentsOf: url) else {
                return
        }
        let defaults = UserDefaults.standard
        defaults.register(defaults: defaultPrefs)
        
        updateSettings()
    }
    
    private func saveDefaults() {
    }
    
    private func updateSettings() {
        let defaults = UserDefaults.standard
        let controlMode = defaults.integer(forKey: "controlMode")
        
        if motionLink?.canAccessMotion,
            controlMode == 5 {
            startMotionUpdate()
            crazyFlie.commander = .tilt(leftJoystick, rightJoystick, motionLink).commander()
            
        } else {
            stopMotionUpdate()
        }
        
        if controlMode == 1 {
            crazyFlie.commander = .mode1(leftJoystick, rightJoystick).commander
        } else if controlMode == 2 {
            crazyFlie.commander = .mode2(leftJoystick, rightJoystick).commander
        } else if controlMode == 3 {
            crazyFlie.commander = .mode3(leftJoystick, rightJoystick).commander
        } else if controlMode == 4 {
            crazyFlie.commander = .mode4(leftJoystick, rightJoystick).commander
        }
    }
}
