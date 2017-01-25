//
//  SettinbsViewModel.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 24.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

protocol SettingsViewModelDelegate {
    func didUpdate()
}

final class SettingsViewModel {
 
    enum Sensitivity: String {
        case slow = "slow"
        case fast = "fast"
        case custom = "custom"
        
        var index: Int {
            switch self {
            case .slow:
                return 0
            case .fast:
                return 1
            case .custom:
                return 2
            }
        }
    }
    
    enum ControlMode: Int {
        case slow = "slow"
        case fast = "fast"
        case custom = "custom"
        
        var index: Int {
            switch self {
            case .slow:
                return 0
            case .fast:
                return 1
            case .custom:
                return 2
            }
        }
    }
    
    weak var delegate: SettingsViewModelDelegate?
    
    private let bluetoothLink: BluetoothLink
    
    init(bluetoothLink: BluetoothLink) {
        self.bluetoothLink = bluetoothLink
    }
    
    var sensitivity: Sensitivity
    var controlMode: ControlMode
}

/*
    if ([self.sensitivitySetting isEqualToString:@"slow"])
    self.sensitivitySelector.selectedSegmentIndex = 0;
    else if ([self.sensitivitySetting isEqualToString:@"fast"])
    self.sensitivitySelector.selectedSegmentIndex = 1;
    else if ([self.sensitivitySetting isEqualToString:@"custom"])
    self.sensitivitySelector.selectedSegmentIndex = 2;
    
    if ([MotionLink new].canAccessMotion) {
        [self.controlModeSelector insertSegmentWithTitle:@"Tilt Mode" atIndex:4 animated:YES];
    }
    
    self.controlModeSelector.selectedSegmentIndex = self.controlMode-1;
    
    [self sensitivityChanged:self.sensitivitySelector];
    [self modeChanged:self.controlModeSelector];
    
    [self.view addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self.view action:@selector(endEditing:)]];
    }
    
    - (void)didReceiveMemoryWarning {
        [super didReceiveMemoryWarning];
        // Dispose of any resources that can be recreated.
        }
        
        - (IBAction)closeClicked:(id)sender {
            if (self.delegate) {
                [self.delegate closeButtonPressed];
            }
            }
            - (IBAction)sensitivityChanged:(id)sender {
                NSArray *selectorNames = @[@"slow", @"fast", @"custom"];
                
                self.sensitivitySetting = selectorNames[self.sensitivitySelector.selectedSegmentIndex];
                NSDictionary *sensitivity =  [self.sensitivities valueForKey:self.sensitivitySetting];
                
                self.pitchrollSensitivity.text = [[sensitivity valueForKey:@"pitchRate"] stringValue];
                self.thrustSensitivity.text = [[sensitivity valueForKey:@"maxThrust"] stringValue];
                self.yawSensitivity.text = [[sensitivity valueForKey:@"yawRate"] stringValue];
                
                switch (self.sensitivitySelector.selectedSegmentIndex) {
                case 0:
                case 1:
                    self.pitchrollSensitivity.enabled = NO;
                    self.thrustSensitivity.enabled = NO;
                    self.yawSensitivity.enabled = NO;
                    break;
                case 2:
                    self.pitchrollSensitivity.enabled = YES;
                    self.thrustSensitivity.enabled = YES;
                    self.yawSensitivity.enabled = YES;
                    break;
                }
                }
                - (IBAction)modeChanged:(id)sender {
                    self.controlMode = (int)self.controlModeSelector.selectedSegmentIndex+1;
                    
                    if ([MotionLink new].canAccessMotion) {
                        _leftXLabel.text = [mode2str[_controlMode-1][0] copy];
                        _leftYLabel.text = [mode2str[_controlMode-1][1] copy];
                        _rightXLabel.text = [mode2str[_controlMode-1][2] copy];
                        _rightYLabel.text = [mode2str[_controlMode-1][3] copy];
                    }
                    else {
                        _leftXLabel.text = [mode2strNoMotion[_controlMode-1][0] copy];
                        _leftYLabel.text = [mode2strNoMotion[_controlMode-1][1] copy];
                        _rightXLabel.text = [mode2strNoMotion[_controlMode-1][2] copy];
                        _rightYLabel.text = [mode2strNoMotion[_controlMode-1][3] copy];
                    }
                    }
                    
                    - (IBAction)endEditing:(id)sender {
                        if ([self.sensitivitySetting isEqualToString:@"custom"]) {
                            //Check settings range and correct them automatically if required
                            NSInteger pitchRate = [self.pitchrollSensitivity.text integerValue];
                            NSInteger yawRate = [self.yawSensitivity.text integerValue];
                            NSInteger maxThrust = [self.thrustSensitivity.text integerValue];
                            
                            if (pitchRate<0)
                            pitchRate = 0;
                            if (pitchRate>80)
                            pitchRate = 80;
                            if (yawRate<0)
                            yawRate = 0;
                            if (yawRate>500)
                            yawRate = 500;
                            if (maxThrust<0)
                            maxThrust = 0;
                            if (maxThrust>100)
                            maxThrust = 100;
                            
                            // Write the correctef values
                            self.pitchrollSensitivity.text = [NSString stringWithFormat:@"%ld", (long)pitchRate];
                            self.yawSensitivity.text = [NSString stringWithFormat:@"%ld", (long)yawRate];
                            self.thrustSensitivity.text = [NSString stringWithFormat:@"%ld", (long)maxThrust];
                            
                            NSDictionary * customSensitivity = @{@"pitchRate": [NSNumber numberWithLong:pitchRate],
                                @"yawRate": [NSNumber numberWithLong:yawRate],
                                @"maxThrust": [NSNumber numberWithLong:maxThrust]};
                            
                            [self.sensitivities setValue:customSensitivity forKey:@"custom"];
                        }
                        }
                        
                        /*
                         #pragma mark - Navigation
                         
                         // In a storyboard-based application, you will often want to do a little preparation before navigation
                         - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
                         // Get the new view controller using [segue destinationViewController].
                         // Pass the selected object to the new view controller.
                         }
                         */
                        - (IBAction)onBootloaderClicked:(id)sender {
                            if (self.bluetoothLink && [[self.bluetoothLink getState] isEqualToString:@"connected"]) {
                                [self.bluetoothLink disconnect];
                            }
}

@end


