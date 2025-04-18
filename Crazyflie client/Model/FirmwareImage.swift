//
//  FirmwareImage.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 27/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation
import UIKit
import Zip


struct FirmwareImage: Decodable {
    let version: String
    let description: String
    let fileName: String
    let browserDownloadUrl: URL
    
    var file: String? = nil
    var targetFirmwares = [String: Data]()
    
    enum CodingKeys: String, CodingKey {
        case version = "tag_name"
        case description = "body"
        case assets
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(String.self, forKey: .version)
        description = try container.decode(String.self, forKey: .description)
        
        if let assets = try container.decode(Array<Any>.self, forKey: .assets) as? Array<Dictionary<String, Any>>,
           let asset = assets.first(where: {
               let name = $0["name"] as? String
               let url = $0["browser_download_url"]
               return name != nil && url is String && ((name?.hasSuffix("zip")) != nil)
           }),
           let name = asset["name"] as? String,
           let downloadUrlString = asset["browser_download_url"] as? String,
           let url = URL(string: downloadUrlString)
        {
            self.fileName = name
            self.browserDownloadUrl = url
        } else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Could not find a zip file asset"))
        }
    }
}
