//
//  BootloaderViewController.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 27/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation
import UIKit

class BootloaderViewController : UIViewController {
    
    @IBOutlet weak var versionLabel: UILabel!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var progressBar: UIProgressView!
    
    @IBOutlet weak var connectButton: UIButton!
    
    enum State {
        case Idle, ImageFetched, BootloaderConnected
    }

    // MARK: - UI handling
    
    var state:State = .Idle {
        didSet {
            NSOperationQueue.mainQueue().addOperationWithBlock() { self.updateUI() };
        }
    }
    
    func updateUI() {
        switch state {
        case .Idle:
            self.connectButton.enabled = false
            self.connectButton.setTitle("Connect bootloader", forState: UIControlState.Normal)
            self.progressLabel.text = "IDLE"
        case .ImageFetched:
            self.connectButton.enabled = true
            self.connectButton.setTitle("Connect bootloader", forState: UIControlState.Normal)
            self.progressLabel.text = "Ready to connect bootloader"
        case .BootloaderConnected:
            self.connectButton.enabled = true
            self.connectButton.setTitle("Diconnnect bootloader", forState: UIControlState.Normal)
            self.progressLabel.text = "Ready to update"
        }
    }
    
    // MARK: - Image handling
    
    var firmware: FirmwareImage? = nil
    
    @IBAction func onFetchClicked(sender: UIButton) {
        NSLog("Fetch clicked!")
        
        self.progressLabel.text = "Fetching latest version informations ..."
        
        FirmwareImage.fetchLatestWithCallback() { (firmware) in
            self.firmware = firmware
            if let firmware = self.firmware {
                NSLog("New version fetched!")
                self.versionLabel.text = firmware.version
                self.descriptionLabel.text = (split(firmware.description) { $0 == "\n" })[0]
                
                self.progressLabel.text = "Downloading firmware image ..."
                firmware.download() { (success) in
                    if success {
                        self.state = .ImageFetched
                        var desc = ""
                        for (name, data) in firmware.targetFirmwares {
                            desc += "\(name): \(data.length) Bytes "
                        }
                        self.descriptionLabel.text = desc
                    } else {
                        self.descriptionLabel.text =  "Error downloading firmware from the Internet."
                        self.state = .Idle
                    }
                }
                
            } else {
                self.versionLabel.text = "N/A"
                self.descriptionLabel.text =  "Error fetching version from the Internet."
                self.state = .Idle
            }
        }
    }
    
    // MARK: - Bootloader logic

    let bootloaderName = "Crazyflie Loader"
    
    @IBAction func onConnectClicked(sender: UIButton) {
        	
    }
    
}