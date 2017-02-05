//
//  ViewModel.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 23.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

protocol ViewModelDelegate: class {
    func signalUpdate()
}

final class ViewModel {
    weak var delegate: ViewModelDelegate?
    var leftJoystickProvider: BCJoystickViewModel?
    var rightJoystickProvider: BCJoystickViewModel?
    
    private var motionLink: MotionLink?
    private var crazyFlie: CrazyFlie?
    private var sensitivity: Sensitivity = .slow
    private var controlMode: ControlMode = ControlMode.current!
    
    private(set) var leftJoystickHorizontalTitle: String?
    private(set) var leftJoystickVerticalTitle: String?
    private(set) var rightJoystickHorizontalTitle: String?
    private(set) var rightJoystickVerticalTitle: String?
    
    fileprivate(set) var progress: Float = 0
    fileprivate(set) var topButtonTitle: String
    
    init() {
        topButtonTitle = "Connect"
        
        crazyFlie = CrazyFlie(delegate: self)
        loadDefaults()
    }
    
    var bothThumbsOnJoystick: Bool = false {
        didSet {
            if oldValue != bothThumbsOnJoystick {
                if bothThumbsOnJoystick {
                    motionLink?.calibrate()
                }
                delegate?.signalUpdate()
            }
        }
    }
    
    var settingsViewModel: SettingsViewModel? {
        guard let bluetoothLink = crazyFlie?.bluetoothLink else {
            return nil
        }
        return SettingsViewModel(sensitivity: sensitivity, controlMode: controlMode, bluetoothLink: bluetoothLink)
    }
    
    // MARK: - Public Methods
    
    func loadSettings() {
        
    }
    
    func connect() {
        crazyFlie?.connect(nil)
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
        motionLink?.stopAccelerometerUpdates()
    }
    
    private func loadDefaults() {
        guard let url = Bundle.main.url(forResource: "DefaultPreferences", withExtension: "plist"),
            let defaultPrefs = NSDictionary(contentsOf: url) else {
                return
        }
        let defaults = UserDefaults.standard
        defaults.register(defaults: defaultPrefs as! [String : Any])
        defaults.synchronize()
        
        updateSettings()
    }
    
    private func updateSettings() {
        if controlMode == .tilt,
            let motionLink = motionLink,
            motionLink.canAccessMotion {
            startMotionUpdate()
        }
        else {
            stopMotionUpdate()
        }
        
        crazyFlie?.commander = controlMode.commander(
            leftJoystick: leftJoystickProvider,
            rightJoystick: rightJoystickProvider,
            motionLink: motionLink,
            settings: sensitivity.settings)
    }
    
    fileprivate func updateWith(state: CrazyFlieState) {
        topButtonTitle = "Cancel"
        switch state {
        case .idle:
            progress = 0
            topButtonTitle = "Connect"
            break
        case .scanning:
            progress = 0
            break
        case .connecting:
            progress = 0.25
            break
        case .services:
            progress = 0.5
            break
        case .characteristics:
            progress = 0.75
            break
        case .connected:
            progress = 1
            break
        }
    }
}

extension ViewModel: BCJoystickViewModelObserver {
}

extension ViewModel: CrazyFlieDelegate {
    func didSend() {
        
    }
    
    func didUpdate(state: CrazyFlieState) {
        updateWith(state: state)
        delegate?.signalUpdate()
    }
    
    func didFail(with title: String, message: String?) {
        
    }
}
