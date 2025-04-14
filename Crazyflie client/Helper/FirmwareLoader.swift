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
                DispatchQueue.main.async {
                    callback(.failure(error))
                }
            }
            
            do {
                let firmwares = try JSONDecoder().decode([Firmware].self, from: data)
                DispatchQueue.main.async {
                    callback(.success(firmwares))
                }
            } catch let e {
                DispatchQueue.main.async {
                    callback(.failure(e))
                }
            }
        }
        task.resume()
    }
    
    func fetchFirmware(url: URL, _ callback: @escaping (Result<FirmwareImage, Error>)->()) {
        let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
            guard let data = data else {
                NSLog("Error no data for firmware.")
                DispatchQueue.main.async {
                    callback(.failure(MissingDataError()))
                }
                return
            }
            
            if let error = error  {
                NSLog("Error requesting latest version from github. Error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    callback(.failure(error))
                }
                return
            }
            
            let httpResponse = response as! HTTPURLResponse
            if httpResponse.statusCode != 200 {
                NSLog("Error requesting latest version from github. Response code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    callback(.failure(WebserverError()))
                }
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
    
    func download(firmware: Firmware,
                  progress: @escaping (String) -> Void,
                  callback: @escaping (Result<Firmware, Error>) -> Void) {
        guard let url = firmware.assets.first(where: { $0.browserDownloadUrl != nil })?.browserDownloadUrl else {
            callback(.failure(MissingDataError()))
            return
        }
        progress("Start downloading firmware")
        
        let task = URLSession.shared.dataTask(with: url, completionHandler: {(data, response, error) in
            guard let data = data else {
                NSLog("Error empty firmware data)")
                callback(.failure(MissingDataError()))
                return
            }
            
            if let error = error {
                DispatchQueue.main.async {
                    callback(.failure(error))
                }
                NSLog("Error downloading the firmware: \(error.localizedDescription)")
                return
            }
            
            DispatchQueue.main.async {
                progress("Firmware downloaded .. extracting ..")
            }
            
            let path = NSTemporaryDirectory() + firmware.name + ".zip"
            let downloadPath = URL(fileURLWithPath: path)
            
            do {
                try data.write(to: downloadPath, options: [])
                let firmwareData = try self.extractTargets(path)
                DispatchQueue.main.async {
                    var newFirmware = Firmware(name: firmware.name, assets: firmware.assets)
                    newFirmware.targetFirmwares = firmwareData
                    callback(.success(newFirmware))
                }
            } catch let e {
                DispatchQueue.main.async {
                    callback(.failure(ExtractingDataError()))
                }
            }
        })
        
        task.resume()
    }
    
    private func extractTargets(_ path: String) throws -> [String: Data] {
        
        let destination = path.hasSuffix(".zip") ? path.replacingOccurrences(of: ".zip", with: "") : path
        let zipFileUrl = URL(fileURLWithPath: path)
        let destinationPath = URL(fileURLWithPath: destination)
        
        try? Zip.unzipFile(
            zipFileUrl,
            destination: destinationPath,
            overwrite: true,
            password: nil)
        
        let fileManager = FileManager.default
        guard let entries = try? fileManager.contentsOfDirectory(atPath: destination) else {
            throw ImageFolderMalformed()
        }

        // Find json and decode it

        guard entries.first(where: { $0 == "manifest.json" }) != nil else {
            NSLog("Error extracting the image: no manifest.json")
            throw ImageFolderMalformed()
        }

        let manifest: ImageManifest
        do {
            manifest = try JSONDecoder().decode(ImageManifest.self, from: Data(contentsOf: URL(fileURLWithPath: destination + "/manifest.json")))
        } catch {
            NSLog("Error extracting the image: json malformed. Error: \(error)")
            throw ImageManifestError(description: "Image Version malformed. Try a different version")
        }

        let version =  manifest.version
        let files = manifest.files
        
        if version != 1 {
            NSLog("Error extracting the image: Wrong version")
            throw ImageManifestError(description: "Version not supported. Try a different version")
        }
        
        var targetFirmwares = [String: Data]()
        
        for (name, content) in files {
            let platform = content.platform
            let target = content.target
            let type = content.type
            
            for entry in entries where entry == name {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: destination + "/" + entry)) else {
                    NSLog("Error extracting the image: Malformed firmware for \(name)")
                    throw ImageManifestError(description: "Malformed firmware for \(name)")
                }
                targetFirmwares["\(platform)-\(target)-\(type)"] = data
            }
        }
        
        return targetFirmwares
    }
}
