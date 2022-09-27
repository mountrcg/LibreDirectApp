//
//  SensorBLEConnection.swift
//  GlucoseDirect
//

import Combine
import CoreBluetooth
import Foundation

// MARK: - SensorPeripheralType

enum SensorPeripheralType {
    case unknown
    case foundPeripheral
    case knownPeripheral
    case connectedPeripheral
}

// MARK: - SensorBluetoothConnection

class SensorBluetoothConnection: NSObject, SensorConnectionProtocol, CBCentralManagerDelegate, CBPeripheralDelegate {
    // MARK: Lifecycle

    init(subject: PassthroughSubject<DirectAction, DirectError>, serviceUUID: CBUUID) {
        DirectLog.info("init")

        super.init()

        self.subject = subject
        self.serviceUUID = serviceUUID
        self.manager = CBCentralManager(delegate: self, queue: managerQueue, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }

    deinit {
        DirectLog.info("deinit")

        managerQueue.sync {
            disconnect()
        }
    }

    // MARK: Internal

    var serviceUUID: CBUUID!
    var manager: CBCentralManager!

    let managerQueue = DispatchQueue(label: "libre-direct.sensor-ble-connection.queue")
    weak var subject: PassthroughSubject<DirectAction, DirectError>?

    var stayConnected = false
    var sensor: Sensor?
    var sensorInterval = 1
    var peripheralType: SensorPeripheralType = .unknown

    var peripheralName: String {
        preconditionFailure("This property must be overridden")
    }

    var peripheral: CBPeripheral? {
        didSet {
            oldValue?.delegate = nil
            peripheral?.delegate = self

            if let peripheralUUID = peripheral?.identifier.uuidString {
                sendUpdate(peripheralUUID: peripheralUUID)
            }
        }
    }
    
    func getConfiguration() -> [SensorConnectionConfigurationOption]? {
        return nil
    }

    func pairConnection() {
        DirectLog.info("PairSensor")

        sendUpdate(connectionState: .pairing)

        managerQueue.async {
            self.find()
        }
    }

    func connectConnection(sensor: Sensor, sensorInterval: Int) {
        DirectLog.info("ConnectSensor: \(sensor)")

        self.sensor = sensor
        self.sensorInterval = sensorInterval

        setStayConnected(stayConnected: true)

        managerQueue.async {
            self.find()
        }
    }

    func disconnectConnection() {
        DirectLog.info("DisconnectConnection")

        setStayConnected(stayConnected: false)

        managerQueue.sync {
            self.disconnect()
        }
    }

    func find() {
        DirectLog.info("Find")

        guard manager != nil else {
            DirectLog.error("Guard: manager is nil")
            return
        }

        guard manager.state == .poweredOn else {
            DirectLog.error("Guard: manager.state \(manager.state.rawValue) is not .poweredOn")
            return
        }

        if let peripheralUUIDString = UserDefaults.standard.connectionPeripheralUUID,
           let peripheralUUID = UUID(uuidString: peripheralUUIDString),
           let retrievedPeripheral = manager.retrievePeripherals(withIdentifiers: [peripheralUUID]).first,
           checkRetrievedPeripheral(peripheral: retrievedPeripheral)
        {
            DirectLog.info("Connect from retrievePeripherals")

            if let connectedPeripheral = manager.retrieveConnectedPeripherals(withServices: [serviceUUID]).first,
               connectedPeripheral.identifier == retrievedPeripheral.identifier
            {
                peripheralType = .connectedPeripheral
            } else {
                peripheralType = .knownPeripheral
            }

            connect(retrievedPeripheral)

        } else {
            DirectLog.info("Scan for peripherals")

            peripheralType = .foundPeripheral
            scan()
        }
    }

    func scan() {
        DirectLog.info("scan")

        guard manager != nil else {
            DirectLog.error("Guard: manager is nil")
            return
        }

        sendUpdate(connectionState: .scanning)
        manager.scanForPeripherals(withServices: [serviceUUID], options: nil)
    }

    func disconnect() {
        DirectLog.info("Disconnect")

        guard manager != nil else {
            DirectLog.error("Guard: manager is nil")
            return
        }

        if manager.isScanning {
            manager.stopScan()
        }

        if let peripheral = peripheral {
            manager.cancelPeripheralConnection(peripheral)
            self.peripheral = nil
        }

        sendUpdate(connectionState: .disconnected)
        sensor = nil
    }

    func connect(_ peripheral: CBPeripheral) {
        DirectLog.info("Connect: \(peripheral)")

        guard manager != nil else {
            DirectLog.error("Guard: manager is nil")
            return
        }

        self.peripheral = peripheral

        manager.connect(peripheral, options: nil)
        sendUpdate(connectionState: .connecting)
    }

    func resetBuffer() {
        preconditionFailure("This method must be overridden")
    }

    func setStayConnected(stayConnected: Bool) {
        DirectLog.info("StayConnected: \(stayConnected.description)")
        self.stayConnected = stayConnected
    }

    func checkRetrievedPeripheral(peripheral: CBPeripheral) -> Bool {
        preconditionFailure("This property must be overridden")
    }

    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        guard manager != nil else {
            DirectLog.error("Guard: manager is nil")
            return
        }

        if let manager = manager {
            switch manager.state {
            case .poweredOff:
                sendUpdate(connectionState: .powerOff)

            case .poweredOn:
                sendUpdate(connectionState: .disconnected)

                guard stayConnected else {
                    break
                }

                find()
            default:
                sendUpdate(connectionState: .unknown)
            }
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        DirectLog.info("Peripheral: \(peripheral)")

        guard manager != nil else {
            DirectLog.error("Guard: manager is nil")
            return
        }

        guard peripheral.name?.lowercased().starts(with: peripheralName) ?? false else {
            return
        }

        manager.stopScan()
        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        DirectLog.info("Peripheral: \(peripheral), didFailToConnect")

        sendUpdate(connectionState: .disconnected)
        sendUpdate(error: error)

        guard stayConnected else {
            return
        }

        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        DirectLog.info("Peripheral: \(peripheral), didDisconnectPeripheral")

        sendUpdate(connectionState: .disconnected)
        sendUpdate(error: error)

        guard stayConnected else {
            return
        }

        connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DirectLog.info("Peripheral: \(peripheral)")

        resetBuffer()

        sendUpdate(connectionState: .connected)
        peripheral.discoverServices([serviceUUID])
    }
}
