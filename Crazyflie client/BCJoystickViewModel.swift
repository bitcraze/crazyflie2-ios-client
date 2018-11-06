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
    func didUpdateState()
}

final class BCJoystickViewModel: BCJoystickViewModelProtocol, Observable, CrazyFlieXProvideable, CrazyFlieYProvideable  {
    typealias ConcreteObserver = BCJoystickViewModelObserver
    
    var weakObservers: [WeakBox] = [WeakBox]()
    weak var delegate: BCJoystickViewModelDelegate?
    
    private(set) var x: Float = 0
    private(set) var y: Float = 0
    private(set) var activated: Bool = false
    private(set) var touchesChanged: Bool = false
    private(set) var deadbandX: Double
    private(set) var deadbandY: Double = 0
    private(set) var vLabelLeft: Bool
    var thrustControl: ThrustControl
    
    //MARK: - Init
    
    init(deadbandX: Double = 0, vLabelLeft: Bool = false, thrustControl: ThrustControl = .none) {
        self.deadbandX = deadbandX
        self.vLabelLeft = vLabelLeft
        self.thrustControl = thrustControl
    }

    //MARK: - ViewModel
    
    func touchesBegan() {
        activated = true
        touchesChanged = true
        notifyDidUpdate()
        touchesChanged = false
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
        y = Float(thrustControl == .y ? (yUpdate + 1) / 2 : yUpdate)
        
        notifyDidUpdate()
    }
    
    var hProgress: Float {
        return (x + 1) / 2
    }
    
    var vProgress: Float {
        return thrustControl == .y ? y : (y + 1) / 2
    }
    
    //MARK: - Private Methods

    private func cancel() {
        guard activated else {
            return
        }
        
        x = 0
        y = 0
        
        touchesChanged = true
        activated = false
        
        notifyDidUpdate()
        touchesChanged = false
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
        observers.forEach { $0.didUpdateState() }
    }
}
