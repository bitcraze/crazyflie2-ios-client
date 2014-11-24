//
//  SettingsViewController.m
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 11/1/14.
//  Copyright (c) 2014 Bitcraze. All rights reserved.
//

#import "SettingsViewController.h"

@interface SettingsViewController ()

@end

@implementation SettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if ([self.sensitivitySetting isEqualToString:@"slow"])
        self.sensitivitySelector.selectedSegmentIndex = 0;
    else if ([self.sensitivitySetting isEqualToString:@"fast"])
        self.sensitivitySelector.selectedSegmentIndex = 1;
    else if ([self.sensitivitySetting isEqualToString:@"custom"])
        self.sensitivitySelector.selectedSegmentIndex = 2;
    
    [self sensitivityChanged:self.sensitivitySelector];
    
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
        //[[NSDictionary alloc] init];
        //[customSensitivity setValue:[NSNumber numberWithFloat:pitchRate] forKey:@"pitchRate"];
        
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

@end
