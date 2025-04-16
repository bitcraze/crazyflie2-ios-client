//
//  Image.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 14.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
//

import Foundation

struct ImageManifest: Decodable {
    let version: Int
    let files: [String: File]
    
    struct File: Decodable {
        let platform: String
        let target: String
        let type: String
    }
}
