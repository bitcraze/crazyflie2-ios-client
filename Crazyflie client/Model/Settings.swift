//
//  Settings.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 23.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

final class Settings {
    enum Names: String {
        case pitchRate = "pitchRate"
        case maxThrust = "maxThrust"
        case yawRate = "yawRate"
    }
    
    private var _pitchRate: Float
    private var _yawRate: Float
    private var _maxThrust: Float
    
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
        
        _pitchRate = pitchRate
        _yawRate = yawRate
        _maxThrust = maxThrust
    }
    
    var dictionary: [String: Any] {
        return [Names.pitchRate.rawValue: pitchRate,
                Names.yawRate.rawValue: yawRate,
                Names.maxThrust.rawValue: maxThrust]
    }
    
    var pitchRate: Float {
        get {
            return _pitchRate
        }
        set {
            _pitchRate = min(max(newValue, minPitchRate), maxPitchRate)
        }
    }
    
    var maxThrust: Float {
        get {
            return _maxThrust
        }
        set {
            _maxThrust = min(max(newValue, minThrustRate), maxThrustRate)
        }
    }
    
    var yawRate: Float {
        get {
            return _yawRate
        }
        set {
            _yawRate = min(max(newValue, minYawRate), maxYawRate)
        }
    }
}
