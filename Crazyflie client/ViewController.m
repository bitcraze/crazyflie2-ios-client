/*
 *    ||          ____  _ __
 * +------+      / __ )(_) /_______________ _____  ___
 * | 0xBC |     / __  / / __/ ___/ ___/ __ `/_  / / _ \
 * +------+    / /_/ / / /_/ /__/ /  / /_/ / / /_/  __/
 *  ||  ||    /_____/_/\__/\___/_/   \__,_/ /___/\___/
 *
 * Crazyflie ios client
 *
 * Copyright (C) 2014 BitCraze AB
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, in version 3.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <http://www.gnu.org/licenses/>.
 *
 * ViewController.m: View controller. Handles app life cycle and BLE connection.
 */

#import "ViewController.h"
#import "BCJoystick.h"
#import <CoreBluetooth/CoreBluetooth.h>

#import <Crazyflie_client-Swift.h>

#define LINEAR_PR YES
#define LINEAR_THRUST YES
//#define TEST YES

@interface ViewController () {
    BCJoystick *leftJoystick;
    BCJoystick *rightJoystick;
    bool sent;
    
    bool locked;
    
    float pitchRate;
    float yawRate;
    float maxThrust;
    int controlMode;
    
    enum {stateIdle, stateScanning, stateConnecting, stateConnected} state;
    
    SettingsViewController *settingsViewController;
    
    NSMutableDictionary *sensitivities;
    NSString *sensitivitySetting;
}

@property (weak, nonatomic) IBOutlet UILabel *unlockLabel;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIButton *settingsButton;
@property (weak, nonatomic) IBOutlet UIProgressView *connectProgress;

@property (weak, nonatomic) IBOutlet UIView *leftView;
@property (weak, nonatomic) IBOutlet UIView *rightView;

@property (strong) BluetoothLink *bluetoothLink;
@property (strong) MotionLink *motionLink;

@property (strong) NSTimer *commanderTimer;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Init instance variables
    self.connectProgress.progress = 0;
    
    sent = NO;
    state = stateIdle;
    locked = YES;
    
    //Init button border color
    _connectButton.layer.borderColor = [_connectButton tintColor].CGColor;
    _settingsButton.layer.borderColor = [_settingsButton tintColor].CGColor;
    
    //Init joysticks
    CGRect frame = [[UIScreen mainScreen] bounds];
    leftJoystick = [[BCJoystick alloc] initWithFrame:frame];
    [_leftView addSubview:leftJoystick];
    [leftJoystick addTarget:self action:@selector(joystickTouch:) forControlEvents:UIControlEventAllTouchEvents];
    
    rightJoystick = [[BCJoystick alloc] initWithFrame:frame];
    [_rightView addSubview:rightJoystick];
    [rightJoystick addTarget:self action:@selector(joystickTouch:) forControlEvents:UIControlEventAllTouchEvents];
    rightJoystick.deadbandX = 0.1;  //Some deadband for the yaw
    rightJoystick.vLabelLeft = YES;
    
    [self loadDefault];
    
    self.bluetoothLink = [[BluetoothLink alloc] init];
    
    // Update GUI when connection state changes
    [_bluetoothLink onStateUpdated: ^(NSString *newState) {
        if ([newState isEqualToString:@"idle"]) {
            [self.connectProgress setProgress:0 animated:NO];
            [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
        } else if ([newState isEqualToString:@"scanning"]) {
            [self.connectProgress setProgress:0 animated:NO];
            [self.connectButton setTitle:@"Cancel" forState:UIControlStateNormal];
        } else if ([newState isEqualToString:@"connecting"]) {
            [self.connectProgress setProgress:0.25 animated:YES];
            [self.connectButton setTitle:@"Cancel" forState:UIControlStateNormal];
        } else if ([newState isEqualToString:@"services"]) {
            [self.connectProgress setProgress:0.5 animated:YES];
            [self.connectButton setTitle:@"Cancel" forState:UIControlStateNormal];
        } else if ([newState isEqualToString:@"characteristics"]) {
            [self.connectProgress setProgress:0.75 animated:YES];
            [self.connectButton setTitle:@"Cancel" forState:UIControlStateNormal];
        } else if ([newState isEqualToString:@"connected"]) {
            [self.connectProgress setProgress:1 animated:YES];
            [self.connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
        }
    }];
}

- (void) startMotionUpdate
{
    if (self.motionLink == nil) {
        self.motionLink = [[MotionLink alloc] init];
    }
    [self.motionLink startDeviceMotionUpdates:nil];
    [self.motionLink startAccelerometerUpdates:nil];
}

- (void) stopMotionUpdate
{
    [self.motionLink stopDeviceMotionUpdates];
    [self.motionLink stopAccelerometerUpdates];
}

- (void) loadDefault
{
    NSURL *defaultPrefsFile = [[NSBundle mainBundle] URLForResource:@"DefaultPreferences" withExtension:@"plist"];
    NSDictionary *defaultPrefs = [NSDictionary dictionaryWithContentsOfURL:defaultPrefsFile];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults registerDefaults:defaultPrefs];
    
    [self updateSettings:defaults];
}

- (void) saveDefault
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    [defaults setObject:[NSNumber numberWithInt:controlMode] forKey:@"controlMode"];
    [defaults setObject:sensitivities forKey:@"sensitivities"];
    [defaults setObject:sensitivitySetting forKey:@"sensitivitySettings"];
    
    [self updateSettings:defaults];
}

- (void) updateSettings: (NSUserDefaults*) defaults
{
    controlMode = [defaults doubleForKey:@"controlMode"];
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
        
        leftJoystick.hLabel.text = [mode2str[controlMode-1][0] copy];
        leftJoystick.vLabel.text = [mode2str[controlMode-1][1] copy];
        rightJoystick.hLabel.text = [mode2str[controlMode-1][2] copy];
        rightJoystick.vLabel.text = [mode2str[controlMode-1][3] copy];
    }
    else {
        leftJoystick.hLabel.text = [mode2strNoMotion[controlMode-1][0] copy];
        leftJoystick.vLabel.text = [mode2strNoMotion[controlMode-1][1] copy];
        rightJoystick.hLabel.text = [mode2strNoMotion[controlMode-1][2] copy];
        rightJoystick.vLabel.text = [mode2strNoMotion[controlMode-1][3] copy];
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

@end
