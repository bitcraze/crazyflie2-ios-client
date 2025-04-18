//
//  ControlMode.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 14.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
//

import Foundation

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
        defaults.set(rawValue + 1, forKey: "controlMode")
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
            return ["Yaw", "Thrust",  "Roll", "Pitch"]
        case .mode3:
            return ["Roll", "Pitch",  "Yaw", "Thrust"]
        case .mode4:
            return ["Roll", "Thrust",  "Yaw", "Pitch"]
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
        leftJoystick.thrustControl = .none
        rightJoystick.thrustControl = .none
        var commander: CrazyFlieCommander
        switch self {
        case .mode1:
            rightJoystick.thrustControl = .y
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .y(provider: leftJoystick),
                rollProvider: .x(provider: rightJoystick),
                yawProvider: .x(provider: leftJoystick),
                thrustProvider: .y(provider: rightJoystick),
                settings: settings)
            break
        case .mode2:
            leftJoystick.thrustControl = .y
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .y(provider: rightJoystick),
                rollProvider: .x(provider:  rightJoystick),
                yawProvider: .x(provider: leftJoystick),
                thrustProvider: .y(provider: leftJoystick),
                settings: settings)
            break
        case .mode3:
            rightJoystick.thrustControl = .y
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .y(provider: leftJoystick),
                rollProvider: .x(provider: leftJoystick),
                yawProvider: .x(provider: rightJoystick),
                thrustProvider: .y(provider: rightJoystick),
                settings: settings)
            break
        case .mode4:
            leftJoystick.thrustControl = .y
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .y(provider: rightJoystick),
                rollProvider: .x(provider: leftJoystick),
                yawProvider: .x(provider: rightJoystick),
                thrustProvider: .y(provider: leftJoystick),
                settings: settings)
            break
        case .tilt:
            guard let motionLink = motionLink else {
                return nil
            }
            rightJoystick.thrustControl = .y
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .y(provider: motionLink),
                rollProvider: .x(provider: motionLink),
                yawProvider: .x(provider: leftJoystick),
                thrustProvider: .y(provider: rightJoystick),
                settings: settings,
                allowNegativeValues: true)
        }
        return commander
    }
}
