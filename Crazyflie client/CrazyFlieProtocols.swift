//
//  CrazyFlieProtocols.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 24.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

protocol CrazyFlieDataProviderProtocol {
    var value: Float { get }
}

protocol CrazyFlieXProvideable {
    var x: Float { get }
}

protocol CrazyFlieYProvideable {
    var y: Float { get }
}
