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

struct Firmware: Decodable {
    let name: String
    let asset: [FirmwareAsset]
}
