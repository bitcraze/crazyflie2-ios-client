//
//  ViewController.swift
//  Crazyflie client
//
//  Created by Martin Eberl on 23.01.17.
//  Copyright © 2017 Bitcraze. All rights reserved.
//

import UIKit

final class FlightControllerViewController: UIViewController {
    private var leftJoystick: BCJoystick?
    private var rightJoystick: BCJoystick?
    
    private var viewModel: FlightControllerViewModel?
    private var settingsViewController: SettingsViewController?
    
    @IBOutlet weak var unlockLabel: UILabel!
    @IBOutlet weak var connectButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var connectProgress: UIProgressView!
    @IBOutlet weak var leftView: UIView!
    @IBOutlet weak var rightView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        if viewModel == nil {
            viewModel = FlightControllerViewModel()
            viewModel?.delegate = self
        }
        
        setupUI()
        viewModel?.updateSettings()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        viewModel?.loadSettings()
        updateUI()
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    //MARK: - IBActions
    
    @IBAction func connectClicked(_ sender: Any) {
        viewModel?.connect()
    }
    
    @IBAction func settingsClicked(_ sender: Any) {
        performSegue(withIdentifier: "settings", sender: nil)
    }
    
    //MARK: - Private
    
    private func setupUI() {
        guard let viewModel = viewModel else { return }
        connectProgress.progress = 0
        
        connectButton.layer.borderColor = connectButton.tintColor.cgColor
        settingsButton.layer.borderColor = settingsButton.tintColor.cgColor
        
        //Init joysticks
        let frame = UIScreen.main.bounds
        
        let leftViewModel = viewModel.leftJoystickProvider
        let leftJoystick = BCJoystick(frame: frame, viewModel: leftViewModel)
        leftViewModel.delegate = leftJoystick
        leftViewModel.add(observer: viewModel)
        leftView.addSubview(leftJoystick)
        self.leftJoystick = leftJoystick
        
        let rightViewModel = viewModel.rightJoystickProvider
        let rightJoystick = BCJoystick(frame: frame, viewModel: rightViewModel)
        rightViewModel.delegate = rightJoystick
        rightViewModel.add(observer: viewModel)
        rightView.addSubview(rightJoystick)
        self.rightJoystick = rightJoystick
    }
    
    fileprivate func updateUI() {
        guard let viewModel = viewModel else {
            return
        }
        unlockLabel.isHidden = viewModel.bothThumbsOnJoystick
        
        leftJoystick?.hLabel.text = viewModel.leftXTitle
        leftJoystick?.vLabel.text = viewModel.leftYTitle
        rightJoystick?.hLabel.text = viewModel.rightXTitle
        rightJoystick?.vLabel.text = viewModel.rightYTitle
        
        connectProgress.setProgress(viewModel.progress, animated: true)
        connectButton.setTitle(viewModel.topButtonTitle, for: .normal)
    }
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "settings" {
            guard let viewController = segue.destination as? SettingsViewController else {
                return
            }
            
            viewController.viewModel = viewModel?.settingsViewModel
        }
    }

}

extension FlightControllerViewController: FlightControllerViewModelDelegate {
    func signalUpdate() {
        updateUI()
    }
    
    func signalFailed(with title: String, message: String?) {
        let alert = UIAlertController(title: title,
                                      message: message,
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok",
                                      style: .default,
                                      handler: {[weak alert] (action) in
            alert?.dismiss(animated: true, completion: nil)
        }))
        present(alert, animated: true, completion: nil)
    }
}
