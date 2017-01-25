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
    
    @IBOutlet weak var leftYLabel: UILabel!
    @IBOutlet weak var leftXLabel: UILabel!
    @IBOutlet weak var rightYLabel: UILabel!
    @IBOutlet weak var leftYLabel: UILabel!
    @IBOutlet weak var rightXLabel: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }
    
    // MARK: - Private Methods
    
    private func setupUI() {
        closeButton.layer.borderColor = closeButton.tintColor.cgColor
        
        if MotionLink().canAccessMotion {
            controlModeSelector.insertSegment(withTitle: "Tilt Mode", at: 4, animated: true)
        }
    }
    
    private func updateUI() {
        sensitivitySelector.selectedSegmentIndex = viewModel?.sensitivity.index
        controlModeSelector.selectedSegmentIndex = viewModel.
    }
    
                self.controlModeSelector.selectedSegmentIndex = self.controlMode-1;
                
                [self sensitivityChanged:self.sensitivitySelector];
                [self modeChanged:self.controlModeSelector];
                
                [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self.view action:@selector(endEditing:)]];
        }
    }
    
    @IBAction func closeButtonPressed(_ sender: Any) {
        
    }
    
    
    @required
    - (void) closeButtonPressed;
    @end
    
    @property (nonatomic, strong) id delegate;
    
    
    @property () NSInteger controlMode;
    @property (strong, nonatomic) NSMutableDictionary *sensitivities;
    @property (weak, nonatomic) NSString *sensitivitySetting;
}
