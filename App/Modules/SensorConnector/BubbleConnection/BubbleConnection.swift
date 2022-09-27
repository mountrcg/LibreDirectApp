//
//  BubbleConnection.swift
//  GlucoseDirect
//

import Combine
import CoreBluetooth
import Foundation

// MARK: - BubbleConnection

class BubbleConnection: SensorBluetoothConnection, IsTransmitter {
    // MARK: Lifecycle

    init(subject: PassthroughSubject<DirectAction, DirectError>) {
        DirectLog.info("init")
        super.init(subject: subject, serviceUUID: CBUUID(string: "6E400001-B5A3-F393-E0A9-E50E24DCCA9E"))
    }

    // MARK: Internal

    override var peripheralName: String {
        "bubble"
    }

    override func resetBuffer() {
        rxBuffer = Data()
    }

    override func checkRetrievedPeripheral(peripheral: CBPeripheral) -> Bool {
        return peripheral.name?.lowercased() == peripheralName
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        DirectLog.info("Peripheral: \(peripheral)")

        sendUpdate(error: error)

        if let services = peripheral.services {
            for service in services {
                DirectLog.info("Service Uuid: \(service.uuid)")

                peripheral.discoverCharacteristics([writeCharacteristicUUID, readCharacteristicUUID], for: service)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        DirectLog.info("Peripheral: \(peripheral)")

        sendUpdate(error: error)

        if let characteristics = service.characteristics {
            for characteristic in characteristics {
                DirectLog.info("Characteristic Uuid: \(characteristic.uuid.description)")

                if characteristic.uuid == readCharacteristicUUID {
                    readCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }

                if characteristic.uuid == writeCharacteristicUUID {
                    writeCharacteristic = characteristic
                }
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        DirectLog.info("Peripheral: \(peripheral)")

        sendUpdate(error: error)

        guard let writeCharacteristic = writeCharacteristic else {
            return
        }

        peripheral.writeValue(Data([0x00, 0x00, UInt8(sensorInterval)]), for: writeCharacteristic, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        DirectLog.info("Peripheral: \(peripheral)")

        guard let value = characteristic.value else {
            return
        }

        guard let firstByte = value.first, let bubbleResponseState = BubbleResponseType(rawValue: firstByte) else {
            return
        }

        DirectLog.info("BubbleResponseState: \(bubbleResponseState)")

        switch bubbleResponseState {
        case .dataInfo:
            let hardwareMajor = value[value.count-2]
            let hardwareMinor = value[value.count-1]
            let hardware = Double("\(hardwareMajor).\(hardwareMinor)")
            let firmwareMajor = value[2]
            let firmwareMinor = value[3]
            let firmware = Double("\(firmwareMajor).\(firmwareMinor)")
            let battery = Int(value[4])

            let transmitter = Transmitter(name: peripheral.name ?? "Bubble", battery: battery, firmware: firmware, hardware: hardware)
            sendUpdate(transmitter: transmitter)
            sendUpdate(isPaired: true)

            if let writeCharacteristic = writeCharacteristic {
                peripheral.writeValue(Data([0x02, 0x00, 0x00, 0x00, 0x00, 0x2b]), for: writeCharacteristic, type: .withResponse)
            }

        case .dataPacket:
            rxBuffer.append(value.suffix(from: 4))

            if rxBuffer.count >= expectedBufferSize {
                DirectLog.info("Completed DataPacket")

                guard let uuid = uuid, let patchInfo = patchInfo else {
                    resetBuffer()
                    return
                }

                let type = sensor?.type ?? SensorType(patchInfo)
                guard type == .libre1 || type == .libre2EU || type == .libreUS14day else {
                    resetBuffer()
                    return
                }

                guard let fram = type == .libre1
                    ? rxBuffer[..<expectedBufferSize]
                    : Libre2EUtility.decryptFRAM(uuid: uuid, patchInfo: patchInfo, fram: rxBuffer[..<expectedBufferSize])
                else {
                    resetBuffer()
                    return
                }

                let sensor = Sensor.libreStyleSensor(uuid: uuid, patchInfo: patchInfo, fram: fram)
                
                guard let factoryCalibration = sensor.factoryCalibration else {
                    resetBuffer()
                    return
                }
                
                sendUpdate(sensor: sensor, keepDevice: true)

                if sensor.age >= sensor.lifetime {
                    sendUpdate(age: sensor.age, state: .expired)

                } else if sensor.age > sensor.warmupTime {
                    let readings = LibreUtility.parseFRAM(calibration: factoryCalibration, pairingTimestamp: sensor.pairingTimestamp, fram: fram)

                    sendUpdate(age: sensor.age, state: sensor.state)
                    sendUpdate(readings: readings.history + readings.trend)
                } else if sensor.age <= sensor.warmupTime {
                    sendUpdate(age: sensor.age, state: sensor.state)
                }

                resetBuffer()
            }

        case .noSensor:
            sendUpdate(sensor: nil)
            resetBuffer()

        case .serialNumber:
            guard value.count >= 10 else {
                return
            }

            uuid = value.subdata(in: 2 ..< 10)
            resetBuffer()

        case .patchInfo:
            patchInfo = value.subdata(in: 5 ..< 11)
        }
    }

    // MARK: Private

    private let expectedBufferSize = 344

    private let writeCharacteristicUUID = CBUUID(string: "6E400002-B5A3-F393-E0A9-E50E24DCCA9E")
    private let readCharacteristicUUID = CBUUID(string: "6E400003-B5A3-F393-E0A9-E50E24DCCA9E")

    private var readCharacteristic: CBCharacteristic?
    private var writeCharacteristic: CBCharacteristic?

    private var uuid: Data?
    private var patchInfo: Data?
    private var hardware: Double?
    private var firmware: Double?

    private var rxBuffer = Data()
}

// MARK: - BubbleResponseType

private enum BubbleResponseType: UInt8 {
    case dataInfo = 128 // = wakeUp + device info
    case dataPacket = 130
    // case decryptedDataPacket = 0x88
    case noSensor = 191
    case patchInfo = 193 // 0xC1
    case serialNumber = 192
}
