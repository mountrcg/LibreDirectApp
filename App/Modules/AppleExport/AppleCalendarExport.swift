//
//  CalendarExport.swift
//  GlucoseDirect
//

import Combine
import EventKit
import Foundation

func appleCalendarExportMiddleware() -> Middleware<DirectState, DirectAction> {
    return appleCalendarExportMiddleware(service: LazyService<AppleCalendarExportService>(initialization: {
        AppleCalendarExportService()
    }))
}

private func appleCalendarExportMiddleware(service: LazyService<AppleCalendarExportService>) -> Middleware<DirectState, DirectAction> {
    return { state, action, _ in
        switch action {           
        case .requestAppleCalendarAccess(enabled: let enabled):
            if enabled {
                return Future<DirectAction, DirectError> { promise in
                    service.value.requestAccess { granted in
                        if !granted {
                            promise(.failure(.withMessage("Calendar access declined")))

                        } else {
                            promise(.success(.setAppleCalendarExport(enabled: true)))
                        }
                    }
                }.eraseToAnyPublisher()

            } else {
                // clear events on disable
                service.value.clearGlucoseEvents()

                return Just(DirectAction.setAppleCalendarExport(enabled: false))
                    .setFailureType(to: DirectError.self)
                    .eraseToAnyPublisher()
            }

        case .addSensorGlucose(glucoseValues: let glucoseValues):
            guard state.appleCalendarExport else {
                DirectLog.info("Guard: state.calendarExport disabled")
                break
            }

            guard let calendarTarget = state.selectedCalendarTarget else {
                DirectLog.info("Guard: state.selectedCalendarTarget is nil")
                break
            }

            guard let glucose = glucoseValues.last else {
                break
            }

            service.value.addSensorGlucose(calendarTarget: calendarTarget, glucose: glucose, glucoseUnit: state.glucoseUnit, sensorInterval: Double(state.sensorInterval))

        default:
            break
        }

        return Empty().eraseToAnyPublisher()
    }
}

// MARK: - CalendarExportService

typealias CalendarExportHandler = (_ granted: Bool) -> Void

// MARK: - AppleCalendarExportService

private class AppleCalendarExportService {
    // MARK: Lifecycle

    init() {
        DirectLog.info("Create AppleCalendarExportService")
    }

    // MARK: Internal

    lazy var eventStore: EKEventStore = .init()

    func requestAccess(completionHandler: @escaping CalendarExportHandler) {
        eventStore.requestAccess(to: EKEntityType.event, completion: { granted, error in
            if granted, error == nil {
                completionHandler(true)
            } else {
                completionHandler(false)
            }
        })
    }

    func clearGlucoseEvents() {
        guard let calendar = calendar else {
            return
        }

        let predicate = eventStore.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -24 * 3600),
            end: Date(),
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)

        for event in events {
            if event.url == DirectConfig.appSchemaURL {
                do {
                    try eventStore.remove(event, span: .thisEvent)
                } catch {
                    DirectLog.error("Cannot remove calendar event: \(error)")
                }
            }
        }
    }

    func addSensorGlucose(calendarTarget: String, glucose: SensorGlucose, glucoseUnit: GlucoseUnit, sensorInterval: Double) {
        if calendar == nil || calendar?.title != calendarTarget {
            calendar = eventStore.calendars(for: .event).first(where: { $0.title == calendarTarget })
        }

        guard let calendar = calendar else {
            return
        }
        
        clearGlucoseEvents()

        let event = EKEvent(eventStore: eventStore)
        event.title = "\(glucose.trend.description) \(glucose.glucoseValue.asGlucose(unit: glucoseUnit, withUnit: true))"

        if let minuteChange = glucose.minuteChange?.asMinuteChange(glucoseUnit: glucoseUnit) {
            event.location = "\(glucose.timestamp.toLocalTime()), \(minuteChange)"
        }

        event.calendar = calendar
        event.url = DirectConfig.appSchemaURL
        event.startDate = glucose.timestamp
        event.endDate = glucose.timestamp + 15 * 60

        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            DirectLog.error("Cannot create calendar event: \(error)")
        }
    }

    // MARK: Private

    private var calendar: EKCalendar?

    private func findEvent() -> EKEvent? {
        guard let calendar = calendar else {
            return nil
        }

        let predicate = eventStore.predicateForEvents(
            withStart: Date(timeIntervalSinceNow: -24 * 3600),
            end: Date(),
            calendars: [calendar]
        )

        let events = eventStore.events(matching: predicate)

        for event in events {
            if event.url == DirectConfig.appSchemaURL {
                return event
            }
        }

        return nil
    }
}
