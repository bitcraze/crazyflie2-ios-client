//
//  SettinsViewModel.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 24.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

protocol SettingsViewModelDelegate: AnyObject {
    func didUpdate()
}

protocol SettingsViewModelObserver: Observer {
    func didUpdate(controlMode: ControlMode)
}

final class SettingsViewModel: Observable {
    typealias ConcreteObserver = SettingsViewModelObserver
    
    weak var delegate: SettingsViewModelDelegate?
    private(set) var sensitivity: Sensitivity
    private(set) var controlMode: ControlMode
    private let bluetoothLink: BluetoothLink
    var weakObservers: [WeakBox] = [WeakBox]()
    
    init(sensitivity: Sensitivity, controlMode: ControlMode, bluetoothLink: BluetoothLink) {
        self.bluetoothLink = bluetoothLink
        self.sensitivity = sensitivity
        self.controlMode = controlMode
    }
    
    var leftXTitle: String? {
        return title(at: 0)
    }
    var rightXTitle: String? {
        return title(at: 2)
    }
    var leftYTitle: String? {
        return title(at: 1)
    }
    var rightYTitle: String? {
        return title(at: 3)
    }
    
    var controlModeIndex: Int {
        return controlMode.rawValue
    }
    
    var sensitivityModeIndex: Int {
        return sensitivity.index
    }
    
    var hasTiltMode: Bool {
        return MotionLink().canAccessMotion
    }
    
    var canEditValues: Bool {
        return sensitivity == .custom
    }
    
    func didSetControlMode(at index: Int) {
        guard let controlMode = ControlMode(rawValue: index) else {
            return
        }
        self.controlMode = controlMode
        controlMode.save()
        delegate?.didUpdate()
        notifyObserverDidUpdate(controlMode: controlMode)
    }
    
    func didSetSensitivityMode(at index: Int) {
        guard let sensitivity = Sensitivity.sensitivity(for: index) else {
            return
        }
        self.sensitivity = sensitivity
        delegate?.didUpdate()
    }
    
    var pitch: Float? {
        guard let settings = sensitivity.settings else {
            return nil
        }
        return settings.pitchRate
    }
    
    func didUpdate(pitch: Float) -> Float? {
        guard let settings = sensitivity.settings else {
            return nil
        }
        
        if canEditValues {
            settings.pitchRate = pitch
            if settings.pitchRate != pitch {
                return settings.pitchRate
            }
            return nil
        }
        return settings.pitchRate
    }
    
    var yaw: Float? {
        guard let settings = sensitivity.settings else {
        return nil
        }
        return settings.yawRate
    }
    
    func didUpdate(yaw: Float) -> Float? {
        guard let settings = sensitivity.settings else {
        return nil
        }
        if canEditValues {
            settings.yawRate = yaw
            if settings.yawRate != yaw {
                return settings.yawRate
            }
            return nil
        }
        return settings.yawRate
    }
    
    var thrust: Float? {
        guard let settings = sensitivity.settings else {
            return nil
        }
        return settings.maxThrust
    }
    
    func didUpdate(thrust: Float) -> Float? {
        guard let settings = sensitivity.settings else {
            return nil
        }
        if canEditValues {
            settings.maxThrust = thrust
            if settings.maxThrust != thrust {
                return settings.maxThrust
            }
            return nil
        }
        return settings.maxThrust
    }
    
    var sensitivityTitles: [String] {
        return ["Slow", "Fast", "Custom"]
    }
    
    var controlModeTitles: [String] {
        return controlMode.titles
    }
    
    private func title(at index: Int) -> String? {
        guard controlMode.titles.indices.contains(index) else { return nil }
        
        return controlMode.titles[index]
    }
    
    private func notifyObserverDidUpdate(controlMode: ControlMode) {
        observers.forEach { $0.didUpdate(controlMode: controlMode) }
    }
}
