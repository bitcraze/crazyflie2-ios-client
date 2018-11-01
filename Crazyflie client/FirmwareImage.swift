//
//  FirmwareImage.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 27/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation
import UIKit
import zipzap
import SwiftyJSON

class FirmwareImage {
    
    static let latestVersionUrl = "https://api.github.com/repos/bitcraze/crazyflie-release/releases/latest"
    
    static func fetchLatestWithCallback(_ callback:@escaping (FirmwareImage?, Bool)->()) {
        let url = URL(string: latestVersionUrl)
        
        let task = URLSession.shared.dataTask(with: url!, completionHandler: {(data, response, error) in
            guard let data = data else {
                NSLog("Error no data for firmware.")
                return
            }
            
            if let error = error  {
                NSLog("Error requesting latest version from github. Error: \(error.localizedDescription)")
                OperationQueue.main.addOperation() { callback(nil, false) }
                return
            }
            
            let httpResponse = response as! HTTPURLResponse
            if httpResponse.statusCode != 200 {
                NSLog("Error requesting latest version from github. Response code: \(httpResponse.statusCode)")
                OperationQueue.main.addOperation() { callback(nil, false) }
                return
            }
            
            // Decoding the JSON and inithializing a new FirmwareImage object
            let json: JSON
            do {
                json = try JSON(data: data)
            } catch {
                NSLog("Error, the data is not json. Data: \(data)")
                OperationQueue.main.addOperation() { callback(nil, false) }
                return
            }

            let version = json["tag_name"].string
            let description = json["body"].string
            var fileName: String? = nil
            var fileUrl: String? = nil
            
            // Search for an asset that has the zip file
            if let assets = json["assets"].array {
                for asset in assets {
                    if let name = asset["name"].string {
                        if let url = asset["browser_download_url"].string {
                            if name.hasSuffix(".zip") {
                                fileName = name
                                fileUrl = url
                                break;
                            }
                        }
                    }
                }
            }

            if let version = version,
                let description = description,
                let fileName = fileName,
                let fileUrl = fileUrl {
                OperationQueue.main.addOperation() {
                    let firmware = FirmwareImage(version: version, description: description, fileName: fileName, fileUrl: fileUrl)
                    OperationQueue.main.addOperation() { callback(firmware, false) }
                }
            } else {
                NSLog("Error decoding the github latest version json: (\(String(describing: version)), \(String(describing: description)), \(String(describing: fileName)), \(String(describing: fileUrl))")
                OperationQueue.main.addOperation() { callback(nil, fileName == nil) }
                return
            }
        }) 
        
        task.resume()
    }
    
    var version: String
    var description: String
    var fileName: String
    var fileUrl: String
    
    var file: String? = nil
    
    var targetFirmwares = [String: Data]()
    
    init(version:String, description:String, fileName:String, fileUrl:String) {
        self.version = version
        self.description = description
        self.fileName = fileName
        self.fileUrl = fileUrl
    }
    
    func download(_ callback: @escaping (Bool)->()) {
        let url = URL(string: fileUrl)
        
        let task = URLSession.shared.dataTask(with: url!, completionHandler: {(data, response, error) in
            guard let data = data else {
                NSLog("Error empty firmware data)")
                return
            }
            
            if let error = error {
                OperationQueue.main.addOperation() { callback(false) }
                NSLog("Error downloading the firmware: \(error.localizedDescription)")
                return
            }
            
            let path = NSTemporaryDirectory() + self.fileName
            
            if ((try? data.write(to: URL(fileURLWithPath: path), options: [])) != nil) && self.extractTargets(path) {
                self.file = path
                OperationQueue.main.addOperation() { callback(true) }
            } else {
                self.file = nil
                OperationQueue.main.addOperation() { callback(false) }
            }
        }) 
        
        task.resume()
    }
    
    fileprivate func extractTargets(_ path: String) -> Bool {

        guard let archive = try? ZZArchive(url: URL(fileURLWithPath: path)) else {
            NSLog("Error extracting archive from url \(path)")
            return false
        }


        // Find json and decode it
        let entries = archive.entries

        guard let manifestEntry = entries.first(where: { $0.fileName == "manifest.json" }) else {
            NSLog("Error extracting the image: no manifest.json")
            return false
        }

        let json: JSON
        do {
            json = try JSON(data: manifestEntry.newData())
        } catch {
            NSLog("Error extracting the image: json malformed. Error: \(error)")
            return false
        }

        let version =  json["version"].int
        let files = json["files"].dictionary
        
        if version == nil || version! != 1 || files == nil {
            NSLog("Error extracting the image: Wrong version or malformed manifest")
            return false
        }
        
        for (name, content) in files! {
            let platform: String! = content["platform"].string
            let target: String! = content["target"].string
            let type: String! = content["type"].string
            
            if platform == nil || target == nil || type == nil {
                NSLog("Error extracting the image: Malformed manifest")
                return false
            }
            
            for entry in entries where entry.fileName == name {
                guard let data = try? entry.newData() else {
                    NSLog("Error extracting the image: Malformed firmware for \(name)")
                    return false
                }
                self.targetFirmwares["\(platform!)-\(target!)-\(type!)"] = data
            }
        }
        
        return true
    }
}
