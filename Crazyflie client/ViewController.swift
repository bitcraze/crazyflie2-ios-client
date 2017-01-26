//
//  ViewController.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 23.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import UIKit

final class ViewController: UIViewController {
    let leftJoystick: BCJoystick
    let rightJoystick: BCJoystick
    
    weak var viewModel: ViewModel?
    private var settingsViewController: SettingsViewController?
    
    @IBOutlet weak var unlockLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var connectProgress: UIProgressView!
    @IBOutlet weak var leftView: UIView!
    @IBOutlet weak var rightView: UIView!

    func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModel == nil {
            viewModel = ViewModel()
            viewModel.delegate = self
        }
        
        setupUI()
    }
    
    func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        updateUI()
    }
    
    var prefersStatusBarHidden: Bool {
        return true
    }
    
    //MARK: - IBActions
    
    @IBAction func connectClicked(_ sender: Any) {
        viewMode.connect()
    }
    
    @IBAction func settingsClicked(_ sender: Any) {
        performSegue(withIdentifier: "settings", sender: nil)
    }
    
    //MARK: - Private
    
    private func setupUI() {
        connectProgress.progress = 0
        
        connectButton.layer.borderColor = connectButton.tintColor.cgColor
        settingsButton.layer.borderColor = settingsButton.tintColor.cgColor
        
        //Init joysticks
        let frame = UIScreen.main.bounds
        leftJoystick = BCJoystick(frame: frame)
        leftView.addSubview(leftJoystick)
        leftJoystick.addTarget(self, action: #selector(joystickTouched(_:)), forControlEvents: .allEvents)
        
        rightJoystick = BCJoystick(frame: frame)
        rightView.addSubview(rightJoystick)
        rightJoystick.addTarget(self, action: #selector(joystickTouched(_:)), forControlEvents: .allEvents)
        rightJoystick.deadbandX = 0.1;  //Some deadband for the yaw
        rightJoystick.vLabelLeft = true
    }
    
    fileprivate func updateUI() {
        unlockLabel.hidden = viewModel.bothThumbsOnJoystick
        
        leftJoystick.hLabel.text = viewModel?.leftJoystickHorizontalTitle
        leftJoystick.vLabel.text = viewModel?.leftJoystickVerticalTitle
        rightJoystick.hLabel.text = viewModel?.rightJoystickHorizontalTitle
        rightJoystick.vLabel.text = viewModel?.rightJoystickVerticalTitle
    }
    
    private func joystickTouched(_ sender: Any) {
        viewModel.bothThumbsOnJoystick = leftJoystick.activated && rightJoystick.activated
    }
    
    // MARK: - Navigation
    
    func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "settings" {
            
        }
    settingsViewController = [segue destinationViewController];
    settingsViewController.delegate = self;
    settingsViewController.bluetoothLink = self.bluetoothLink;
    
    settingsViewController.controlMode = controlMode;
    settingsViewController.sensitivities = [sensitivities mutableCopy];
    settingsViewController.sensitivitySetting = sensitivitySetting;
    
    [leftJoystick cancel];
    [rightJoystick cancel];
    }
    }
    
    
    #pragma mark - SettingsControllerDelegate
    - (void) closeButtonPressed
    {
    if (settingsViewController) {
    pitchRate = [settingsViewController.pitchrollSensitivity.text floatValue];
    sensitivitySetting = settingsViewController.sensitivitySetting;
    controlMode = (int)settingsViewController.controlMode;
    sensitivities = [settingsViewController.sensitivities mutableCopy];
    [self saveDefault];
    }
    [self dismissViewControllerAnimated:true completion:nil];
    }

}

extension ViewController: ViewModelDelegate {
    func signalUpdate() {
        updateUI()
    }
}
/*
                    
                    - (void) updateSettings: (NSUserDefaults*) defaults
{
    controlMode = [defaults doubleForKey:@];
    NSLog(@"controlMode %d", controlMode);
    sensitivities = (NSMutableDictionary*)[defaults dictionaryForKey:@"sensitivities"];
    sensitivitySetting = [defaults stringForKey:@"sensitivitySettings"];
    
    NSDictionary *sensitivity = (NSDictionary*)[sensitivities valueForKey:sensitivitySetting];
    pitchRate = [(NSNumber*)[sensitivity valueForKey:@"pitchRate"] floatValue];
    yawRate = [(NSNumber*)[sensitivity valueForKey:@"yawRate"] floatValue];
    maxThrust = [(NSNumber*)[sensitivity valueForKey:@"maxThrust"] floatValue];
    
    if ([MotionLink new].canAccessMotion) {
        if (controlMode == 5) {
            [self startMotionUpdate];
        }
        else {
            [self stopMotionUpdate];
        }
        
            }
    else {
        
    }
    
    leftJoystick.deadbandX = 0;
    rightJoystick.deadbandX = 0;
    if ([leftJoystick.hLabel.text isEqualToString:@"Yaw"]) {
        leftJoystick.deadbandX = 0.1;
    } else {
        rightJoystick.deadbandX = 0.1;
    }
    
    leftJoystick.positiveY = NO;
    rightJoystick.positiveY = NO;
    if ([leftJoystick.vLabel.text isEqualToString:@"Thrust"]) {
        leftJoystick.positiveY = YES;
    } else {
        rightJoystick.positiveY = YES;
    }
    }



@end*/
