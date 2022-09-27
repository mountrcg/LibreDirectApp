//
//  Int.swift
//  GlucoseDirect
//

import Combine
import Foundation
import SwiftUI

// MARK: - GlucoseFormatters

struct GlucoseFormatters {
    static var percentFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        return formatter
    }()

    static var integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        return formatter
    }()

    static var mgdLFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0

        return formatter
    }()

    static var preciseMgdLFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2

        return formatter
    }()

    static var mmolLFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1

        return formatter
    }()

    static var preciseMmolLFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 2

        return formatter
    }()

    static var minuteChangeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.positivePrefix = "+"
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1

        return formatter
    }()
}

extension Int {
    var inDays: Int {
        let minutes = Double(self)

        return Int(minutes / 24 / 60)
    }

    var inHours: Int {
        let minutes = Double(self)

        return Int((minutes / 60).truncatingRemainder(dividingBy: 24))
    }

    var inMinutes: Int {
        let minutes = Double(self)

        return Int(minutes.truncatingRemainder(dividingBy: 60))
    }

    var inTime: String {
        return String(format: LocalizedString("%1$@d %2$@h %3$@min"), self.inDays.description, self.inHours.description, self.inMinutes.description)
    }

    var asMmolL: Decimal {
        return Double(self).asMmolL
    }

    var asMgdL: Decimal {
        return Decimal(self)
    }

    func pluralize(singular: String, plural: String) -> String {
        if self == 1 {
            return singular
        }

        return plural
    }

    func asPercent() -> String {
        return "\(GlucoseFormatters.percentFormatter.string(from: self as NSNumber)!)%"
    }

    func toPercent(of: Int) -> Double {
        return 100.0 / Double(of) * Double(self)
    }

    func isAlmost(_ lower: Int, _ upper: Int) -> Bool {
        if self >= (lower - 1), self <= (lower + 1) {
            return true
        }

        if self >= (upper - 1), self <= (upper + 1) {
            return true
        }

        return false
    }

    func asGlucose(unit: GlucoseUnit, withUnit: Bool = false, precise: Bool = false) -> String {
        var glucose: String

        if unit == .mmolL {
            if precise {
                glucose = GlucoseFormatters.preciseMmolLFormatter.string(from: self.asMmolL as NSNumber)!
            } else {
                glucose = GlucoseFormatters.mmolLFormatter.string(from: self.asMmolL as NSNumber)!
            }
        } else {
            glucose = String(self)
        }

        if withUnit {
            return "\(glucose) \(unit.localizedDescription)"
        }

        return glucose
    }
}

extension UInt16 {
    init(_ high: UInt8, _ low: UInt8) {
        self = UInt16(high) << 8 + UInt16(low)
    }

    init(_ data: Data) {
        self = UInt16(data[data.startIndex + 1]) << 8 + UInt16(data[data.startIndex])
    }
}

extension UInt64 {
    func asFileSize() -> String {
        var convertedValue = Double(self)
        var multiplyFactor = 0
        let tokens = ["bytes", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"]

        while convertedValue > 1024 {
            convertedValue /= 1024
            multiplyFactor += 1
        }
        return String(format: "%4.2f %@", convertedValue, tokens[multiplyFactor])
    }
}
