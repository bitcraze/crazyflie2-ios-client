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
/**
    Bluetooth connection link to a Crazyflie 2.0

    This class implements all logic to send and receive packet to and from the
    Crazyflie 2.0. Documentation for the BTLE protocol can be found on the 
    Bitcraze Wiki: https://wiki.bitcraze.io/doc:crazyflie:ble:index
 */
class BluetoothLink : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    let crazyflieServiceUuid = "00000201-1C7F-4F9E-947B-43B7C00A9A08"
    let crtpCharacteristicUuid = "00000202-1C7F-4F9E-947B-43B7C00A9A08"
    let crtpUpCharacteristicUuid = "00000203-1C7F-4F9E-947B-43B7C00A9A08"
    let crtpDownCharacteristicUuid = "00000204-1C7F-4F9E-947B-43B7C00A9A08"
    
    // Structure that decode and encode crtpUp and crtpDown control byte (header)
    // See https://wiki.bitcraze.io/doc:crazyflie:ble:index#characteristics for format
    struct ControlByte {
        let start: Bool
        let pid: Int
        let length: Int
        
        let header: Int
        
        init(_ header: Int) {
            self.start = (header & 0x80) != 0
            self.pid = (header & 0b0110_0000) >> 5
            self.length = (header & 0b0001_1111)+1
            self.header = header
        }
        
        init(start: Bool, pid: Int, length: Int) {
            self.start = start
            self.pid = pid
            self.length = length
            
            self.header = (start ? 0x80:0x00) | ((pid&0x03)<<5) | ((length-1)&0x1f)
        }
    }
    
    var canBluetooth = false
    
    var stateCallback: (NSString -> ())?
    var txCallback: ((Bool) -> ())?
    var rxCallback: ((NSData) -> ())?
    
    private var centralManager: CBCentralManager?
    private var peripheralBLE: CBPeripheral?
    private var connectingPeripheral: CBPeripheral?
    private var crazyflie: CBPeripheral?
    private var crtpCharacteristic: CBCharacteristic! = nil
    private var crtpUpCharacteristic:CBCharacteristic! = nil
    private var crtpDownCharacteristic:CBCharacteristic! = nil
    
    private var btQueue: dispatch_queue_t
    private var pollTimer: NSTimer?
    
    
    private var state = "idle" {
        didSet {
            stateCallback?(state)
        }
    }
    private var error = ""
    
    private var scanTimer: NSTimer?
    
    private var connectCallback: (Bool -> ())?
    
    private var address = "Crazyflie"
    
    override init() {
        self.btQueue = dispatch_queue_create("se.bitcraze.crazyfliecontrol.bluetooth", DISPATCH_QUEUE_SERIAL)
        
        super.init()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        canBluetooth = centralManager!.state == CBCentralManagerState.PoweredOn
        
        state = "idle"
    }
    
    func centralManagerDidUpdateState(central: CBCentralManager!) {
        canBluetooth = central.state == CBCentralManagerState.PoweredOn;
        println("Bluetooth is now " + (canBluetooth ? "on" : "off"))
    }
    
    func connect(address: String?, callback: Bool -> ()) {
        if !canBluetooth || state != "idle" {
            error = canBluetooth ? "Already connected":"Bluetooth disabled"
            callback(false);
            return;
        }
        
        if address == nil {
            self.address = "Crazyflie"
        } else {
            self.address = address!
        }
        
        // Reseting characteristics
        self.crtpCharacteristic = nil
        self.crtpUpCharacteristic = nil
        self.crtpDownCharacteristic = nil
        
        
        if let central = centralManager {
            let connectedPeripheral = central.retrieveConnectedPeripheralsWithServices([CBUUID(string: crazyflieServiceUuid)]) as! [CBPeripheral];
            
            if count(connectedPeripheral) > 0  && connectedPeripheral.first!.name != nil && connectedPeripheral.first!.name == self.address {
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
            if name == self.address {
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
                peripheral.discoverCharacteristics([CBUUID(string: crtpCharacteristicUuid),
                                                    CBUUID(string: crtpUpCharacteristicUuid),
                                                    CBUUID(string: crtpDownCharacteristicUuid)], forService: service);
                state = "characteristics"
            }
        }
    }
    
    func peripheral(peripheral: CBPeripheral!, didDiscoverCharacteristicsForService service: CBService!, error: NSError!) {
        for characteristic in service.characteristics as! [CBCharacteristic] {
            if characteristic.UUID.UUIDString == crtpCharacteristicUuid {
                self.crtpCharacteristic = characteristic
            } else if characteristic.UUID.UUIDString == crtpUpCharacteristicUuid {
                self.crtpUpCharacteristic = characteristic
            } else if characteristic.UUID.UUIDString == crtpDownCharacteristicUuid {
                self.crtpDownCharacteristic = characteristic
                peripheral.setNotifyValue(true, forCharacteristic: characteristic)
            }
            
            if self.crtpCharacteristic != nil && self.crtpUpCharacteristic != nil && crtpDownCharacteristic != nil {
                state = "connected"
                connectCallback?(true)
                // Start the packet polling
                dispatch_async(self.btQueue) {
                    self.sendAPacket()
                }
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
    
    private var decoderLength = 0
    private var decoderPid = -1
    private var decoderData: [UInt8] = []
    func peripheral(peripheral: CBPeripheral, didUpdateValueForCharacteristic characteristic: CBCharacteristic, error: NSError?) {
        println("Received value for characteristic: \(characteristic.UUID.UUIDString), length: \(characteristic.value.length)")
        
        var data = characteristic.value
        var dataArray = [UInt8](count: data.length, repeatedValue: 0)
        data.getBytes(&dataArray, length: dataArray.count)
        var header = ControlByte(Int(dataArray[0]))
        
        if header.start {
            if header.length < 20 {
                let packet = NSData(bytes: Array(dataArray[1..<dataArray.count]), length: dataArray.count-1)
                self.rxCallback?(packet)
                let fullData = Array(dataArray[1..<dataArray.count])
            } else {
                self.decoderData = Array(dataArray[1..<dataArray.count])
                self.decoderPid = header.pid
                self.decoderLength = header.length
            }
        } else {
            if header.pid == self.decoderPid {
                let fullData = self.decoderData + Array(dataArray[1..<dataArray.count])
                let packet = NSData(bytes: fullData, length: fullData.count)
                self.rxCallback?(packet)
            } else {
                self.decoderPid = -1
                self.decoderData = []
                self.decoderLength = 0
                NSLog("Bletooth link: Error while receiving long data: PID does not match!")
            }
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
    
    func getError() -> String {
        return error
    }
    
    func onStateUpdated(callback: NSString -> ()) {
        stateCallback = callback
    }
    
    
    // MARK: Bluetooth queue
    
    // The following variables are modified ONLY from the bluetooth execution queue
    private var packetQueue: [(NSData, ((Bool)->())?)] = []
    
    private var encodedSecondPacket: NSData! = nil
    private var encoderPid = 0
    
    private let nullPacket: NSData = NSData(bytes: [UInt8(0xff)], length: 1)
    
    /**
        Send a packet to Crazyflie

        :param: packet Packet to send. Should be less than 31Bytes long
        :param: callback Callback called when the packet has been sent of not.
                The boolean will be true is the packet has been sent, false otherwise.
    */
    func sendPacket(packet: NSData, callback: ((Bool) -> ())?) {
        dispatch_async(self.btQueue) {
            self.packetQueue.append((packet, callback))
        }
    }
    
    /* Send either a packet from the packetQueue or a NULL packet */
    private func sendAPacket() {
        var packet: NSData
        var callback: ((Bool)->())?
        
        if packetQueue.count > 0 {
            (packet, callback) = self.packetQueue.removeLast()
        } else {
            packet = self.nullPacket
            callback = nil
        }
        
        if state != "connected" {
            callback?(false)
            return
        }
        
        txCallback = callback
        
        // If the packet is small send it with the simple crtp characteristic, otherwise send it with the segmented crtpUp characteristic
        if packet.length <= 20 {
            self.encodedSecondPacket = nil
            crazyflie!.writeValue(packet, forCharacteristic: crtpCharacteristic, type: CBCharacteristicWriteType.WithResponse)
        } else {
            var packetArray = [UInt8](count: packet.length, repeatedValue: 0)
            packet.getBytes(&packetArray, length: packetArray.count)
            
            var header: UInt8 = UInt8(ControlByte(start: true, pid: self.encoderPid, length: packet.length).header)
            let firstPacket = NSData(bytes: [header] + Array(packetArray[0..<19]), length: 20)
            
            header = UInt8(ControlByte(start: false, pid: self.encoderPid, length: 0).header)
            self.encodedSecondPacket = NSData(bytes: [header] + Array(packetArray[19..<packetArray.count]), length: packetArray.count-19)
            
            crazyflie!.writeValue(firstPacket, forCharacteristic: crtpUpCharacteristic, type: CBCharacteristicWriteType.WithResponse)
            
            self.encoderPid = (self.encoderPid+1)%4
        }
        
    }
    
    func peripheral(peripheral: CBPeripheral!, didWriteValueForCharacteristic characteristic: CBCharacteristic!, error: NSError!) {
        if self.encodedSecondPacket == nil {
            txCallback?(true)
            dispatch_async(self.btQueue) {
                self.sendAPacket()
            }
        } else {
            crazyflie!.writeValue(self.encodedSecondPacket, forCharacteristic: crtpUpCharacteristic, type: CBCharacteristicWriteType.WithResponse)
            self.encodedSecondPacket = nil
        }
    }
}