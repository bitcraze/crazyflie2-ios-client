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

class FirmwareImage {
    
    static let latestVersionUrl = "https://api.github.com/repos/bitcraze/crazyflie-firmware/releases/latest"
    
    static func fetchLatestWithCallback(callback:(FirmwareImage?)->()) {
        let url = NSURL(string: latestVersionUrl)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if error != nil {
                NSLog("Error requesting latest version from github. Error: \(error.description)")
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(nil) }
                return
            }
            let httpResponse = response as! NSHTTPURLResponse
            if httpResponse.statusCode != 200 {
                NSLog("Error requesting latest version from github. Response code: \(httpResponse.statusCode)")
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(nil) }
                return
            }
            
            // Decoding the JSON and inithializing a new FirmwareImage object
            let json = JSON(data: data)
            
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
            
            if version == nil || description == nil || fileName == nil || fileUrl == nil {
                NSLog("Error decoding the github latest version json: (\(version), \(description), \(fileName), \(fileUrl)")
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(nil) }
                return
            }
            
            NSOperationQueue.mainQueue().addOperationWithBlock() {
                let firmware = FirmwareImage(version: version!, description: description!, fileName: fileName!, fileUrl: fileUrl!)
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(firmware) }
            }
        }
        
        task.resume()
    }
    
    var version: String
    var description: String
    var fileName: String
    var fileUrl: String
    
    var file: String? = nil
    
    var targetFirmwares = [String: NSData]()
    
    init(version:String, description:String, fileName:String, fileUrl:String) {
        self.version = version
        self.description = description
        self.fileName = fileName
        self.fileUrl = fileUrl
    }
    
    func download(callback: (Bool)->()) {
        let url = NSURL(string: fileUrl)
        
        let task = NSURLSession.sharedSession().dataTaskWithURL(url!) {(data, response, error) in
            if error != nil {
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(false) }
                NSLog("Error downloading the firmware: \(error.description)");
                return
            }
            
            let path = NSTemporaryDirectory() + self.fileName
            
            
            if data.writeToFile(path, atomically: false) && self.extractTargets(path) {
                self.file = path
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(true) }
            } else {
                self.file = nil
                NSOperationQueue.mainQueue().addOperationWithBlock() { callback(false) }
            }
        }
        
        task.resume()
    }
    
    private func extractTargets(path: String) -> Bool {
        var error: NSError?
        let archive = ZZArchive(URL: NSURL.fileURLWithPath(path), error: &error)
        var json: JSON = nil
                
        // Find json and decode it
        for entrie  in archive.entries {
            if entrie.fileName != nil && entrie.fileName! == "manifest.json" {
                var data = entrie.newDataWithError(&error)
                if data != nil {
                    json = JSON(data: data)
                }
                break
            }
        }
        
        if json == nil {
            NSLog("Error extracting the image: no manifest.json")
            return false
        }
        
        var version =  json["version"].int
        var files = json["files"].dictionary
        
        if version == nil || version! != 1 || files == nil {
            NSLog("Error extracting the image: Wrong version or malformed manifest")
            return false
        }
        
        for (name, content) in files! {
            var platform: String! = content["platform"].string
            var target: String! = content["target"].string
            var type: String! = content["type"].string
            
            if platform == nil || target == nil || type == nil {
                NSLog("Error extracting the image: Malformed manifest")
                return false
            }
            
            for entrie in archive.entries {
                if entrie.fileName == name {
                    var data = entrie.newDataWithError(&error)
                    
                    if data == nil {
                        NSLog("Error extracting the image: Malformed firmware for \(name)")
                        return false
                    }
                    self.targetFirmwares["\(platform)-\(target)-\(type)"] = data
                }
            }
        }
        
        
        return true
    }
}