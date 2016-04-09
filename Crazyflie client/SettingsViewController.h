//
//  SettingsViewController.h
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 11/1/14.
//  Copyright (c) 2014 Bitcraze. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Crazyflie_client-Swift.h>

static const NSString *mode2str[5][4] = {{@"Yaw",  @"Pitch",  @"Roll", @"Thrust"},
    {@"Yaw",  @"Thrust", @"Roll", @"Pitch"},
    {@"Roll", @"Pitch",  @"Yaw",  @"Thrust"},
    {@"Roll", @"Thrust", @"Yaw",  @"Pitch"},
    {@"Yaw", @"", @" ",  @"Thrust"}};

static const NSString *mode2strNoMotion[5][4] = {{@"Yaw",  @"Pitch",  @"Roll", @"Thrust"},
    {@"Yaw",  @"Thrust", @"Roll", @"Pitch"},
    {@"Roll", @"Pitch",  @"Yaw",  @"Thrust"},
    {@"Roll", @"Thrust", @"Yaw",  @"Pitch"}};

@protocol SettingsProtocolDelegate <NSObject>

@required
- (void) closeButtonPressed;
@end

@interface SettingsViewController : UIViewController

@property (nonatomic, strong) id delegate;

@property (weak, nonatomic) IBOutlet UITextField *pitchrollSensitivity;
@property (weak, nonatomic) IBOutlet UITextField *thrustSensitivity;
@property (weak, nonatomic) IBOutlet UITextField *yawSensitivity;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sensitivitySelector;
@property (weak, nonatomic) IBOutlet UISegmentedControl *controlModeSelector;

@property () NSInteger controlMode;
@property (strong, nonatomic) NSMutableDictionary *sensitivities;
@property (weak, nonatomic) NSString *sensitivitySetting;

@property (weak, nonatomic) BluetoothLink *bluetoothLink;

@end
