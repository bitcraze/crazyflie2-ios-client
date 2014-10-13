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

@interface ViewController () {
    BCJoystick *leftJoystick;
    BCJoystick *rightJoystick;
    bool canBluetooth;
    bool isScanning;
    bool sent;
    
    enum {stateIdle, stateScanning, stateConnecting, stateConnected} state;
    
    CBPeripheral *crazyflie;
    
    CBCentralManager *centralManager;
}

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
    
    //Init joysticks
    leftJoystick = [[BCJoystick alloc] initWithFrame:[_leftView frame]];
    [_leftView addSubview:leftJoystick];
    
    rightJoystick = [[BCJoystick alloc] initWithFrame:[_leftView frame]];
    [_rightView addSubview:rightJoystick];
    rightJoystick.deadbandX = 0.1;  //Some deadband for the yaw
    rightJoystick.vLabelLeft = YES;
    
    centralManager = [[CBCentralManager alloc] initWithDelegate:self queue:nil];
}

- (void) joystickMoved: (BCJoystick*)joystick
{
    NSLog(@"Joystick moved to %f,%f.", joystick.x, joystick.y);
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
    [_connectProgress setProgress:0.84 animated:YES];
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
    
    if (sent) {
        NSLog(@"Send commander!");
        NSData *data;
        
        commanderPacket.header = 0x30;
        
        commanderPacket.pitch = pow(leftJoystick.y, 2) * -50 * ((leftJoystick.y>0)?1:-1);
        commanderPacket.roll = pow(leftJoystick.x, 2) * 50 * ((leftJoystick.x>0)?1:-1);
        
        commanderPacket.yaw = rightJoystick.x * 200;
        
        int thrust = sqrt(rightJoystick.y)*65535*0.8;
        //int thrust = rightJoystick.y*65535*0.8;
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

- (void)peripheral:(CBPeripheral *)peripheral

didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic
             error:(NSError *)error {
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

@end
