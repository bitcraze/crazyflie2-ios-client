//
//  CommanderPacket.swift
//  Crazyflie client
//
//  Created by Valeriy Van on 10/01/2023.
//  Copyright © 2023 Bitcraze. All rights reserved.
//

import Foundation

struct CommanderPacket {
    let header: UInt8
    let roll: Float
    let pitch: Float
    let yaw: Float
    let thrust: UInt16

    var data: Data {
        var data = Data(capacity: MemoryLayout<UInt8>.size + 3 * MemoryLayout<Float>.size + MemoryLayout<UInt16>.size)
        withUnsafePointer(to: header) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
        withUnsafePointer(to: roll) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
        withUnsafePointer(to: pitch) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
        withUnsafePointer(to: yaw) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
        withUnsafePointer(to: thrust) { data.append(UnsafeBufferPointer(start: $0, count: 1)) }
        return data
    }
}
