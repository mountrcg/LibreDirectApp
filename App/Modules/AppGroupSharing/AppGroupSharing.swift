//
//  FreeAPS.swift
//  GlucoseDirect
//

import Combine
import Foundation

func appGroupSharingMiddleware() -> Middleware<DirectState, DirectAction> {
    return appGroupSharingMiddleware(service: LazyService<AppGroupSharingService>(initialization: {
        AppGroupSharingService()
    }))
}

private func appGroupSharingMiddleware(service: LazyService<AppGroupSharingService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {
        case .startup:
            service.value.clearAll()
            service.value.setApp(app: DirectConfig.appName, appVersion: "\(DirectConfig.appVersion) (\(DirectConfig.appBuild))")

        case .selectConnection(id: _, connection: _):
            service.value.clearAll()

        case .setConnectionState(connectionState: let connectionState):
            service.value.setConnectionState(value: connectionState.localizedDescription)

        case .setSensor(sensor: let sensor, keepDevice: _):
            service.value.setSensor(sensor: sensor.type.localizedDescription, sensorState: sensor.state.localizedDescription, sensorConnectionState: state.connectionState.localizedDescription)

        case .setTransmitter(transmitter: let transmitter):
            service.value.setTransmitter(transmitter: transmitter.name, transmitterBattery: "\(transmitter.battery)%", transmitterHardware: transmitter.hardware?.description, transmitterFirmware: transmitter.firmware?.description)

        case .disconnectConnection:
            service.value.clearGlucoseValues()

        case .pairConnection:
            service.value.clearGlucoseValues()

        case .addBloodGlucose(glucoseValues: let glucoseValues):
            if let sensor = state.sensor {
                service.value.setSensor(sensor: sensor.type.localizedDescription, sensorState: sensor.state.localizedDescription, sensorConnectionState: state.connectionState.localizedDescription)
            } else {
                service.value.setSensor(sensor: nil, sensorState: nil, sensorConnectionState: nil)
            }

            if let transmitter = state.transmitter {
                service.value.setTransmitter(transmitter: transmitter.name, transmitterBattery: "\(transmitter.battery)%", transmitterHardware: transmitter.hardware?.description, transmitterFirmware: transmitter.firmware?.description)
            } else {
                service.value.setTransmitter(transmitter: nil, transmitterBattery: nil, transmitterHardware: nil, transmitterFirmware: nil)
            }

            guard let glucose = glucoseValues.last else {
                break
            }

            service.value.addBloodGlucose(glucoseValues: [glucose])

        case .addSensorGlucose(glucoseValues: let glucoseValues):
            if let sensor = state.sensor {
                service.value.setSensor(sensor: sensor.type.localizedDescription, sensorState: sensor.state.localizedDescription, sensorConnectionState: state.connectionState.localizedDescription)
            } else {
                service.value.setSensor(sensor: nil, sensorState: nil, sensorConnectionState: nil)
            }

            if let transmitter = state.transmitter {
                service.value.setTransmitter(transmitter: transmitter.name, transmitterBattery: "\(transmitter.battery)%", transmitterHardware: transmitter.hardware?.description, transmitterFirmware: transmitter.firmware?.description)
            } else {
                service.value.setTransmitter(transmitter: nil, transmitterBattery: nil, transmitterHardware: nil, transmitterFirmware: nil)
            }

            guard let glucose = glucoseValues.last else {
                break
            }

            service.value.addSensorGlucose(glucoseValues: [glucose])

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - AppGroupSharingService

private class AppGroupSharingService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create AppGroupSharingService")
    }

    // MARK: Internal

    func clearGlucoseValues() {
        UserDefaults.shared.sharedGlucose = nil
    }

    func clearOthers() {
        UserDefaults.shared.sharedSensor = nil
        UserDefaults.shared.sharedSensorState = nil
        UserDefaults.shared.sharedSensorConnectionState = nil
        UserDefaults.shared.sharedTransmitter = nil
        UserDefaults.shared.sharedTransmitterBattery = nil
        UserDefaults.shared.sharedTransmitterHardware = nil
        UserDefaults.shared.sharedTransmitterFirmware = nil
    }

    func clearAll() {
        clearGlucoseValues()
        clearOthers()
    }

    func setApp(app: String?, appVersion: String?) {
        UserDefaults.shared.sharedApp = app
        UserDefaults.shared.sharedAppVersion = appVersion
    }

    func setSensor(sensor: String?, sensorState: String?, sensorConnectionState: String?) {
        UserDefaults.shared.sharedSensor = sensor
        UserDefaults.shared.sharedSensorState = sensorState
        UserDefaults.shared.sharedSensorConnectionState = sensorConnectionState
    }

    func setConnectionState(value: String?) {
        UserDefaults.shared.sharedSensorConnectionState = value
    }

    func setTransmitter(transmitter: String?, transmitterBattery: String?, transmitterHardware: String?, transmitterFirmware: String?) {
        UserDefaults.shared.sharedTransmitter = transmitter
        UserDefaults.shared.sharedTransmitterBattery = transmitterBattery
        UserDefaults.shared.sharedTransmitterHardware = transmitterHardware
        UserDefaults.shared.sharedTransmitterFirmware = transmitterFirmware
    }

    func addBloodGlucose(glucoseValues: [BloodGlucose]) {
        let sharedValues = glucoseValues
            .map { $0.toFreeAPS() }
            .compactMap { $0 }

        guard let sharedValuesJson = try? JSONSerialization.data(withJSONObject: sharedValues) else {
            return
        }

        UserDefaults.shared.sharedGlucose = sharedValuesJson
    }

    func addSensorGlucose(glucoseValues: [SensorGlucose]) {
        let sharedValues = glucoseValues
            .map { $0.toFreeAPS() }
            .compactMap { $0 }

        guard let sharedValuesJson = try? JSONSerialization.data(withJSONObject: sharedValues) else {
            return
        }

        UserDefaults.shared.sharedGlucose = sharedValuesJson
    }
}

private extension BloodGlucose {
    func toFreeAPS() -> [String: Any]? {
        let date = "/Date(" + Int64(floor(timestamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"

        let freeAPSGlucose: [String: Any] = [
            "Value": glucoseValue,
            "Trend": SensorTrend.unknown.toNightscoutTrend(),
            "DT": date,
            "direction": SensorTrend.unknown.toNightscoutDirection(),
            "from": DirectConfig.projectName
        ]

        return freeAPSGlucose
    }
}

private extension SensorGlucose {
    func toFreeAPS() -> [String: Any]? {
        let date = "/Date(" + Int64(floor(timestamp.toMillisecondsAsDouble() / 1000) * 1000).description + ")/"

        let freeAPSGlucose: [String: Any] = [
            "Value": glucoseValue,
            "Trend": trend.toNightscoutTrend(),
            "DT": date,
            "direction": trend.toNightscoutDirection(),
            "from": DirectConfig.projectName
        ]

        return freeAPSGlucose
    }
}
