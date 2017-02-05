//
//  CommandSettings.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 23.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

enum Sensitivity: String {
    case slow = "slow"
    case fast = "fast"
    case custom = "custom"
    
    static func sensitivity(for index: Int) -> Sensitivity? {
        switch index {
        case 0:
            return .slow
        case 1:
            return .fast
        case 2:
            return .custom
        default:
            return nil
        }
    }
    
    var index: Int {
        switch self {
        case .slow:
            return 0
        case .fast:
            return 1
        case .custom:
            return 2
        }
    }
    
    var settings: Settings? {
        let defaults = UserDefaults.standard
        let sensitivities = defaults.dictionary(forKey: "sensitivities")
        guard let sensitivity = sensitivities?[self.rawValue] as? [String : Any] else {
            return nil
        }
        return Settings(sensitivity)
    }
    
    func save(settings: Settings) {
        let defaults = UserDefaults.standard
        var sensitivities = defaults.dictionary(forKey: "sensitivities")
        sensitivities?[self.rawValue] = settings.dictionary
        defaults.set(sensitivities, forKey: "sensitivities")
        defaults.synchronize()
    }
}

enum ControlMode: Int {
    case mode1 = 0
    case mode2 = 1
    case mode3 = 2
    case mode4 = 3
    case tilt = 4
    
    static var current: ControlMode? {
        let defaults = UserDefaults.standard
        let i = defaults.integer(forKey: "controlMode")
        return ControlMode(rawValue: i - 1)
    }
    
    func save() {
        let defaults = UserDefaults.standard
        defaults.set(rawValue, forKey: "controlMode")
        defaults.synchronize()
    }
    
    var index: Int {
        return self.rawValue
    }
    
    var titles: [String] {
        switch self {
        case .mode1:
            return ["Yaw", "Pitch",  "Roll", "Thrust"]
        case .mode2:
            return ["Yaw", "Pitch",  "Roll", "Thrust"]
        case .mode3:
            return ["Yaw", "Pitch",  "Roll", "Thrust"]
        case .mode4:
            return ["Yaw", "Pitch",  "Roll", "Thrust"]
        case .tilt:
            return ["Yaw", "",  "", "Thrust"]
        }
    }
    
    func commander(leftJoystick: BCJoystickViewModel?,
                   rightJoystick: BCJoystickViewModel?,
                   motionLink: MotionLink? = nil,
                   settings: Settings?) -> CrazyFlieCommander? {
        guard let settings = settings,
            let leftJoystick = leftJoystick,
            let rightJoystick = rightJoystick else {
                return nil
        }
        var commander: CrazyFlieCommander
        switch self {
        case .mode1:
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(provider: leftJoystick),
                rollProvider: .y(provider: rightJoystick),
                yawProvider: .y(provider: leftJoystick),
                thrustProvider: .x(provider: rightJoystick),
                settings: settings)
            break
        case .mode2:
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(provider: rightJoystick),
                rollProvider: .y(provider: rightJoystick),
                yawProvider: .y(provider: leftJoystick),
                thrustProvider: .x(provider: leftJoystick),
                settings: settings)
            break
        case .mode3:
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(provider: leftJoystick),
                rollProvider: .y(provider: leftJoystick),
                yawProvider: .y(provider: rightJoystick),
                thrustProvider: .x(provider: rightJoystick),
                settings: settings)
            break
        case .mode4:
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(provider: rightJoystick),
                rollProvider: .y(provider: leftJoystick),
                yawProvider: .y(provider: rightJoystick),
                thrustProvider: .x(provider: leftJoystick),
                settings: settings)
            break
        case .tilt:
            guard let motionLink = motionLink else {
                return nil
            }
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(provider: motionLink),
                rollProvider: .y(provider: motionLink),
                yawProvider: .y(provider: leftJoystick),
                thrustProvider: .x(provider: rightJoystick),
                settings: settings,
                allowNegativeValues: true)
        }
        return commander
    }
}

class Settings {
    enum Names: String {
        case pitchRate = "pitchRate"
        case maxThrust = "maxThrust"
        case yawRate = "yawRate"
    }
    
    let minPitchRate: Float = 0
    let maxPitchRate: Float = 80
    let minYawRate: Float = 0
    let maxYawRate: Float = 500
    let minThrustRate: Float = 0
    let maxThrustRate: Float = 100
    
    init?(_ dictionary: [String: Any]) {
        guard let pitchRate = dictionary[Names.pitchRate.rawValue] as? Float,
            let yawRate = dictionary[Names.yawRate.rawValue] as? Float,
            let maxThrust = dictionary[Names.maxThrust.rawValue] as? Float else {
                return nil
        }
        
        self.pitchRate = pitchRate
        self.yawRate = yawRate
        self.maxThrust = maxThrust
    }
    
    var dictionary: [String: Any] {
        return [Names.pitchRate.rawValue: pitchRate,
                Names.yawRate.rawValue: yawRate,
                Names.maxThrust.rawValue: maxThrust]
    }
    
    var pitchRate: Float {
        get {
            return pitchRate
        }
        set {
            if newValue < minPitchRate {
                pitchRate = minPitchRate
            } else if newValue > maxPitchRate {
                pitchRate = maxPitchRate
            }
        }
    }
    
    var maxThrust: Float {
        get {
            return maxThrust
        }
        set {
            if newValue < minThrustRate {
                maxThrust = minThrustRate
            } else if newValue > maxThrustRate {
                maxThrust = maxThrustRate
            }
        }
    }
    
    var yawRate: Float {
        get {
            return yawRate
        }
        set {
            if newValue < minYawRate {
                yawRate = minYawRate
            } else if newValue > maxYawRate {
                yawRate = maxYawRate
            }
        }
    }
}
