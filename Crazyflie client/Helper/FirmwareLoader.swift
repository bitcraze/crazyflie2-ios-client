//
//  FirmwareLoader.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 10.04.25.
//  Copyright © 2025 Bitcraze. All rights reserved.
//

import Foundation
import Zip

struct ImageFolderMalformed: Error {}
struct MissingDataError: Error {}
struct WebserverError: Error {}
struct ExtractingDataError: Error {}
struct ImageManifestError: Error {
    let description: String
}

final class FirmwareLoader {
    private let releaseUrl = "https://api.github.com/repos/bitcraze/crazyflie-release/releases"
    
    func fetchAvailableFirmwares(_ callback: @escaping (Result<[Firmware], Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: URL(string: releaseUrl)!) {(data, response, error) in
            guard let data = data else {
                NSLog("Error no data for firmware.")
                return
            }
            
            if let error = error  {
                callback(.failure(error))
            }
            
            do {
                let firmwares = try JSONDecoder().decode([Firmware].self, from: data)
                callback(.success(firmwares))
            } catch let e {
                callback(.failure(e))
            }
        }
    }
    
    func fetchFirmware(url: URL, _ callback: @escaping (Result<FirmwareImage, Error>)->()) {
        let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
            guard let data = data else {
                NSLog("Error no data for firmware.")
                OperationQueue.main.addOperation { callback(.failure(MissingDataError())) }
                return
            }
            
            if let error = error  {
                NSLog("Error requesting latest version from github. Error: \(error.localizedDescription)")
                OperationQueue.main.addOperation() { callback(.failure(error)) }
                return
            }
            
            let httpResponse = response as! HTTPURLResponse
            if httpResponse.statusCode != 200 {
                NSLog("Error requesting latest version from github. Response code: \(httpResponse.statusCode)")
                OperationQueue.main.addOperation() { callback(.failure(WebserverError())) }
                return
            }
            
            // Decoding the JSON and initializing a new FirmwareImage object
            
            do {
                let image = try JSONDecoder().decode(FirmwareImage.self, from: data)
                OperationQueue.main.addOperation { callback(.success(image)) }
            } catch let error {
                    NSLog("Error, the data is not json. Data: \(data): \(error)")
                OperationQueue.main.addOperation() { callback(.failure(error)) }
                return
            }
        })
        
        task.resume()
    }
    
    func download(image: FirmwareImage, _ callback: @escaping (String?) -> Void) {
        let task = URLSession.shared.dataTask(with: image.browserDownloadUrl, completionHandler: {(data, response, error) in
            guard let data = data else {
                NSLog("Error empty firmware data)")
                return
            }
            
            if let error = error {
                OperationQueue.main.addOperation() { callback(nil) }
                NSLog("Error downloading the firmware: \(error.localizedDescription)")
                return
            }
            
            let path = NSTemporaryDirectory() + image.fileName
            let downloadPath = URL(fileURLWithPath: path)
            
            if let _ = try? data.write(to: downloadPath, options: []),
                let firmwareData = self.extractTargets(path) {
                OperationQueue.main.addOperation() { callback(path) }
            } else {
                OperationQueue.main.addOperation() { callback(nil) }
            }
        })
        
        task.resume()
    }
    
    private func extractTargets(_ path: String) -> [String: Data]? {
        
        let destination = path.hasSuffix(".zip") ? path.replacingOccurrences(of: ".zip", with: "") : path
        
        try? Zip.unzipFile(
            URL(filePath: path),
            destination: URL(filePath: destination),
            overwrite: true,
            password: nil)
        
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: destination) else {
            return nil
        }

        // Find json and decode it

        guard let manifestEntry = entries.first(where: { $0 == "manifest.json" }) else {
            NSLog("Error extracting the image: no manifest.json")
            return nil
        }

        let json: JSON
        do {
            json = try JSON(data: Data(contentsOf: URL(filePath: destination + "/manifest.json")))
        } catch {
            NSLog("Error extracting the image: json malformed. Error: \(error)")
            return nil
        }

        let version =  json["version"].int
        let files = json["files"].dictionary
        
        if version == nil || version != 1 || files == nil {
            NSLog("Error extracting the image: Wrong version or malformed manifest")
            return nil
        }
        
        var targetFirmwares = [String: Data]()
        
        for (name, content) in files! {
            let platform: String! = content["platform"].string
            let target: String! = content["target"].string
            let type: String! = content["type"].string
            
            if platform == nil || target == nil || type == nil {
                NSLog("Error extracting the image: Malformed manifest")
                return nil
            }
            
            for entry in entries where entry == name {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: destination + "/" + entry)) else {
                    NSLog("Error extracting the image: Malformed firmware for \(name)")
                    return nil
                }
                targetFirmwares["\(platform!)-\(target!)-\(type!)"] = data
            }
        }
        
        return targetFirmwares
    }
}
