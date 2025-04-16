//
//  Firmware.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 10.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
//

import Foundation

struct FirmwareAsset: Decodable {
    enum CodingKeys: String, CodingKey {
        case browserDownloadUrl = "browser_download_url"
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.browserDownloadUrl = try container.decode(URL.self, forKey: .browserDownloadUrl)
    }
    
    let browserDownloadUrl: URL
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
