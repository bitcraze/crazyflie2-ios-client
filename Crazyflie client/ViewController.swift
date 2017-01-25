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
    
    - (void) joystickMoved: (BCJoystick*)joystick
{
    NSLog(@"Joystick moved to %f,%f.", joystick.x, joystick.y);
}

-(void) joystickTouch:(BCJoystick *)jostick
{
    if (leftJoystick.activated && rightJoystick.activated) {
        self.unlockLabel.hidden = true;
        locked = NO;
        [self.motionLink calibrate];
    } else if (!leftJoystick.activated && !rightJoystick.activated) {
        self.unlockLabel.hidden = false;
        locked = YES;
    }
    }
    
    - (void)didReceiveMemoryWarning
        {
            [super didReceiveMemoryWarning];
            // Dispose of any resources that can be recreated.
        }
        
        - (IBAction)connectClick:(id)sender {
            #ifdef TEST
            sent = YES;
            self.commanderTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(sendCommander:) userInfo:nil repeats:YES];
            #else
            if ([[self.bluetoothLink getState]  isEqualToString:@"idle"]) {
            [self.bluetoothLink connect:nil callback: ^ (BOOL connected) {
            if (connected) {
            NSLog(@"Connected!");
            
            // Start sending commander update
            sent = YES;
            self.commanderTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(sendCommander:) userInfo:nil repeats:YES];
            } else { // Not connected, connection error!
            NSString * title;
            NSString * body;
            
            if (self.commanderTimer) {
            [self.commanderTimer invalidate];
            self.commanderTimer = nil;
            }
            
            // Find the reason and prepare a message
            if ([[_bluetoothLink getError] isEqualToString:@"Bluetooth disabled"]) {
            title = @"Bluetooth disabled";
            body = @"Please enable Bluetooth to connect a Crazyflie";
            } else if ([[_bluetoothLink getError] isEqualToString:@"Timeout"]) {
            title = @"Connection timeout";
            body = @"Could not find Crazyflie";
            } else {
            title = @"Error";
            body = [_bluetoothLink getError];
            }
            
            // Display the message
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
            message:body
            delegate:nil
            cancelButtonTitle:@"OK"
            otherButtonTitles:nil];
            [alert show];
            }
            }];
            } else { // Already connected or connecting, disconnecting...
            [self.bluetoothLink disconnect];
            
            [self.commanderTimer invalidate];
            self.commanderTimer = nil;
            }
            #endif
            }
            
            - (IBAction)settingsClick:(id)sender {
                [self performSegueWithIdentifier:@"settings" sender:nil];
}

-(void) sendCommander: (NSTimer*)timer
{
    struct __attribute__((packed)) {
        uint8_t header;
        float roll;
        float pitch;
        float yaw;
        uint16_t thrust;
    } commanderPacket;
    // Mode sorted by pitch, roll, yaw, thrust versus lx, ly, rx, ry
    static const int mode2axis[5][4] = {{1, 2, 0, 3},
        {3, 2, 0, 1},
        {1, 0, 2, 3},
        {3, 0, 2, 1},
        {1, 0, 2, 3}};
    float joysticks[4];
    float jsPitch, jsRoll, jsYaw, jsThrust;
    bool enableNegativeValues = NO;
    
    if (locked == NO
        && self.motionLink.accelerationUpdateActive) {
        CMAcceleration a =  self.motionLink.calibratedAcceleration;
        enableNegativeValues = YES;
        joysticks[0] = a.x;
        joysticks[1] = a.y;
        joysticks[2] = leftJoystick.x;
        joysticks[3] = rightJoystick.y;
    } else if (locked == NO) {
        joysticks[0] = leftJoystick.x;
        joysticks[1] = leftJoystick.y;
        joysticks[2] = rightJoystick.x;
        joysticks[3] = rightJoystick.y;
    } else {
        joysticks[0] = 0;
        joysticks[1] = 0;
        joysticks[2] = 0;
        joysticks[3] = 0;
    }
    
    jsPitch  = joysticks[mode2axis[controlMode-1][0]];
    jsRoll   = joysticks[mode2axis[controlMode-1][1]];
    jsYaw    = joysticks[mode2axis[controlMode-1][2]];
    jsThrust = joysticks[mode2axis[controlMode-1][3]];
    
    if (sent) {
        NSLog(@"Send commander!");
        NSData *data;
        
        commanderPacket.header = 0x30;
        
        if (LINEAR_PR) {
            if (jsPitch >= 0
                || enableNegativeValues) {
                commanderPacket.pitch = jsPitch*-1*pitchRate;
            }
            if (jsRoll >= 0
                || enableNegativeValues) {
                commanderPacket.roll = jsRoll*pitchRate;
            }
        } else {
            if (jsPitch >= 0) {
                commanderPacket.pitch = pow(jsPitch, 2) * -1 * pitchRate * ((jsPitch>0)?1:-1);
            }
            if (jsRoll >= 0) {
                commanderPacket.roll = pow(jsRoll, 2) * pitchRate * ((jsRoll>0)?1:-1);
            }
        }
        
        if (yawRate >= 0) {
            commanderPacket.yaw = jsYaw * yawRate;
        }
        
        int thrust;
        if (LINEAR_THRUST) {
            thrust = jsThrust*65535*(maxThrust/100);
        } else {
            thrust = sqrt(jsThrust)*65535*(maxThrust/100);
        }
        if (thrust>65535) thrust = 65535;
        if (thrust < 0) thrust = 0;
        commanderPacket.thrust = thrust;
        NSLog(@"pith: %f - roll: %f - yaw: %f - thrust: %f", commanderPacket.pitch, commanderPacket.roll, commanderPacket.yaw, commanderPacket.thrust);
        
        data = [NSData dataWithBytes:&commanderPacket length:sizeof(commanderPacket)];
        
        #ifndef TEST
        sent = NO;
        [_bluetoothLink sendPacket:data callback: ^(BOOL success) {
        sent = YES;
        }];
#endif
} else {
    NSLog(@"Missed commander update!");
}
}

- (BOOL) prefersStatusBarHidden
    {
        return YES;
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    NSLog(@"Prepare for segue %@", segue.identifier);
    
    if ([segue.identifier  isEqual: @"settings"]) {
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

@end*/
