//
//  Firmware.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 10.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
//

import Foundation

struct FirmwareAsset: Decodable {
    let name: String
    let browserDownloadUrl: URL
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadUrl = "browser_download_url"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.browserDownloadUrl = try container.decode(URL.self, forKey: .browserDownloadUrl)
    }
    
    enum `Type`: CaseIterable {
        case CF1
        case CF2
        case CF1AndCF2
        case tag
        
        var prefixes: [String] {
            switch self {
            case .CF1:
                return  ["cf1", "crazyflie1"]
            case .CF2:
                return ["cf2", "crazyflie2", "cflie2", "firmware-cf2"]
            case .CF1AndCF2:
                return ["crazyflie-"]
            case .tag:
                return ["firmware-tag"]
            }
        }
    }
    
    var type: Type? {
        let lowercasedName = name.lowercased(with: Locale(identifier: "US"))
        return Type.allCases.first { type in
            type.prefixes.contains(where: { lowercasedName.hasPrefix($0) })
        }
    }
}

struct Firmware {
    let name: String
    let assets: [FirmwareAsset]
    
    var targetFirmwares = [String: Data]()
}

extension Firmware: Decodable {
    enum CodingKeys: CodingKey {
        case name
        case assets
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decode(String.self, forKey: .name)
        self.assets = try container.decode([FirmwareAsset].self, forKey: .assets)
    }
}
