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

protocol CrazyFlieDataProviderProtocol {
    var value: Float { get }
}

protocol CrazyFlieXProvideable {
    var x: Float { get }
}

protocol CrazyFlieYProvideable {
    var y: Float { get }
}

enum CrazyFlieDataProvider {
    case x(provider: CrazyFlieXProvideable)
    case y(provider: CrazyFlieYProvideable)
    
    var provider: CrazyFlieDataProviderProtocol {
        switch self {
        case .x(let provider):
            return SimpleXDataProvider(provider)
        case .y(let provider):
            return SimpleYDataProvider(provider)
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
    
    init(_ providable: CrazyFlieYProvideable) {
        self.providable = providable
    }
    
    var value: Float {
        return providable.y
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
         rollProvider: CrazyFlieDataProvider,
         yawProvider: CrazyFlieDataProvider,
         thrustProvider: CrazyFlieDataProvider,
         settings: Settings,
         allowNegativeValues: Bool = true) {
        
        self.pitchProvider = pitchProvider
        self.yawProvider = yawProvider
        self.rollProvider = rollProvider
        self.thrustProvider = thrustProvider
        self.allowNegativeValues = allowNegativeValues
        
        pitchRate = settings.pitchRate
        yawRate = settings.yawRate
        maxThrust = settings.maxThrust
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
        pitchBounds.value = pitch(from: pitchProvider.provider.value)
        rollBounds.value = roll(from: rollProvider.provider.value)
        thrustBounds.value = thrust(from: thrustProvider.provider.value)
        yawBounds.value = yaw(from: yawProvider.provider.value)
    }
    
    private func pitch(from control: Float) -> Float {
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
    
    private func roll(from control: Float) -> Float {
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
    
    private func yaw(from control: Float) -> Float {
        return control * yawRate
    }

    private func thrust(from control: Float) -> Float {
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
