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
    @IBOutlet weak var progressIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var closeButton: UIButton!
    @IBOutlet weak var updateButton: UIButton!
    
    @IBOutlet var bootloaderUI: [UILabel]!
    
    enum State {
        case Idle, ImageFetched , Updating, Error
    }

    // MARK: - UI handling
    
    override func viewDidLoad() {
        //_closeButton.layer.borderColor = [_closeButton tintColor].CGColor;
        self.closeButton.layer.borderWidth = 1
        self.closeButton.layer.cornerRadius = 4
        self.closeButton.layer.borderColor = self.closeButton.tintColor?.CGColor
        
        self.updateButton.layer.borderWidth = 1
        self.updateButton.layer.cornerRadius = 4
        self.updateButton.layer.borderColor = self.closeButton.tintColor?.CGColor
        
        self.state = .Idle;
    }
    
    override func viewDidAppear(animated: Bool) {
        self.state = .Idle;
        
        self.progressIndicator.startAnimating()
        
        self.fetchFirmware();
    }
    
    var state:State = .Idle {
        didSet {
            NSOperationQueue.mainQueue().addOperationWithBlock() { self.updateUI() };
        }
    }
    
    private var errorString = "Error, try again later."
    
    func updateUI() {
        switch state {
        case .Error:
            self.updateButton.enabled = false
            self.closeButton.enabled = true
            self.updateButton.setTitle("Update", forState: .Normal)
            self.progressLabel.text = self.errorString
            self.progressIndicator.stopAnimating()
            self.progressIndicator.hidden = true;
        case .Idle:
            self.updateButton.enabled = false
            self.closeButton.enabled = true
            self.updateButton.setTitle("Update", forState: .Normal)
            self.progressLabel.text = "Downloading latest firmware from the Internet"
        case .ImageFetched:
            self.updateButton.enabled = true
            self.closeButton.enabled = true
            self.progressIndicator.stopAnimating()
            self.updateButton.setTitle("Update", forState: .Normal)
            self.progressIndicator.hidden = true;
            self.progressLabel.text = "Ready to Update"
        case .Updating:
            self.updateButton.enabled = true
            self.closeButton.enabled = false
            self.progressIndicator.startAnimating()
            self.progressIndicator.hidden = false;
            self.updateButton.setTitle("Cancel update", forState: .Normal)
            self.progressLabel.text = "Updating ..."
        }
    }
    
    // MARK: - Image handling
    
    var firmware: FirmwareImage? = nil
    
    func fetchFirmware() {
        NSLog("Fetch clicked!")
        
        self.progressLabel.text = "Fetching latest version informations ..."
        
        FirmwareImage.fetchLatestWithCallback() { (firmware, nozip) in
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
                        self.state = .Error
                    }
                }
                
            } else {
                self.versionLabel.text = "N/A"
                self.descriptionLabel.text =  "N/A"
                
                if nozip {
                    self.errorString = "No new firmware available."
                } else {
                    self.errorString = "Error fetching version from the Internet."
                }
                self.state = .Error
            }
        }
    }
    
    // MARK: - Bootloader logic

    let bootloaderName = "Crazyflie Loader"
    var link: BluetoothLink = BluetoothLink()
    lazy var bootloader: Bootloader = { Bootloader(link: self.link) }()
    
    @IBAction func onUpdateClicked(sender: AnyObject) {
        if self.state == .ImageFetched && self.link.getState() == "idle" {
            self.progressLabel.text = "Connecting bootloader ..."
            self.link.connect(self.bootloaderName) { (connected) in
                NSOperationQueue.mainQueue().addOperationWithBlock() {
                    if connected {
                        self.state = .Updating
                        self.update()
                    } else {
                        let errorMessage = "Bootloader connection: \(self.link.getError())"
                        UIAlertView(title: "Error", message: errorMessage, delegate: self, cancelButtonTitle: "Ok").show()
                        self.state = .ImageFetched
                    }
                }
            }
        } else if self.state == .Updating {
            self.bootloader.cancel()
            self.link.disconnect()
            self.state = .ImageFetched
        }
    }
    
    private func update() {
        bootloader.update(self.firmware!) { (done, progress, status, error) in
            if done && error == nil {
                UIAlertView(title: "Success", message: "Crazyflie successfuly updated!\n" +
                                                       "Press the ON/OFF switch to start new firmware.",
                            delegate: self, cancelButtonTitle: "Ok").show()
                self.link.disconnect()
                self.state = .ImageFetched
            } else if done && error != nil {
                UIAlertView(title: "Error updating", message: error!.localizedDescription, delegate: self, cancelButtonTitle: "Ok").show()
                if self.link.getState() == "connected" {
                    self.link.disconnect()
                    self.state = .ImageFetched
                } else {
                    self.state = .ImageFetched
                }
            } else { // Just a state update ...
                self.progressLabel.text = status
                self.progressBar.progress = progress
            }
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