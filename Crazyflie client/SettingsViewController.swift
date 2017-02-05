//
//  SettingsViewController.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 24.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import UIKit

final class SettingsViewController: UIViewController {
    var viewModel: SettingsViewModel?
    
    @IBOutlet weak var pitchrollSensitivity: UITextField!
    @IBOutlet weak var thrustSensitivity: UITextField!
    @IBOutlet weak var yawSensitivity: UITextField!
    @IBOutlet weak var sensitivitySelector: UISegmentedControl!
    @IBOutlet weak var controlModeSelector: UISegmentedControl!
    
    @IBOutlet weak var leftXLabel: UILabel!
    @IBOutlet weak var leftYLabel: UILabel!
    @IBOutlet weak var rightXLabel: UILabel!
    @IBOutlet weak var rightYLabel: UILabel!
    @IBOutlet weak var closeButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewModel?.delegate = self
        updateUI()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        viewModel?.delegate = nil
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        closeButton.layer.borderColor = closeButton.tintColor.cgColor
        
        if MotionLink().canAccessMotion {
            controlModeSelector.insertSegment(withTitle: "Tilt Mode", at: 4, animated: true)
        }
    }
    
    fileprivate func updateUI() {
        guard let viewModel = viewModel else {
            return
        }
        
        sensitivitySelector.selectedSegmentIndex = viewModel.sensitivity.index
        controlModeSelector.selectedSegmentIndex = viewModel.controlMode.index
        
        leftXLabel.text = viewModel.leftXTitle
        leftYLabel.text = viewModel.leftYTitle
        rightXLabel.text = viewModel.rightXTitle
        rightYLabel.text = viewModel.rightYTitle
    }
    
    @IBAction func sensitivityModeChanged(_ sender: Any) {
        viewModel?.didSetSensitivityMode(at: sensitivitySelector.selectedSegmentIndex)
    }
    
    @IBAction func controlModeChanged(_ sender: Any) {
        viewModel?.didSetControlMode(at: controlModeSelector.selectedSegmentIndex)
    }
    
    @IBAction func closeClicked(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onBootloaderClicked( _ sender: Any) {
        viewModel?.bootloaderClicked()
    }
}

extension SettingsViewController: SettingsViewModelDelegate {
    func didUpdate() {
        updateUI()
    }
}
