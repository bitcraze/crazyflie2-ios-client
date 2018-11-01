//
//  Observer.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 29.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import Foundation

public struct WeakBox {
    private(set) weak var object: Observer?
    init(object: Observer) {
        self.object = object
    }
}

public protocol Observer: class  {
}

public protocol Observable: class {
    associatedtype ConcreteObserver
    var weakObservers: [WeakBox] { get set }
}
extension Observable {
    private func cleanup() {
        guard weakObservers.count > 0 else { return }
        
        var array = [Int]()
        var i = 0
        for observer in weakObservers {
            if observer.object == nil {
                array.append(i)
            }
            i += 1
        }
        
        for index in array {
            weakObservers.remove(at: index)
        }
    }
    
    public func add(observer: Observer) {
        cleanup()
        
        if weakObservers.contains(where: { $0.object === observer }) {
            return
        }
        
        weakObservers.append(WeakBox(object: observer))
    }
    
    public func remove(observer: Observer) {
        cleanup()
        
        guard let index = weakObservers.index(where: { $0.object === observer }) else {
            return
        }
        weakObservers.remove(at: index)
    }
    
    public var observers: [ConcreteObserver] {
        return weakObservers.compactMap { $0.object as? ConcreteObserver }
    }
}
