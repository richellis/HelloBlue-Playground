import Cocoa
import CoreBluetooth
import PlaygroundSupport

PlaygroundPage.current.needsIndefiniteExecution = true

class BluetoothManager : NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    var centralManager : CBCentralManager
    var peripheral : CBPeripheral?
    
    public var targetPeripheralName: String?
    
    var ledCharacteristic : CBCharacteristic?
    var lightState = false
    
    // Commands for BMDWare
    
    let offCommand : [UInt8] = [0x55]
    let onCommand  : [UInt8] = [0x54, 0x09, 0x00]
    let ledCharactertisticUUID = CBUUID.init(string:"2413B43F-707F-90BD-2045-2AB8807571B7")
    
    // Commands for EvalDemo
    /*
     let offCommand : [UInt8] = [0x00, 0x00, 0x00]
     let onCommand  : [UInt8] = [0xff, 0xff, 0xff]
     let ledCharactertisticUUID = CBUUID.init(string:"50DB1525-418D-4690-9589-AB7BE9E22684")
     */
    
    
    override init() {
        self.centralManager = CBCentralManager.init(delegate: nil, queue: nil)
        super.init()
        // Set self as the delegate of the CentralManager
        self.centralManager.delegate = self
    }
    
    func toggleLED() {
        print("toggling LED")
        let command : [UInt8] = lightState ? offCommand : onCommand
        if let ledChar = ledCharacteristic {
            peripheral?.writeValue(Data.init(bytes: command), for: ledChar, type: .withoutResponse) // for EvalDemo, must be .withoutResponse
            lightState = !lightState
        }
    }
    
    /// Executes closure on global queue (not main) after a delay of *seconds* seconds
    public func performActions(after seconds: Double, _ action: @escaping () -> Void) {
        let rawDelay = DispatchTime.now().rawValue + dispatch_time_t(seconds * Double(NSEC_PER_SEC))
        let delay = DispatchTime(uptimeNanoseconds: rawDelay)
        DispatchQueue
            .global(qos: .default)
            .asyncAfter(deadline:  delay, execute: action)
    }
    
    public var count = 10
    
    public func startFlashing(delay: Double) {
        if count > 0 {
            toggleLED()
            count -= 1
            performActions(after: delay) { self.startFlashing(delay: delay) }
        }
    }
    
    // MARK: Central Manager Delegate Methods
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOff:
            print("BLE has powered off")
            centralManager.stopScan()
            
        case .poweredOn:
            print("BLE is now powered on")
            
            if let targetPeripheralName = targetPeripheralName {
                print("Looking for \"\(targetPeripheralName)\"")
            } else {
                print("\n\n*** Set `targetPeripheralName` to connect ***\n\n")
            }

            centralManager.scanForPeripherals(withServices: nil, options: nil)
            
        case .resetting: print("BLE is resetting")
        case .unauthorized: print("Unauthorized BLE state")
        case .unknown: print("Unknown BLE state")
        case .unsupported: print("This platform does not support BLE")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData advertisement: [String : Any], rssi: NSNumber) {
        guard let name = peripheral.name else { return }
        
        // RSSI is Received Signal Strength Indicator
        let connectable = advertisement["kCBAdvDataIsConnectable"] as? Bool ?? false
        print("Found \"\(name)\" (\(peripheral.identifier)) peripheral (RSSI: \(rssi)) connectable: \(connectable)")
//        print("Advertisement data:", advertisement, "\n")
        
        // In this example, we are looking for devices of a specific name, one could look for devices of a certain UUID, or other data which may be available in the advertisingData
        // Please look at the back of your device to find out it's name.
        // You should check your log to see if you are discovering a device with the correct name
        
        if name == targetPeripheralName {
            self.peripheral = peripheral
            centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("CentralManager did Connect to Peripheral: : \(peripheral)")
        // Stop scanning after you connect to the device you are looking for
        central.stopScan()
        // Set self as the delegate of the peripheral
        peripheral.delegate = self
        // Start discovery of Services. As in scanning, one can limit discovery to specific services by passing in an array of the specific UUIDs.
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        // Likely, you would send an alert to your user here.
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
    }
    
    // MARK: Peripheral Delegate Methods
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else {
            print("Peripheral has no services")
            return
        }
        
        print("Peripheral did Discover Services: \(services) \n")
        
        // Once you have found services, you can elect to discover their characteristics
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else {
            print("Peripheral has no characteristics")
            return
        }
        
        print("Peripheral did Discover Characteristics: \(characteristics) \n")
        
        for char in characteristics as [CBCharacteristic] {
            if char.uuid == ledCharactertisticUUID {
                print("Set LED Charactertistic")
                ledCharacteristic = char
                
                startFlashing(delay: 1)
                
                break
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Peripheral did update value")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        print("Peripheral did write value: \(characteristic.value)")
        if let error = error { print(error) }
    }
}


let bt = BluetoothManager()
//bt.targetPeripheralName = "matt"

