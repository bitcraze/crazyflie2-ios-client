//
//  CrazyFlieModes.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 21.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

let LINEAR_PR = true
let LINEAR_THRUST = true

enum CrazyFlieDataProvider {
    case x(joystick: BCJoystick)
    case y(joystick: BCJoystick)
    
    var provider: CrazyFlieDataProviderProtocol {
        switch self {
        case .x(let joystock):
            return SimpleXDataProvider(joystock)
        case .y(let joystock):
            return SimpleYDataProvider(joystock)
        }
    }
}

class SimpleXDataProvider: CrazyFlieDataProviderProtocol {
    let providable: CrazyFlieXProvideable
    
    init(_ providable: CrazyFlieXProvideable) {
        self.providable = providable
    }
    
    var value: Float {
        return providable.x
    }
}

class SimpleYDataProvider: CrazyFlieDataProviderProtocol {
    let providable: CrazyFlieYProvideable
    
    init(_ providable: CrazyFlieXProvideable) {
        self.providable = providable
    }
    
    var value: Float {
        return providable.y
    }
}

enum CrazyFlieCommand {
    case mode1(leftJoystick: BCJoystick, rightJoystick: BCJoystick)
    case mode2(leftJoystick: BCJoystick, rightJoystick: BCJoystick)
    case mode3(leftJoystick: BCJoystick, rightJoystick: BCJoystick)
    case mode4(leftJoystick: BCJoystick, rightJoystick: BCJoystick)
    case tilt(leftJoystick: BCJoystick, rightJoystick: BCJoystick, motionLink: MotionLink)
    
    var commander: CrazyFlieCommander {
        var commander: CrazyFlieCommander
        switch self {
        case mode1(let leftJoystick, let rightJoystick):
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(leftJoystick),
                rollProvider: .y(rightJoystick),
                yawProvider: .y(leftJoystick),
                thrustProvider: .x(rightJoystick))
            break
        case mode2(let leftJoystick, let rightJoystick):
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(rightJoystick),
                rollProvider: .y(rightJoystick),
                yawProvider: .y(leftJoystick),
                thrustProvider: .x(leftJoystick))
            break
        case mode3(let leftJoystick, let rightJoystick):
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(leftJoystick),
                rollProvider: .y(leftJoystick),
                yawProvider: .y(rightJoystick),
                thrustProvider: .x(rightJoystick))
            break
        case mode4(let leftJoystick, let rightJoystick):
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(rightJoystick),
                rollProvider: .y(leftJoystick),
                yawProvider: .y(rightJoystick),
                thrustProvider: .x(leftJoystick))
            break
        case tilt(let leftJoystick, let rightJoystick, let motionLink):
            commander = SimpleCrazyFlieCommander(
                pitchProvider: .x(motionLink),
                rollProvider: .y(motionLink),
                yawProvider: .y(leftJoystick),
                thrustProvider: .x(rightJoystick),
                allowNegativeValues: true)
        }
        return commander
    }
}

class SimpleCrazyFlieCommander: CrazyFlieCommander {
 
    struct BoundsValue {
        let minValue: Float
        let maxValue: Float
        var value: Float
    }
    
    private var pitchBounds = BoundsValue(minValue: 0, maxValue: 1, value: 0)
    private var rollBounds = BoundsValue(minValue: 0, maxValue: 1, value: 0)
    private var thrustBounds = BoundsValue(minValue: 0, maxValue: 1, value: 0)
    private var yawBounds = BoundsValue(minValue: 0, maxValue: 1, value: 0)

    private let pitchRate: Float
    private let yawRate: Float
    private let maxThrust: Float
    private let allowNegativeValues: Bool
    
    private let pitchProvider: CrazyFlieDataProvider
    private let yawProvider: CrazyFlieDataProvider
    private let rollProvider: CrazyFlieDataProvider
    private let thrustProvider: CrazyFlieDataProvider
    
    init(pitchProvider: CrazyFlieDataProvider,
         yawProvider: CrazyFlieDataProvider,
         rollProvider: CrazyFlieDataProvider,
         thrustProvider: CrazyFlieDataProvider,
         allowNegativeValues: Bool = false) {
        
        self.pitchProvider = pitchProvider
        self.yawProvider = yawProvider
        self.rollProvider = rollProvider
        self.thrustProvider = thrustProvider
        self.allowNegativeValues = allowNegativeValues
        
        let defaults = UserDefaults.standard
        let sensitivities = defaults.dictionary(forKey: "sensitivities") as String
        let sensitivitySetting = defaults.string(forKey: "sensitivitySettings")
 
        let sensitivity = sensitivities[sensitivitySetting]
        pitchRate = sensitivity["pitchRate"] as Float
        yawRate = sensitivity["yawRate"] as Float
        maxThrust = sensitivity["maxThrust"] as Float
        
        
    }
    
    var pitch: Float {
        return pitchBounds.value
    }
    var roll: Float {
        return rollBounds.value
    }
    var thrust: Float {
        return thrustBounds.value
        
    }
    var yaw: Float {
        return yawBounds.value
    }
    
    func prepareData() {
        if let value = pitchProvider?.value {
            pitchBounds.value = pitch(from: value)
        }
        if let value = rollProvider?.value {
            rollBounds.value = roll(from: value)
        }
        if let value = thrustProvider?.value {
            thrustBounds.value = thrust(from: value)
        }
        if let value = yawProvider?.value {
            yawBounds.value = yaw(from: value)
        }
    }
    
    fileprivate func pitch(from control: Float) -> Float {
        if LINEAR_PR {
            if control >= 0
                || allowNegativeValues {
                return control * -1 * pitchRate
            }
        } else {
            if control >= 0 {
                return pow(control, 2) * -1 * pitchRate * ((control > 0) ? 1 : -1)
            }
        }
        
        return 0
    }
    
    fileprivate func roll(from control: Float) -> Float {
        if LINEAR_PR {
            if control >= 0
                || allowNegativeValues {
                return control * pitchRate
            }
        } else {
            if control >= 0 {
                return pow(control, 2) * pitchRate * ((control > 0) ? 1 : -1)
            }
        }
        
        return 0
    }
    
    fileprivate func yaw(from control: Float) -> Float {
        if control >= 0 {
            return control * yawRate
        }
        return 0
    }

    fileprivate func thrust(from control: Float) -> Float {
        var thrust: Float = 0
        if LINEAR_THRUST {
            thrust = control * 65535 * (maxThrust/100)
        } else {
            thrust = sqrt(control)*65535*(maxThrust/100)
        }
        if thrust > 65535 { thrust = 65535 }
        if thrust < 0 { thrust = 0 }
        return thrust
    
    }
}
