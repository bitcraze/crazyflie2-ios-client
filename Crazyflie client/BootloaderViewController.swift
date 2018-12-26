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
        case idle, imageFetched , updating, error
    }

    // MARK: - UI handling
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //_closeButton.layer.borderColor = [_closeButton tintColor].CGColor;
        self.closeButton.layer.borderWidth = 1
        self.closeButton.layer.cornerRadius = 4
        self.closeButton.layer.borderColor = self.closeButton.tintColor?.cgColor
        
        self.updateButton.layer.borderWidth = 1
        self.updateButton.layer.cornerRadius = 4
        self.updateButton.layer.borderColor = self.closeButton.tintColor?.cgColor
        
        self.state = .idle;
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.state = .idle;
        
        self.progressIndicator.startAnimating()
        
        self.fetchFirmware();
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    var state:State = .idle {
        didSet {
            OperationQueue.main.addOperation() { self.updateUI() };
        }
    }
    
    fileprivate var errorString = "Error, try again later."
    
    func updateUI() {
        switch state {
        case .error:
            self.updateButton.isEnabled = false
            self.closeButton.isEnabled = true
            self.updateButton.setTitle("Update", for: .normal)
            self.progressLabel.text = self.errorString
            self.progressIndicator.stopAnimating()
            self.progressIndicator.isHidden = true;
        case .idle:
            self.updateButton.isEnabled = false
            self.closeButton.isEnabled = true
            self.updateButton.setTitle("Update", for: .normal)
            self.progressLabel.text = "Downloading latest firmware from the Internet"
        case .imageFetched:
            self.updateButton.isEnabled = true
            self.closeButton.isEnabled = true
            self.progressIndicator.stopAnimating()
            self.updateButton.setTitle("Update", for: .normal)
            self.progressIndicator.isHidden = true;
            self.progressLabel.text = "Ready to Update"
        case .updating:
            self.updateButton.isEnabled = true
            self.closeButton.isEnabled = false
            self.progressIndicator.startAnimating()
            self.progressIndicator.isHidden = false;
            self.updateButton.setTitle("Cancel update", for: .normal)
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
                self.descriptionLabel.text = (firmware.description.split { $0 == "\n" }.map { String($0) })[0]
                
                self.progressLabel.text = "Downloading firmware image ..."
                firmware.download() { (success) in
                    if success {
                        self.state = .imageFetched
                        var desc = ""
                        for (name, data) in firmware.targetFirmwares {
                            desc += "\(name): \(data.count/1024)KiB. "
                        }
                        self.descriptionLabel.text = desc
                    } else {
                        self.descriptionLabel.text =  "Error downloading firmware from the Internet."
                        self.state = .error
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
                self.state = .error
            }
        }
    }
    
    // MARK: - Bootloader logic

    let bootloaderName = "Crazyflie Loader"
    var link: BluetoothLink = BluetoothLink()
    lazy var bootloader: Bootloader = { Bootloader(link: self.link) }()
    
    @IBAction func onUpdateClicked(_ sender: AnyObject) {
        if self.state == .imageFetched && self.link.getState() == "idle" {
            self.progressLabel.text = "Connecting bootloader ..."
            self.link.connect(self.bootloaderName) { (connected) in
                OperationQueue.main.addOperation() {
                    if connected {
                        self.state = .updating
                        self.update()
                    } else {
                        let errorMessage = "Bootloader connection: \(self.link.getError())"
                        UIAlertView(title: "Error", message: errorMessage, delegate: self, cancelButtonTitle: "Ok").show()
                        self.state = .imageFetched
                    }
                }
            }
        } else if self.state == .updating {
            self.bootloader.cancel()
            self.link.disconnect()
            self.state = .imageFetched
        }
    }
    
    fileprivate func update() {
        bootloader.update(self.firmware!) { (done, progress, status, error) in
            if done && error == nil {
                UIAlertView(title: "Success", message: "Crazyflie successfuly updated!\n" +
                                                       "Press the ON/OFF switch to start new firmware.",
                            delegate: self, cancelButtonTitle: "Ok").show()
                self.link.disconnect()
                self.state = .imageFetched
            } else if done && error != nil {
                UIAlertView(title: "Error updating", message: error!.localizedDescription, delegate: self, cancelButtonTitle: "Ok").show()
                if self.link.getState() == "connected" {
                    self.link.disconnect()
                    self.state = .imageFetched
                } else {
                    self.state = .imageFetched
                }
            } else { // Just a state update ...
                self.progressLabel.text = status
                self.progressBar.progress = progress
            }
        }
    }
    
    @IBAction func onCloseClicked(_ sender: AnyObject) {
        if self.link.getState() == "connected" {
            self.link.disconnect()
            self.state = .idle
        }
        self.dismiss(animated: true, completion: nil)
    }
}
