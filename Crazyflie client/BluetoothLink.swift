//
//  BluetoothLink.swift
//  Bluetooth connection to Crazyflie
//    Sends and receives CRTP packet to/from Crazyflie firmware and bootloader
//
//  Created by Arnaud Taffanel on 22/04/15.
//  Copyright (c) 2015 Bitcraze. All rights reserved.
//

import Foundation
import CoreBluetooth

class BluetoothLink : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let crazyflieServiceUuid = "00000201-1C7F-4F9E-947B-43B7C00A9A08";
    let crtpCharacteristicUuid = "00000202-1C7F-4F9E-947B-43B7C00A9A08"
    
    var canBluetooth = false
    
    var stateCallback: (NSString -> ())?
    var txCallback: ((Bool) -> ())?
    
    private var centralManager: CBCentralManager?
    private var peripheralBLE: CBPeripheral?
    private var connectingPeripheral: CBPeripheral?
    private var crazyflie: CBPeripheral?
    private var crtpCharacteristic: CBCharacteristic?
    
    private var state = "idle" {
        didSet {
            stateCallback?(state)
        }
    }
    private var error = ""
    
    private var scanTimer: NSTimer?
    
    private var connectCallback: (Bool -> ())?
    
    override init() {
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        
        state = "idle"
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        canBluetooth = central.state == CBCentralManagerState.PoweredOn;
        println("Bluetooth is now " + (canBluetooth ? "on" : "off"))
    }
    
    func connect(address: String?, callback: Bool -> ()) {
        if !canBluetooth || state != "idle" {
            error = canBluetooth ? "Bluetooth disabled":"Already connected"
            callback(false);
            return;
        }
        
        if let central = centralManager {
            var connectedPeripheral = central.retrieveConnectedPeripheralsWithServices([CBUUID(string: crazyflieServiceUuid)]) as! [CBPeripheral];
            
            if count(connectedPeripheral) > 0 {
                NSLog("Already connected, reusing peripheral");
                connectingPeripheral = connectedPeripheral.first;
                central.connectPeripheral(connectingPeripheral, options: nil);
                state = "connecting";
            } else {
                NSLog("Start scanning")
                central.scanForPeripheralsWithServices(nil, options: nil);
                state = "scanning"
                
                scanTimer = NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: "scanningTimeout:", userInfo: nil, repeats: false)
            }
            
            connectCallback = callback
        }
    }
    
    func scanningTimeout(timer: NSTimer) {
        NSLog("Scan timeout, stop scan");
        centralManager!.stopScan()
        state = "idle"
        scanTimer?.invalidate()
        scanTimer = nil
        
        error = "Timeout"
        connectCallback?(false)
    }
    
    func centralManager(central: CBCentralManager!, didDiscoverPeripheral peripheral: CBPeripheral!, advertisementData: [NSObject : AnyObject]!, RSSI: NSNumber!) {
        if let name = peripheral.name  {
            if name == "Crazyflie" {
                scanTimer?.invalidate()
                central.stopScan()
                NSLog("Stop scanning")
                connectingPeripheral = peripheral
                state = "connecting"
                
                central.connectPeripheral(peripheral, options: nil)
            }
        }
    }
    
    func centralManager(central: CBCentralManager!, didFailToConnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        self.error = "Failed to connect"
        state = "idle"
        connectCallback?(false)
    }
    
    func centralManager(central: CBCentralManager!, didConnectPeripheral peripheral: CBPeripheral!) {
        crazyflie = peripheral
        
        NSLog("Crazyflie connected, refreshing services ...")
        
        peripheral.delegate = self
        
        peripheral.discoverServices([CBUUID(string: crazyflieServiceUuid)])
        
        state = "services";
    }
    
    func centralManager(central: CBCentralManager!, didDisconnectPeripheral peripheral: CBPeripheral!, error: NSError!) {
        disconnect()
        
        self.error = error.localizedDescription
        
        connectCallback?(false)
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverServices error: NSError!) {
        for service in peripheral.services as! [CBService] {
            if service.UUID.UUIDString == crazyflieServiceUuid {
                peripheral.discoverCharacteristics([CBUUID(string: crtpCharacteristicUuid)], forService: service);
                state = "characteristics"
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        for characteristic in service.characteristics as! [CBCharacteristic] {
            if (characteristic.UUID.UUIDString == crtpCharacteristicUuid) {
                crtpCharacteristic = characteristic
                
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
                
                state = "connected"
                connectCallback?(true)
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didUpdateNotificationStateForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if error != nil {
            NSLog("Error setting notification state: " + error.localizedDescription)
        } else {
            NSLog("Changed notification state for " + characteristic.UUID.UUIDString)
        }
    }
    
    func disconnect() {
        switch state {
        case "scanning":
            NSLog("Cancel scanning");
            centralManager!.stopScan()
            scanTimer?.invalidate()
        case "connecting", "services", "characteristics", "connected":
            centralManager!.cancelPeripheralConnection(connectingPeripheral)
        default:
            break;
        }
        
        connectingPeripheral = nil
        crazyflie = nil
        crtpCharacteristic = nil
        
        state = "idle"
        println("Connection IDLE")
    }
    
    func getState() -> NSString {
        return state as NSString
    }
    
    func getError() -> NSString {
        return error as NSString
    }
    
    func onStateUpdated(callback: NSString -> ()) {
        stateCallback = callback
    }
    
    func sendPacket(packet: NSData, callback: ((Bool) -> ())?) {
        if state != "connected" {
            callback?(false)
            return
        }
        
        txCallback = callback
        crazyflie!.writeValue(packet, forCharacteristic: crtpCharacteristic, type: CBCharacteristicWriteType.WithResponse)
    }
    
    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        txCallback?(true)
    }
}