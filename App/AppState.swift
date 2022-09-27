//
//  UserDefaultsAppState.swift
//  GlucoseDirect
//

import Combine
import Foundation
import UserNotifications
import SwiftUI

#if canImport(CoreNFC)
    import CoreNFC
#endif

// MARK: - AppState

struct AppState: DirectState {
    // MARK: Lifecycle

    init() {
        #if targetEnvironment(simulator)
            let defaultConnectionID = DirectConfig.virtualID
        #else
            #if canImport(CoreNFC)
                let defaultConnectionID = NFCTagReaderSession.readingAvailable
                    ? DirectConfig.libre2ID
                    : DirectConfig.bubbleID
            #else
                let defaultConnectionID = DirectConfig.bubbleID
            #endif
        #endif

        if UserDefaults.shared.glucoseUnit == nil {
            UserDefaults.shared.glucoseUnit = UserDefaults.standard.glucoseUnit ?? .mgdL
        }

        if let sensor = UserDefaults.standard.sensor, UserDefaults.shared.sensor == nil {
            UserDefaults.shared.sensor = sensor
        }

        if let transmitter = UserDefaults.standard.transmitter, UserDefaults.shared.transmitter == nil {
            UserDefaults.shared.transmitter = transmitter
        }

        self.alarmHigh = UserDefaults.standard.alarmHigh ?? 180
        self.alarmLow =  UserDefaults.standard.alarmLow ?? 80
        self.alarmSnoozeUntil = UserDefaults.standard.alarmSnoozeUntil
        self.appleCalendarExport = UserDefaults.standard.appleCalendarExport
        self.appleHealthExport = UserDefaults.standard.appleHealthExport
        self.bellmanAlarm = UserDefaults.standard.bellmanAlarm
        self.chartShowLines = UserDefaults.standard.chartShowLines
        self.chartZoomLevel = UserDefaults.standard.chartZoomLevel
        self.connectionAlarmSound = UserDefaults.standard.connectionAlarmSound
        self.connectionPeripheralUUID = UserDefaults.standard.connectionPeripheralUUID
        self.customCalibration = UserDefaults.standard.customCalibration
        self.expiringAlarmSound = UserDefaults.standard.expiringAlarmSound
        self.normalGlucoseNotification = UserDefaults.standard.normalGlucoseNotification
        self.alarmGlucoseNotification = UserDefaults.standard.alarmGlucoseNotification
        self.glucoseLiveActivity = UserDefaults.standard.glucoseLiveActivity
        self.ignoreMute = UserDefaults.standard.ignoreMute
        self.glucoseUnit = UserDefaults.shared.glucoseUnit ?? .mgdL
        self.highGlucoseAlarmSound = UserDefaults.standard.highGlucoseAlarmSound
        self.isConnectionPaired = UserDefaults.standard.isConnectionPaired
        self.latestBloodGlucose = UserDefaults.shared.latestBloodGlucose
        self.latestSensorGlucose = UserDefaults.shared.latestSensorGlucose
        self.latestSensorError = UserDefaults.shared.latestSensorError
        self.lowGlucoseAlarmSound = UserDefaults.standard.lowGlucoseAlarmSound
        self.nightscoutApiSecret = UserDefaults.standard.nightscoutApiSecret
        self.nightscoutUpload = UserDefaults.standard.nightscoutUpload
        self.nightscoutURL = UserDefaults.standard.nightscoutURL
        self.readGlucose = UserDefaults.standard.readGlucose
        self.selectedCalendarTarget = UserDefaults.standard.selectedCalendarTarget
        self.selectedConnectionID = UserDefaults.standard.selectedConnectionID ?? defaultConnectionID
        self.sensor = UserDefaults.shared.sensor
        self.sensorInterval = UserDefaults.standard.sensorInterval
        self.showAnnotations = UserDefaults.standard.showAnnotations
        self.transmitter = UserDefaults.shared.transmitter
    }

    // MARK: Internal

    var appState: ScenePhase = .inactive
    var bellmanConnectionState: BellmanConnectionState = .disconnected
    var bloodGlucoseHistory: [BloodGlucose] = []
    var bloodGlucoseValues: [BloodGlucose] = []
    var connectionError: String?
    var connectionErrorTimestamp: Date?
    var connectionInfos: [SensorConnectionInfo] = []
    var connectionState: SensorConnectionState = .disconnected
    var preventScreenLock = false
    var selectedConnection: SensorConnectionProtocol?
    var sensorErrorValues: [SensorError] = []
    var sensorGlucoseHistory: [SensorGlucose] = []
    var sensorGlucoseValues: [SensorGlucose] = []
    var glucoseStatistics: GlucoseStatistics? = nil
    var targetValue = 100
    var selectedView = DirectConfig.overviewViewTag

