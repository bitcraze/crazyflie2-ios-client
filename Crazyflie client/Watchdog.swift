//
//  Watchdog.swift
//  Crazyflie client
//
//  Created by Arnaud Taffanel on 31/07/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation
import UIKit

/**
    Simple watchdog class based on NSTimer

    After starting it, reset should be called periodically befor the
    period (in seconds) is expired. Otherwise the onTimeout function
    will be called.
*/
class Watchdog : NSObject
{
    private var started = false
    private var timer: NSTimer! = nil
    var onTimeout: (()->())?
    var period: Double
    
    init(period: Double, onTimeout: ()->()) {
        self.period = period
        self.onTimeout = onTimeout
    }
    
    /// Start the watchdog
    func start() {
        if self.started {
            return
        }
        
        self.timer = NSTimer.scheduledTimerWithTimeInterval(self.period, target:self, selector: "timeout:", userInfo: nil, repeats: false)
        self.started = true
    }
    
    func timeout(_:NSTimer) {
        self.onTimeout?()
        self.stop()
    }
    
    /// Stop the watchdog
    func stop() {
        if !self.started {
            return
        }
        
        self.timer.invalidate()
        self.timer = nil
        self.started = false
    }
    
    /**
        Reset the timer to the preset period. Optionally reset it to an higher period
        (for example just before running an operation which is known to take longer
        time)
    
        :param: period Nil to use the default period (configured when creating the 
                watchdog and contained in the period property). Otherwise should be
                the period in seconds
    */
    func reset(var period: Double! = nil) {
        if !self.started {
            return
        }
        
        if period == nil {
            period = self.period
        }
        
        self.timer.invalidate()
        self.timer = NSTimer.scheduledTimerWithTimeInterval(period, target:self, selector: "timeout:", userInfo: nil, repeats: false)
        
    }
    
}