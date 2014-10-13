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

#import "BCJoystick.h"

#define JSIZE 80.0

@interface BCJoystick () {
    CGPoint center;
}

- (CGFloat) applyDeadband:(CGFloat)deadband toValue:(CGFloat)value;

@property (strong) UIBezierPath *path;
@property (strong) CAShapeLayer *shapeLayer;

@property (strong) UIProgressView *vProgress;
@property (strong) UIProgressView *hProgress;

@end

@implementation BCJoystick

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _x = 0;
        _y = 0;
        _deadbandX = 0;
        _deadbandY = 0;
        
        _shapeLayer = [[CAShapeLayer alloc] init];
        _shapeLayer.fillColor = [[UIColor colorWithRed:0 green:122.0/255.0 blue:1.0 alpha:0.25] CGColor];
        [self.layer addSublayer:_shapeLayer];
        
        _vProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _vProgress.center = CGPointMake(0, 0);
        _vProgress.transform = CGAffineTransformMakeRotation( M_PI * -0.5 );
        _vProgress.hidden = YES;
        
        _hProgress = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
        _hProgress.hidden = YES;
        
        _vLabelLeft = NO;
        
        [self addSubview:_vProgress];
        [self addSubview:_hProgress];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
    self = [super initWithCoder:aDecoder];
    if (self) {
        _x = 0;
        _y = 0;
        _deadbandX = 0;
        _deadbandY = 0;
    }
    return self;
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    UITouch *touch= [[event touchesForView:self] anyObject];
    center = [touch locationInView:self];
    
    
    UIBezierPath * startPath;
    UIBezierPath * endPath;
    
    CGRect rect;
    rect.origin = center;
    rect.size.height = 0; rect.size.width = 0;
    startPath = [UIBezierPath bezierPathWithRect:rect];
    
    rect.origin.x -= JSIZE; rect.origin.y -= JSIZE;
    rect.size.height = 2*JSIZE; rect.size.width = 2*JSIZE;
    endPath = [UIBezierPath bezierPathWithRect:rect];
    
    CABasicAnimation * pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    pathAnimation.fromValue = (__bridge id)[startPath CGPath];
    pathAnimation.toValue = (__bridge id)[endPath CGPath];
    pathAnimation.duration = 0.1f;
    pathAnimation.delegate = self;
    [_shapeLayer addAnimation:pathAnimation forKey:@"animationKey"];
    
    if (_vLabelLeft == YES) {
        _vProgress.center = CGPointMake(center.x-JSIZE-3, center.y);
    } else {
        _vProgress.center = CGPointMake(center.x+JSIZE+3, center.y);
    }
    _vProgress.progress = 0.5;
    
    [_hProgress setFrame:CGRectMake(center.x-JSIZE, center.y-JSIZE-4, 2*JSIZE, 2*JSIZE)];
    _hProgress.progress = 0.5;
    
    _path = [UIBezierPath bezierPathWithRect:rect];
    _shapeLayer.path = [_path CGPath];
    
}

- (CGFloat) applyDeadband:(CGFloat)deadband toValue:(CGFloat)value
{
    CGFloat result = 0;
    CGFloat a,b;
    
    a = 1.0f/(1.0f-deadband);
    b = -1*a*deadband;
    if (value<(-1*deadband))                         result = (a*value)-b;
    if ((value>=(-1*deadband)) && (value<=deadband)) result=0;
    if (value>deadband)                              result = (a*value)+b;
    
    return result;
}

- (void) touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
    CGFloat x,y;
    
    UITouch *touch= [[event touchesForView:self] anyObject];
    CGPoint point = [touch locationInView:self];
    
    x = ((CGFloat)(point.x-center.x))/JSIZE;
    if (x>1) x=1;
    if (x<-1) x=-1;
    self.x = [self applyDeadband:self.deadbandX toValue:x];
    
    y = -1*(point.y-center.y)/JSIZE;
    if (y>1) y=1;
    if (y<-1) y=-1;
    self.y = [self applyDeadband:self.deadbandY toValue:y];

    _hProgress.progress = (_x+1)/2.0;
    _vProgress.progress = (_y+1)/2.0;
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void) touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    _x = 0;
    _y = 0;
    
    UIBezierPath * startPath;
    UIBezierPath * endPath;
    
    startPath = [[_shapeLayer presentationLayer] valueForKeyPath:@"path"];
    
    CGRect rect;
    rect.origin = center;
    rect.size.height = 0; rect.size.width = 0;
    endPath = [UIBezierPath bezierPathWithRect:rect];
    
    CABasicAnimation * pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
    pathAnimation.fromValue = (__bridge id) [[UIBezierPath bezierPathWithCGPath:_shapeLayer.path] CGPath];
    pathAnimation.toValue = (__bridge id)[endPath CGPath];
    pathAnimation.duration = 0.1f;
    pathAnimation.delegate = self;
    [_shapeLayer addAnimation:pathAnimation forKey:@"animationKey"];
    
    _path = [UIBezierPath bezierPathWithRect:rect];
    _shapeLayer.path = nil;
    
    _vProgress.hidden = YES;
    _hProgress.hidden = YES;
    
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void) touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self touchesEnded:touches withEvent:event];
}

- (void) animationDidStop:(CAAnimation *)anim finished:(BOOL)flag
{
    if (_shapeLayer.path != nil) {
        _vProgress.hidden = NO;
        _hProgress.hidden = NO;
    }
}

@end
