import Foundation

// Calculator.swift
// A small, safe calculator. It understands + - × ÷ ^ % ( ), the functions sqrt, abs, sin, cos, tan,
// ln, log, and the constants pi and e. It never runs code: it only reads numbers and these symbols.

enum Calculator {
    struct CalcError: Error {}

    /// nil if the text isn't a valid calculation.
    static func evaluate(_ text: String) -> Double? {
        var parser = Parser(text)
        guard let value = try? parser.parseAll(), value.isFinite else { return nil }
        return value
    }

    /// 58.5 -> "58.5", 4.0 -> "4", 1/3 -> "0.3333333333"
    static func format(_ value: Double) -> String {
        if value == value.rounded() && abs(value) < 1e15 { return String(Int64(value)) }
        return String(format: "%.10g", value)
    }

    struct Parser {
        private var chars: [Character]
        private var pos = 0

        init(_ text: String) {
            var cleaned = text.lowercased()
            for (from, to) in [("×", "*"), ("÷", "/"), ("−", "-"), ("–", "-"), (",", ".")] {
                cleaned = cleaned.replacingOccurrences(of: from, with: to)
            }
            chars = Array(cleaned.filter { !$0.isWhitespace })
        }

        mutating func parseAll() throws -> Double {
            guard !chars.isEmpty else { throw CalcError() }
            let value = try expression()
            guard pos == chars.count else { throw CalcError() }
            return value
        }

        private func peek() -> Character? { pos < chars.count ? chars[pos] : nil }

        // expression = term { (+|-) term }
        private mutating func expression() throws -> Double {
            var value = try term()
            while let c = peek(), c == "+" || c == "-" {
                pos += 1
                let rhs = try term()
                value = (c == "+") ? value + rhs : value - rhs
            }
            return value
        }

        // term = unary { (*|/) unary }
        private mutating func term() throws -> Double {
            var value = try unary()
            while let c = peek(), c == "*" || c == "/" {
                pos += 1
                let rhs = try unary()
                if c == "/" {
                    guard rhs != 0 else { throw CalcError() }
                    value /= rhs
                } else {
                    value *= rhs
                }
            }
            return value
        }

        // unary = [-|+] unary | power        (so -2^2 means -(2^2) = -4)
        private mutating func unary() throws -> Double {
            if peek() == "-" { pos += 1; return -(try unary()) }
            if peek() == "+" { pos += 1; return try unary() }
            return try power()
        }

        // power = postfix [ ^ unary ]        (right to left: 2^3^2 = 2^(3^2))
        private mutating func power() throws -> Double {
            let base = try postfix()
            if peek() == "^" {
                pos += 1
                let exponent = try unary()
                return pow(base, exponent)
            }
            return base
        }

        // postfix = primary [ % ]   (50% = 0.5)
        private mutating func postfix() throws -> Double {
            var value = try primary()
            while peek() == "%" {
                pos += 1
                value /= 100
            }
            return value
        }

        private mutating func primary() throws -> Double {
            guard let c = peek() else { throw CalcError() }
            if c == "(" {
                pos += 1
                let value = try expression()
                guard peek() == ")" else { throw CalcError() }
                pos += 1
                return value
            }
            if c.isNumber || c == "." {
                var text = ""
                while let d = peek(), d.isNumber || d == "." { text.append(d); pos += 1 }
                guard let value = Double(text) else { throw CalcError() }
                return value
            }
            if c.isLetter {
                var name = ""
                while let d = peek(), d.isLetter { name.append(d); pos += 1 }
                switch name {
                case "pi": return Double.pi
                case "e": return M_E
                default: break
                }
                guard peek() == "(" else { throw CalcError() }
                pos += 1
                let argument = try expression()
                guard peek() == ")" else { throw CalcError() }
                pos += 1
                switch name {
                case "sqrt": guard argument >= 0 else { throw CalcError() }; return argument.squareRoot()
                case "abs": return abs(argument)
                case "sin": return sin(argument)
                case "cos": return cos(argument)
                case "tan": return tan(argument)
                case "ln": guard argument > 0 else { throw CalcError() }; return log(argument)
                case "log": guard argument > 0 else { throw CalcError() }; return log10(argument)
                default: throw CalcError()
                }
            }
            throw CalcError()
        }
    }
}

// MARK: - Unit converter

struct UnitChoice: Identifiable {
    let name: String
    let unit: Dimension
    var id: String { name }
}

enum UnitCategory: String, CaseIterable, Identifiable {
    case length, mass, temperature, volume, speed, data
    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var units: [UnitChoice] {
        switch self {
        case .length:
            return [UnitChoice(name: "Metres", unit: UnitLength.meters), UnitChoice(name: "Kilometres", unit: UnitLength.kilometers),
                    UnitChoice(name: "Centimetres", unit: UnitLength.centimeters), UnitChoice(name: "Millimetres", unit: UnitLength.millimeters),
                    UnitChoice(name: "Miles", unit: UnitLength.miles), UnitChoice(name: "Yards", unit: UnitLength.yards),
                    UnitChoice(name: "Feet", unit: UnitLength.feet), UnitChoice(name: "Inches", unit: UnitLength.inches)]
        case .mass:
            return [UnitChoice(name: "Kilograms", unit: UnitMass.kilograms), UnitChoice(name: "Grams", unit: UnitMass.grams),
                    UnitChoice(name: "Milligrams", unit: UnitMass.milligrams), UnitChoice(name: "Pounds", unit: UnitMass.pounds),
                    UnitChoice(name: "Ounces", unit: UnitMass.ounces), UnitChoice(name: "Stones", unit: UnitMass.stones)]
        case .temperature:
            return [UnitChoice(name: "Celsius", unit: UnitTemperature.celsius), UnitChoice(name: "Fahrenheit", unit: UnitTemperature.fahrenheit),
                    UnitChoice(name: "Kelvin", unit: UnitTemperature.kelvin)]
        case .volume:
            return [UnitChoice(name: "Litres", unit: UnitVolume.liters), UnitChoice(name: "Millilitres", unit: UnitVolume.milliliters),
                    UnitChoice(name: "Gallons (US)", unit: UnitVolume.gallons), UnitChoice(name: "Cups (US)", unit: UnitVolume.cups),
                    UnitChoice(name: "Fluid ounces (US)", unit: UnitVolume.fluidOunces)]
        case .speed:
            return [UnitChoice(name: "Metres/second", unit: UnitSpeed.metersPerSecond), UnitChoice(name: "Kilometres/hour", unit: UnitSpeed.kilometersPerHour),
                    UnitChoice(name: "Miles/hour", unit: UnitSpeed.milesPerHour), UnitChoice(name: "Knots", unit: UnitSpeed.knots)]
        case .data:
            return [UnitChoice(name: "Bytes", unit: UnitInformationStorage.bytes), UnitChoice(name: "Kilobytes", unit: UnitInformationStorage.kilobytes),
                    UnitChoice(name: "Megabytes", unit: UnitInformationStorage.megabytes), UnitChoice(name: "Gigabytes", unit: UnitInformationStorage.gigabytes),
                    UnitChoice(name: "Terabytes", unit: UnitInformationStorage.terabytes)]
        }
    }

    static func convert(_ value: Double, from: Dimension, to: Dimension) -> Double {
        Measurement<Dimension>(value: value, unit: from).converted(to: to).value
    }
}
