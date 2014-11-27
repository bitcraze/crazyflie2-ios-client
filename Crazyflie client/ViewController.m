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

#define CRAZYFLIE_SERVICE @"00000201-1C7F-4F9E-947B-43B7C00A9A08"
#define CRTP_CHARACTERISTIC @"00000202-1C7F-4F9E-947B-43B7C00A9A08"


#define LINEAR_PR YES
#define LINEAR_THRUST YES

@interface ViewController () {
    BCJoystick *leftJoystick;
    BCJoystick *rightJoystick;
    bool canBluetooth;
    bool isScanning;
    bool sent;
    
    bool locked;
    
    float pitchRate;
    float yawRate;
    float maxThrust;
    int controlMode;
    
    enum {stateIdle, stateScanning, stateConnecting, stateConnected} state;
    
    CBPeripheral *crazyflie;
    
    CBCentralManager *centralManager;
    
    SettingsViewController *settingsViewController;
    
    NSMutableDictionary *sensitivities;
    NSString *sensitivitySetting;
}

@property (weak, nonatomic) IBOutlet UILabel *unlockLabel;
@property (weak, nonatomic) IBOutlet UIButton *connectButton;
@property (weak, nonatomic) IBOutlet UIProgressView *connectProgress;

@property (weak, nonatomic) IBOutlet UIView *leftView;
@property (weak, nonatomic) IBOutlet UIView *rightView;

@property (strong) CBPeripheral *connectingPeritheral;
@property (strong) CBCharacteristic *crtpCharacteristic;

