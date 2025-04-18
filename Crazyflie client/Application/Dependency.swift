//
//  Dependency.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 10.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
//

struct Dependency {
    static let `default` = Dependency()
    
    let firmwareLoader = FirmwareLoader()
}
