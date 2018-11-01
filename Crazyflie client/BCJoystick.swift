//
//  BCJoystick.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 27.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import UIKit

enum ThrustControl {
    case none
    case y
}

protocol BCJoystickViewModelProtocol: class {
    func touchesBegan()
    func touchesEnded()
    func touches(movedTo xValue: Double, yValue: Double)
    
    var activated: Bool { get }
    var thrustControl: ThrustControl { get }
    var vLabelLeft: Bool { get }
    var x: Float { get }
    var y: Float { get }
    var hProgress: Float { get }
    var vProgress: Float { get }
}

final class BCJoystick: UIControl {
    private static let JSIZE: CGFloat = 80.0
    
    var viewModel: BCJoystickViewModelProtocol?
    
    private var _center: CGPoint?
    private var path: UIBezierPath?
    
    private(set) var vLabel: UILabel!
    private(set) var hLabel: UILabel!
    private(set) var vProgress: UIProgressView!
    private(set) var hProgress: UIProgressView!
    fileprivate var shapeLayer: CAShapeLayer!
    
    init(frame: CGRect, viewModel: BCJoystickViewModelProtocol) {
        super.init(frame: frame)
        
        self.viewModel = viewModel
        
        shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = UIColor(red: 0, green: 122.0/255.0, blue: 1.0, alpha: 0.25).cgColor
        layer.addSublayer(shapeLayer)
        
        vProgress = UIProgressView(progressViewStyle: .default)
        vProgress.center = CGPoint(x:0, y:0)
        vProgress.transform = CGAffineTransform(rotationAngle: CGFloat(Double(.pi * -0.5)))
        vProgress.isHidden = true
        
        vLabel = UILabel(frame: frame)
        vLabel.text = "Pitch"
        vLabel.textColor = UIColor(red: 0, green: 122.0/255.0, blue: 1.0, alpha: 0.75)
        vLabel.textAlignment = .center;
        vLabel.center = CGPoint(x:0, y:0);
        vLabel.transform = CGAffineTransform(rotationAngle: CGFloat(Double(.pi * -0.5)))
        vLabel.isHidden = true
        
        hProgress = UIProgressView(progressViewStyle: .default)
        hProgress.center = CGPoint(x:0, y:0)
        hProgress.isHidden = true
        
        hLabel = UILabel(frame: frame)
        hLabel.text = "Pitch"
        hLabel.textColor = UIColor(red: 0, green: 122.0/255.0, blue: 1.0, alpha: 0.75)
        hLabel.textAlignment = .center;
        hLabel.center = CGPoint(x:0, y:0);
        hLabel.isHidden = true
        
        addSubview(vProgress)
        addSubview(vLabel)
        addSubview(hProgress)
        addSubview(hLabel)
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    //MARK: - Private Methods
    
    fileprivate func updateUI() {
        guard let viewModel = viewModel else {
            return
        }
        
        vProgress.isHidden = !viewModel.activated
        hProgress.isHidden = !viewModel.activated
        vLabel.isHidden = !viewModel.activated
        hLabel.isHidden = !viewModel.activated
        
        if !viewModel.activated {
            let _ = shapeLayer.presentation()?.value(forKey: "path")
            let rect = CGRect(origin: center, size: CGSize.zero)
            let endPath = UIBezierPath(rect: rect)
            
            let pathAnimation = CABasicAnimation(keyPath: "path")
            pathAnimation.fromValue = UIBezierPath(cgPath: shapeLayer.path!) //TODO: fix forced unwrapping!!!
            pathAnimation.toValue = endPath.cgPath
            pathAnimation.duration = 0.1
            pathAnimation.delegate = self
            shapeLayer.add(pathAnimation, forKey: "animationKey")
            
            path = UIBezierPath(rect: rect)
            shapeLayer.path = nil
            sendActions(for: .valueChanged)
        } else {
            hProgress.progress = viewModel.hProgress
            vProgress.progress =  viewModel.vProgress
            sendActions(for: .valueChanged)
        }
        
        sendActions(for: .allTouchEvents)
    }
    
    //MARK: - Touches Methods
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let JSIZE = BCJoystick.JSIZE
        guard let viewModel = viewModel, let touch = event?.touches(for: self)?.first else {
            return
        }
        
        viewModel.touchesBegan()
        
        var center = touch.location(in: self)
        if viewModel.thrustControl == .y {
            center.y -= BCJoystick.JSIZE
        }
        
        _center = center
        var rect = CGRect(origin: center, size: CGSize.zero)
        let startPath = UIBezierPath(rect: rect)
        
        rect.origin.x -= JSIZE
        rect.origin.y -= JSIZE
        rect.size.height = 2 * JSIZE
        rect.size.width = 2 * JSIZE
        
        let endPath = UIBezierPath(rect: rect)
        let pathAnimation = CABasicAnimation(keyPath: "path")
        pathAnimation.fromValue = startPath.cgPath
        pathAnimation.toValue = endPath.cgPath
        pathAnimation.duration = 0.1
        pathAnimation.delegate = self
        shapeLayer.add(pathAnimation, forKey: "animationKey")
        
        if viewModel.vLabelLeft {
            vProgress.center = CGPoint(x: center.x-JSIZE-3, y: center.y)
            vLabel.center = CGPoint(x: center.x-JSIZE-12, y: center.y)
            vLabel.transform = CGAffineTransform(rotationAngle: CGFloat(Double(.pi * -0.5)))
        } else {
            vProgress.center = CGPoint(x: center.x+JSIZE+3, y: center.y)
            vLabel.center = CGPoint(x: center.x+JSIZE+12, y: center.y)
            vLabel.transform = CGAffineTransform(rotationAngle: CGFloat(Double(.pi * +0.5)))
        }
        vProgress.progress = viewModel.thrustControl == .y ? 0 : 0.5
        
        hProgress.frame = CGRect(x: center.x - JSIZE, y: center.y - JSIZE - 4, width: 2 * JSIZE, height: 2 * JSIZE)
        hProgress.progress = 0.5;
        hLabel.center = CGPoint(x: center.x, y: center.y - JSIZE - 12);
        let path = UIBezierPath(rect: rect)
        self.path = path
        shapeLayer.path = path.cgPath
        
        sendActions(for: .allTouchEvents)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        let JSIZE = BCJoystick.JSIZE
        guard let touch = event?.touches(for: self)?.first,
            let center = _center else {
            return
        }
        
        let point = touch.location(in: self)
        let x = CGFloat(point.x - center.x) / JSIZE
        let y = -1 * (point.y - center.y) / JSIZE
        
        viewModel?.touches(movedTo: Double(x), yValue: Double(y))
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        viewModel?.touchesEnded()
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        viewModel?.touchesEnded()
    }
}

extension BCJoystick: BCJoystickViewModelDelegate {
    func didUpdate() {
        updateUI()
    }
}

extension BCJoystick: CAAnimationDelegate {
    func animationDidStop(_ anim: CAAnimation, finished flag: Bool) {
        guard shapeLayer.path != nil else {
            return
        }
        
        vProgress.isHidden = false
        hProgress.isHidden = false
        vLabel.isHidden = false
        hLabel.isHidden = false
    }
}
