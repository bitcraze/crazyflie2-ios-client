//
//  BootloaderViewController.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 27/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation
import UIKit

final class BootloaderViewController : UIViewController {
    
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
    
    let firmwareLoader = Dependency.default.firmwareLoader

    // MARK: - UI handling
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.closeButton.layer.borderWidth = 1
        self.closeButton.layer.cornerRadius = 4
        self.closeButton.layer.borderColor = self.closeButton.tintColor?.cgColor
        
        self.updateButton.layer.borderWidth = 1
        self.updateButton.layer.cornerRadius = 4
        self.updateButton.layer.borderColor = self.closeButton.tintColor?.cgColor
        
        self.state = .idle
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        
        self.state = .idle
        
        self.progressIndicator.startAnimating()
        
        self.fetchFirmware()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }
    
    var state:State = .idle {
        didSet {
            OperationQueue.main.addOperation() { self.updateUI() }
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
            self.progressIndicator.isHidden = true
        case .idle:
            self.updateButton.isEnabled = false
            self.closeButton.isEnabled = true
            self.updateButton.setTitle("Update", for: .normal)
            self.progressLabel.text = "Downloading firmware versions from the Internet"
        case .imageFetched:
            self.updateButton.isEnabled = true
            self.closeButton.isEnabled = true
            self.progressIndicator.stopAnimating()
            self.updateButton.setTitle("Update", for: .normal)
            self.progressIndicator.isHidden = true
            self.progressLabel.text = "Ready to Update"
        case .updating:
            self.updateButton.isEnabled = true
            self.closeButton.isEnabled = false
            self.progressIndicator.startAnimating()
            self.progressIndicator.isHidden = false
            self.updateButton.setTitle("Cancel update", for: .normal)
            self.progressLabel.text = "Updating ..."
        }
    }
    
    // MARK: - Image handling
    
    var firmware: FirmwareImage? = nil
    
    func fetchFirmware() {
        NSLog("Fetch firmwares clicked!")
        
        self.progressLabel.text = "Fetching all availabel firmware version informations ..."
        
        firmwareLoader.fetchAvailableFirmwares {[weak self] result in
            switch result {
            case .success(let firmwares):
                self?.progressLabel.text = "Successfully loaded firmware versions"
                let alertController = UIAlertController(title: "Version", message: "Select a firmware version", preferredStyle: .actionSheet)
                firmwares.forEach { firmware in
                    let action = UIAlertAction(title: firmware.name, style: .default) { action in
                        self?.download(firmware: firmware)
                    }
                    alertController.addAction(action)
                }
                let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
                alertController.addAction(cancelAction)
                self?.present(alertController, animated: true)
            case .failure(let error):
                self?.progressLabel.text = "Failed to load firmware versions"
            }
        }
    }
     
    func download(firmware: Firmware) {
        guard let url = firmware.asset.first(where: { asset in
            asset.browserDownloadUrl != nil
        })?.browserDownloadUrl else {
            NSLog("No url from firware")
            return
        }
        NSLog("Download firmware clicked!")
        
        firmwareLoader.fetchFirmware(url: url) { [weak self] result in
            switch result {
            case .success(let image):
                self?.onFirmwareImageFetched(image)
            case .failure(let error):
                NSLog("Failed to download image: \(error)")
                self?.onFirmwareImageFailedLoading(error)
            }
        }
    }
    
    // MARK: - Private
    
    private func onFirmwareImageFetched(_ image: FirmwareImage) {
        self.firmware = image
    
        NSLog("New version fetched!")
        self.versionLabel.text = image.version
        self.descriptionLabel.text = (image.description.split { $0 == "\n" }.map { String($0) })[0]
        
        self.progressLabel.text = "Downloading firmware image ..."
        firmwareLoader.download(image: image) { zipFilePath in
            if zipFilePath != nil {
                self.state = .imageFetched
                var desc = ""
                /*for (name, data) in firmware.targetFirmwares {
                    desc += "\(name): \(data.count/1024)KiB. "
                }*/
                self.descriptionLabel.text = desc
            } else {
                self.descriptionLabel.text =  "Error downloading firmware from the Internet."
                self.state = .error
            }
        }
    }
    
    private func onFirmwareImageFailedLoading(_ error: Error) {
        self.versionLabel.text = "N/A"
        self.descriptionLabel.text =  "N/A"
        self.errorString = "Error fetching version from the Internet."
        self.state = .error
    }
    
    // MARK: - Bootloader logic

    let bootloaderName = "Crazyflie Loader"
    var link: BluetoothLink = BluetoothLink()
    lazy var bootloader: Bootloader = { Bootloader(link: self.link) }()
    
    @IBAction func onUpdateClicked(_ sender: AnyObject) {
        if state == .imageFetched && link.state == .idle {
            progressLabel.text = "Connecting bootloader ..."
            link.connect(self.bootloaderName) { (connected) in
                OperationQueue.main.addOperation() { [weak self] in
                    if connected {
                        self?.state = .updating
                        self?.update()
                    } else {
                        self?.showAlert(title: "Error", message: "Bootloader connection: \(self?.link.error ?? "Unknown")")
                        self?.state = .imageFetched
                    }
                }
            }
        } else if self.state == .updating {
            bootloader.cancel()
            link.disconnect()
            state = .imageFetched
        }
    }
    
    fileprivate func update() {
        bootloader.update(self.firmware!) { (done, progress, status, error) in
            if done && error == nil {
                self.showAlert(
                    title: "Success",
                    message: "Crazyflie successfully updated!\n" +
                             "Press the ON/OFF switch to start new firmware."
                )
                self.link.disconnect()
                self.state = .imageFetched
            } else if done && error != nil {
                self.showAlert(title: "Error updating", message: error!.localizedDescription)
                if self.link.state == .connected {
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
        if self.link.state == .connected {
            self.link.disconnect()
            self.state = .idle
        }
        self.dismiss(animated: true, completion: nil)
    }

    fileprivate func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .cancel))
        show(alert, sender: self)
    }
}
