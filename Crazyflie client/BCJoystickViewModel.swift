//
//  BCJoystickViewModel.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 29.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

protocol BCJoystickViewModelDelegate: class {
    func didUpdate()
}

public protocol BCJoystickViewModelObserver: Observer {
}

final class BCJoystickViewModel: BCJoystickViewModelProtocol, Observable, CrazyFlieXProvideable, CrazyFlieYProvideable  {
    typealias ConcreteObserver = BCJoystickViewModelObserver
    
    var weakObservers: [WeakBox] = [WeakBox]()
    weak var delegate: BCJoystickViewModelDelegate?
    
    private(set) var x: Float = 0
    private(set) var y: Float = 0
    private(set) var activated: Bool = false
    private(set) var deadbandX: Double
    private(set) var deadbandY: Double = 0
    private(set) var vLabelLeft: Bool
    var thrustControl: Bool
    
    //MARK: - Init
    
    init(deadbandX: Double = 0, vLabelLeft: Bool = false, thrustControl: Bool = false) {
        self.deadbandX = deadbandX
        self.vLabelLeft = vLabelLeft
        self.thrustControl = thrustControl
    }

    //MARK: - ViewModel
    
    func touchesBegan() {
        activated = true
        notifyDidUpdate()
    }
    
    func touchesEnded() {
        cancel()
    }
    
    func touches(movedTo xValue: Double, yValue: Double) {
        var xUpdate = xValue
        if xUpdate > 1 { xUpdate = 1 }
        if xUpdate < -1 { xUpdate = -1 }
        x = Float(apply(deadband: deadbandX, to: xUpdate))
        
        var yUpdate = yValue
        if yUpdate > 1 { yUpdate = 1 }
        if yUpdate < -1 { yUpdate = -1 }
        yUpdate = apply(deadband: deadbandY, to: yUpdate)
        y = Float(thrustControl == false ? yUpdate : (yUpdate + 1) / 2)
        
        /*x = ((CGFloat)(point.x-center.x))/JSIZE;
        if (x>1) x=1;
        if (x<-1) x=-1;
        x = [self applyDeadband:self.deadbandX toValue:x];
        
        y = -1*(point.y-center.y)/JSIZE;*/
        
        notifyDidUpdate()
    }
    
    //MARK: - Private Methods
    
    //MARK: - Public Methods
    
    private func cancel() {
        guard activated else {
            return
        }
        
        x = 0
        y = 0
        
        activated = false
        
        notifyDidUpdate()
    }
    
    private func apply(deadband: Double, to value: Double) -> Double {
        let a = 1.0/(1.0 - deadband)
        let b = -1 * a * deadband
        
        if value < (-1 * deadband) {
            return (a * value) - b
        } else if ((value >= (-1 * deadband)) && (value <= deadband)) {
            return 0
        } else if value > deadband {
            return (a * value) + b
        }
        return 0
    }
    
    private func notifyDidUpdate() {
        delegate?.didUpdate()
    }
}
