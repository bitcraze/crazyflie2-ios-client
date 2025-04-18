//
//  Sensitivity.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 14.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
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