    var alarmHigh: Int { didSet { UserDefaults.standard.alarmHigh = alarmHigh } }
    var alarmLow: Int { didSet { UserDefaults.standard.alarmLow = alarmLow } }
    var alarmSnoozeUntil: Date? { didSet { UserDefaults.standard.alarmSnoozeUntil = alarmSnoozeUntil } }
    var appleCalendarExport: Bool { didSet { UserDefaults.standard.appleCalendarExport = appleCalendarExport } }
    var appleHealthExport: Bool { didSet { UserDefaults.standard.appleHealthExport = appleHealthExport } }
    var bellmanAlarm: Bool { didSet { UserDefaults.standard.bellmanAlarm = bellmanAlarm } }
    var chartShowLines: Bool { didSet { UserDefaults.standard.chartShowLines = chartShowLines } }
    var chartZoomLevel: Int { didSet { UserDefaults.standard.chartZoomLevel = chartZoomLevel } }
    var connectionAlarmSound: NotificationSound { didSet { UserDefaults.standard.connectionAlarmSound = connectionAlarmSound } }
    var connectionPeripheralUUID: String? { didSet { UserDefaults.standard.connectionPeripheralUUID = connectionPeripheralUUID } }
    var customCalibration: [CustomCalibration] { didSet { UserDefaults.standard.customCalibration = customCalibration } }
    var expiringAlarmSound: NotificationSound { didSet { UserDefaults.standard.expiringAlarmSound = expiringAlarmSound } }
    var normalGlucoseNotification: Bool { didSet { UserDefaults.standard.normalGlucoseNotification = normalGlucoseNotification } }
    var alarmGlucoseNotification: Bool { didSet { UserDefaults.standard.alarmGlucoseNotification = alarmGlucoseNotification } }
    var glucoseLiveActivity: Bool { didSet { UserDefaults.standard.glucoseLiveActivity = glucoseLiveActivity } }
    var glucoseUnit: GlucoseUnit { didSet { UserDefaults.shared.glucoseUnit = glucoseUnit } }
    var highGlucoseAlarmSound: NotificationSound { didSet { UserDefaults.standard.highGlucoseAlarmSound = highGlucoseAlarmSound } }
    var ignoreMute: Bool { didSet { UserDefaults.standard.ignoreMute = ignoreMute } }
    var isConnectionPaired: Bool { didSet { UserDefaults.standard.isConnectionPaired = isConnectionPaired } }
    var latestBloodGlucose: BloodGlucose? { didSet { UserDefaults.shared.latestBloodGlucose = latestBloodGlucose } }
    var latestSensorError: SensorError? { didSet { UserDefaults.shared.latestSensorError = latestSensorError } }
    var latestSensorGlucose: SensorGlucose? { didSet { UserDefaults.shared.latestSensorGlucose = latestSensorGlucose } }
    var lowGlucoseAlarmSound: NotificationSound { didSet { UserDefaults.standard.lowGlucoseAlarmSound = lowGlucoseAlarmSound } }
    var nightscoutApiSecret: String { didSet { UserDefaults.standard.nightscoutApiSecret = nightscoutApiSecret } }
    var nightscoutUpload: Bool { didSet { UserDefaults.standard.nightscoutUpload = nightscoutUpload } }
    var nightscoutURL: String { didSet { UserDefaults.standard.nightscoutURL = nightscoutURL } }
    var readGlucose: Bool { didSet { UserDefaults.standard.readGlucose = readGlucose } }
    var selectedCalendarTarget: String? { didSet { UserDefaults.standard.selectedCalendarTarget = selectedCalendarTarget } }
    var selectedConnectionID: String? { didSet { UserDefaults.standard.selectedConnectionID = selectedConnectionID } }
    var sensor: Sensor? { didSet { UserDefaults.shared.sensor = sensor } }
    var sensorInterval: Int { didSet { UserDefaults.standard.sensorInterval = sensorInterval } }
    var showAnnotations: Bool { didSet { UserDefaults.standard.showAnnotations = showAnnotations } }
    var transmitter: Transmitter? { didSet { UserDefaults.shared.transmitter = transmitter } }
}
