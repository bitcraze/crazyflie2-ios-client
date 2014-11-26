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
 * BCJoystick.h: Joystick component
 */

#import <UIKit/UIKit.h>

@interface BCJoystick : UIControl
@property (nonatomic,assign) float x;
@property (nonatomic,assign) float y;

@property (nonatomic,assign) BOOL vLabelLeft;

@property float deadbandX;
@property float deadbandY;

@property BOOL positiveY;

@property (strong) UILabel *vLabel;
@property (strong) UILabel *hLabel;

@property BOOL activated;

- (void) cancel;
@end