@property (strong) NSTimer *commanderTimer;
@property (strong) NSTimer *scanTimer;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Init instance variables
    self.connectProgress.progress = 0;
    
    canBluetooth = NO;
    isScanning = NO;
    sent = NO;
    state = stateIdle;
    locked = YES;
    
    //Init joysticks
    leftJoystick = [[BCJoystick alloc] initWithFrame:[_leftView frame]];
    [_leftView addSubview:leftJoystick];
    [leftJoystick addTarget:self action:@selector(joystickTouch:) forControlEvents:UIControlEventAllTouchEvents];
    
    rightJoystick = [[BCJoystick alloc] initWithFrame:[_leftView frame]];
    [_rightView addSubview:rightJoystick];
    [rightJoystick addTarget:self action:@selector(joystickTouch:) forControlEvents:UIControlEventAllTouchEvents];
    rightJoystick.deadbandX = 0.1;  //Some deadband for the yaw
    rightJoystick.vLabelLeft = YES;
    
    [self loadDefault];
    
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
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
    static const NSString *mode2str[4][4] = {{@"Yaw",  @"Pitch",  @"Roll", @"Thrust"},
                                             {@"Yaw",  @"Thrust", @"Roll", @"Pitch"},
                                             {@"Roll", @"Pitch",  @"Yaw",  @"Thrust"},
                                             {@"Roll", @"Thrust", @"Yaw",  @"Pitch"}};
    
    controlMode = [defaults doubleForKey:@"controlMode"];
    NSLog(@"controlMode %d", controlMode);
    sensitivities = (NSMutableDictionary*)[defaults dictionaryForKey:@"sensitivities"];
    sensitivitySetting = [defaults stringForKey:@"sensitivitySettings"];
    
    NSDictionary *sensitivity = (NSDictionary*)[sensitivities valueForKey:sensitivitySetting];
    pitchRate = [(NSNumber*)[sensitivity valueForKey:@"pitchRate"] floatValue];
    yawRate = [(NSNumber*)[sensitivity valueForKey:@"yawRate"] floatValue];
    maxThrust = [(NSNumber*)[sensitivity valueForKey:@"maxThrust"] floatValue];
    
    leftJoystick.hLabel.text = [mode2str[controlMode-1][0] copy];
    leftJoystick.vLabel.text = [mode2str[controlMode-1][1] copy];
    rightJoystick.hLabel.text = [mode2str[controlMode-1][2] copy];
    rightJoystick.vLabel.text = [mode2str[controlMode-1][3] copy];
    
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
    if (canBluetooth) {
        if (state == stateIdle) {
            NSArray * connectedPeritheral = [centralManager retrieveConnectedPeripheralsWithServices:@[ [CBUUID UUIDWithString:CRAZYFLIE_SERVICE] ]];
            
            if (connectedPeritheral.count > 0) {
                NSLog(@"Found Crazyflie already connected!");
                _connectingPeritheral = [connectedPeritheral firstObject];
                [centralManager connectPeripheral:_connectingPeritheral options:nil];
                [_connectProgress setProgress:0.25 animated:YES];
                state = stateConnecting;
            } else {
                NSLog(@"Start scanning");
                [centralManager scanForPeripheralsWithServices:nil options:nil];
                self.scanTimer = [NSTimer scheduledTimerWithTimeInterval:10 target:self selector:@selector(scanningTimeout:) userInfo:nil repeats:NO];
                state = stateScanning;
            }
            
            [(UIButton *)sender setTitle:@"Cancel" forState:UIControlStateNormal];
            
        } else if (state == stateScanning) {
            NSLog(@"Scanning canceled");
            [centralManager stopScan];
            [self.scanTimer invalidate];
            self.scanTimer = nil;
            [(UIButton *)sender setTitle:@"Connect" forState:UIControlStateNormal];
            state = stateIdle;
        } else if (state == stateConnecting) {
            NSLog(@"Connection canceled");
            [centralManager cancelPeripheralConnection:_connectingPeritheral];
            [(UIButton *)sender setTitle:@"Connect" forState:UIControlStateNormal];
            state = stateIdle;
        } else if (state == stateConnected) {
            NSLog(@"Disconnecting");
            [_commanderTimer invalidate];
            [centralManager cancelPeripheralConnection:_connectingPeritheral];
        }
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Bluetooth disabled"
                                                        message:@"Please enable Bluetooth to connect a Crazyflie"
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (IBAction)settingsClick:(id)sender {
    [self performSegueWithIdentifier:@"settings" sender:nil];
}

- (void) scanningTimeout:(NSTimer*)timer
{
    NSLog(@"Scan timeout, stop scan");
    [centralManager stopScan];
    [self.scanTimer invalidate];
    self.scanTimer = nil;
    [[[UIAlertView alloc] initWithTitle:@"Connection timeout"
                               message:@"Could not find Crazyflie"
                              delegate:nil
                     cancelButtonTitle:@"OK"
                     otherButtonTitles:nil] show];
    state = stateIdle;
    [self.connectButton setTitle:@"Connect" forState:UIControlStateNormal];
}

- (void) centralManagerDidUpdateState:(CBCentralManager *)central
{
    if (central.state == CBCentralManagerStatePoweredOn) {
        NSLog(@"Bluetooth is available!");
        canBluetooth = YES;
    } else {
        NSLog(@"Bluetooth not available");
        canBluetooth = NO;
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI
{
    NSLog(@"Discodered peripheral: %@", peripheral.name);
    if ([peripheral.name  isEqual: @"Crazyflie"]) {
        [self.scanTimer invalidate];
        self.scanTimer = nil;
        [centralManager stopScan];
        NSLog(@"Stop scanning");
        self.connectingPeritheral = peripheral;
        state = stateConnecting;
        [centralManager connectPeripheral:peripheral options:nil];
        
        [self.connectProgress setProgress:0.25 animated:YES];
    }
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral
{
    NSLog(@"Preipheral connected");
    crazyflie = peripheral;
    peripheral.delegate = self;
    
    [peripheral discoverServices:@[ [CBUUID UUIDWithString:CRAZYFLIE_SERVICE] ]];
    
    [self.connectProgress setProgress:0.5 animated:YES];
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    state = stateIdle;
    [(UIButton *)_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Connection failed"
                                                    message:@"Connection to Crazyflie failed"
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error
{
    for (CBService *service in peripheral.services) {
        NSLog(@"Discovered serivce %@", [service.UUID UUIDString]);
        if ([service.UUID isEqual:[CBUUID UUIDWithString:CRAZYFLIE_SERVICE]]) {
            [peripheral discoverCharacteristics:@[ [CBUUID UUIDWithString:CRTP_CHARACTERISTIC] ] forService:service];
        }
    }
    
    [self.connectProgress setProgress:0.75 animated:YES];
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error
{
    for (CBCharacteristic *characteristic in service.characteristics) {
        NSLog(@"Discovered characteristic %@", [characteristic.UUID UUIDString]);
        if ([characteristic.UUID isEqual:[CBUUID UUIDWithString:CRTP_CHARACTERISTIC]]) {
            self.crtpCharacteristic = characteristic;
            sent = YES;
            self.commanderTimer = [NSTimer scheduledTimerWithTimeInterval:0.05 target:self selector:@selector(sendCommander:) userInfo:nil repeats:YES];
            [peripheral setNotifyValue:YES forCharacteristic:self.crtpCharacteristic];
        }
        
    }
    [self.connectProgress setProgress:1.0 animated:YES];
    state = stateConnected;
    [_connectButton setTitle:@"Disconnect" forState:UIControlStateNormal];
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
    static const int mode2axis[4][4] = {{1, 2, 0, 3},
                                        {3, 2, 0, 1},
                                        {1, 0, 2, 3},
                                        {3, 0, 2, 1}};
    float joysticks[4];
    float jsPitch, jsRoll, jsYaw, jsThrust;
    
    if (locked == NO) {
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
            commanderPacket.pitch = jsPitch*-1*pitchRate;
            commanderPacket.roll = jsRoll*pitchRate;
        } else {
            commanderPacket.pitch = pow(jsPitch, 2) * -1 * pitchRate * ((jsPitch>0)?1:-1);
            commanderPacket.roll = pow(jsRoll, 2) * pitchRate * ((jsRoll>0)?1:-1);
        }
        
        commanderPacket.yaw = jsYaw * yawRate;
        
        int thrust;
        if (LINEAR_THRUST) {
            thrust = jsThrust*65535*(maxThrust/100);
        } else {
            thrust = sqrt(jsThrust)*65535*(maxThrust/100);
        }
        if (thrust>65535) thrust = 65535;
        if (thrust < 0) thrust = 0;
        commanderPacket.thrust = thrust;
        
        data = [NSData dataWithBytes:&commanderPacket length:sizeof(commanderPacket)];
        
        [_connectingPeritheral writeValue:data forCharacteristic:_crtpCharacteristic type:CBCharacteristicWriteWithResponse];
        sent = NO;
    } else {
        NSLog(@"Missed commander update!");
    }
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error
{
    if (error) {
        NSLog(@"Error writing characteristic value: %@",
              [error localizedDescription]);
        return;
    }
    NSLog(@"Value written");
    sent  = YES;
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    if (error) {
        NSLog(@"Error changing notification state: %@",
              [error localizedDescription]);
    }
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error
{
    if (error) {
        NSLog(@"Error disconnected from peripheral: %@",
              [error localizedDescription]);
        [[[UIAlertView alloc] initWithTitle:@"Error disconnected"
                                   message:[error localizedDescription]
                                  delegate:nil
                         cancelButtonTitle:@"OK"
                         otherButtonTitles:nil] show];
    }
    NSLog(@"Disconnected!");
    [_connectProgress setProgress:0 animated:NO];
    [_commanderTimer invalidate];
    _commanderTimer = nil;
    _crtpCharacteristic = nil;
    _connectingPeritheral = nil;
    [_connectButton setTitle:@"Connect" forState:UIControlStateNormal];
    state = stateIdle;
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
        controlMode = settingsViewController.controlMode;
        sensitivities = [settingsViewController.sensitivities mutableCopy];
        [self saveDefault];
    }
    [self dismissViewControllerAnimated:true completion:nil];
}

@end
