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
    private(set) var positiveY: Bool = false
    
    //MARK: - Init
    
    init(deadbandX: Double = 0, vLabelLeft: Bool = false) {
        self.deadbandX = deadbandX
        self.vLabelLeft = vLabelLeft
    }

    //MARK: - ViewModel
    
    func touchesBegan() {
        activated = true
    }
    
    func touchesEnded() {
        cancel()
    }
    
    func touches(movedTo x: Double, y: Double) {
        var x = x
        if x > 1 { x = 1 }
        if x < -1 { x = -1 }
        x = apply(deadband: deadbandX, to: x)
    
        var y = y
        if y > 1 { y = 1 }
        if y < -1 { y = -1 }
        y = apply(deadband: deadbandY, to: y)
        y = !positiveY ? y : (y + 1) / 2
        
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
