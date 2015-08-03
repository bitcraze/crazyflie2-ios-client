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
    
    @IBOutlet weak var fetchButton: UIButton!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var updateButton: UIButton!
    @IBOutlet weak var closeButton: UIButton!
    
    enum State {
        case Idle, ImageFetched, BootloaderConnected, Updating
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
            self.fetchButton.enabled = true
            self.connectButton.enabled = false
            self.updateButton.enabled = false
            self.closeButton.enabled = true
            self.connectButton.setTitle("Connect bootloader", forState: .Normal)
            self.updateButton.setTitle("Update", forState: .Normal)
            self.progressLabel.text = "IDLE"
        case .ImageFetched:
            self.fetchButton.enabled = true
            self.connectButton.enabled = true
            self.updateButton.enabled = false
            self.closeButton.enabled = true
            self.connectButton.setTitle("Connect bootloader", forState: .Normal)
            self.updateButton.setTitle("Update", forState: .Normal)
            self.progressLabel.text = "Ready to connect bootloader"
        case .BootloaderConnected:
            self.fetchButton.enabled = true
            self.connectButton.enabled = true
            self.updateButton.enabled = true
            self.closeButton.enabled = true
            self.connectButton.setTitle("Diconnnect bootloader", forState: .Normal)
            self.updateButton.setTitle("Update", forState: .Normal)
            self.progressLabel.text = "Ready to update"
        case .Updating:
            self.fetchButton.enabled = false
            self.connectButton.enabled = false
            self.updateButton.enabled = true
            self.closeButton.enabled = false
            self.connectButton.setTitle("Diconnnect bootloader", forState: .Normal)
            self.updateButton.setTitle("Cancel update", forState: .Normal)
            self.progressLabel.text = "Updating ..."
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
    var link: BluetoothLink = BluetoothLink()
    lazy var bootloader: Bootloader = { Bootloader(link: self.link) }()
    
    @IBAction func onConnectClicked(sender: UIButton) {
        if self.state == .ImageFetched && self.link.getState() == "idle" {
            self.progressLabel.text = "Connecting bootloader ..."
            self.connectButton.enabled = false
            self.link.connect(self.bootloaderName) { (connected) in
                NSOperationQueue.mainQueue().addOperationWithBlock() {
                    if connected {
                        self.state = .BootloaderConnected
                    } else {
                        let errorMessage = "Bootloader connection: \(self.link.getError())"
                        UIAlertView(title: "Error", message: errorMessage, delegate: self, cancelButtonTitle: "Ok").show()
                        self.state = .ImageFetched
                    }
                }
            }
        } else if self.state == .BootloaderConnected {
            self.link.disconnect()
            self.state = .ImageFetched
        }
    }
    
    @IBAction func onUpdateClicked(sender: UIButton) {
        if self.state == .BootloaderConnected {
            self.state = .Updating
            bootloader.update(self.firmware!) { (done, progress, status, error) in
                if done && error == nil {
                    UIAlertView(title: "Success", message: "Crazyflie successfuly updated!", delegate: self, cancelButtonTitle: "Ok").show()
                    self.state = .BootloaderConnected
                } else if done && error != nil {
                    UIAlertView(title: "Error updating", message: error!.localizedDescription, delegate: self, cancelButtonTitle: "Ok").show()
                    if self.link.getState() == "connected" {
                        self.state = .BootloaderConnected
                    } else {
                        self.state = .ImageFetched
                    }
                } else { // Just a state update ...
                    self.progressLabel.text = status
                    self.progressBar.progress = progress
                }
            }
        } else if self.state == .Updating {
            self.bootloader.cancel()
        }
    }
    
    @IBAction func onCloseClicked(sender: AnyObject) {
        if self.link.getState() == "connected" {
            self.link.disconnect()
            self.state = .Idle
        }
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}