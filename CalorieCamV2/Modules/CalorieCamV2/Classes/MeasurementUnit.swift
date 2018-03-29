//
//  Distance.swift
//  CalorieCamV2
//
//  Created by Ryosuke Tanno on 18/02/24
//  Copyright © 2018年 RyosukeTanno. All rights reserved.
//

import UIKit
public var tmp_x: Float = 1
public var tmp_calorie: Float = 1
public var tmp_basis: Float = 1
public var tmp_length: Float = 1
public var tmp_area: Float = 1
public var show_cal:Float = 1

struct MeasurementUnit {
    enum Unit: String {
        static let all: [Unit] = [.inch, .foot, .centimeter, .meter]
        case inch = "inch"
        case foot = "foot"
        case centimeter = "centimeter"
        case meter = "meter"
        func next() -> Unit {
            switch self {
            case .inch:
                return .foot
            case .foot:
                return .centimeter
            case .centimeter:
                return .meter
            case .meter:
                return .inch
            }
        }
        
        func meterScale(isArea: Bool = false) -> Float {
            let scale: Float = isArea ? 2 : 1
            switch self {
            case .meter: return pow(1, scale)
            case .centimeter: return pow(100, scale)
            case .inch: return pow(39.370, scale)
            case .foot: return pow(3.2808399, scale)
            }
        }
        
        func unitStr(isArea: Bool = false) -> String {
            switch self {
            case .meter:
                return isArea ? "m^2" : "m"
            case .centimeter:
                return isArea ? "cm^2" : "cm"
            case .inch:
                return isArea ? "in^2" : "in"
            case .foot:
                return isArea ? "ft^2" : "ft"
            }
        }
    }
    private let rawValue: Float
    private let isArea: Bool
    init(meterUnitValue value: Float, isArea: Bool = false) {
        self.rawValue = value
        self.isArea = isArea
    }
    func string(type: Unit) -> String {
        let unit = type.unitStr(isArea: isArea)
        let scale = type.meterScale(isArea: isArea)

        let res = rawValue * scale
        tmp_length = res
        if  res < 0.1 {
            return String(format: "%.3f cm", res) +  unit
        } else if res < 1 {
            return String(format: "%.2f", res) +  unit
        } else if  res < 10 {
            return String(format: "%.1f cm", res) +  unit
        } else {
            return String(format: "%@: \n %.0f[kcal]", category_nam, show_cal)
        }
    }
    func attributeString(type: Unit,
                         valueFont: UIFont = UIFont.boldSystemFont(ofSize: 30),
                         unitFont: UIFont = UIFont.systemFont(ofSize: 20),
                         color: UIColor = UIColor.red,
                         color2: UIColor = UIColor.black) -> NSAttributedString {
        
        func buildAttributeString(value: String, unit: String) -> NSAttributedString {
            
            let main = NSMutableAttributedString()
            switch mode_select {
            case 1:
                show_cal = floor(show_cbase * tmp_length * tmp_length * 3.14 / show_base)
            case 0:
                show_cal = floor(show_cbase * tmp_area / show_base)
            default:
                print("def")
            }
            
            let v = NSMutableAttributedString(string: category_nam + "\n " + String(show_cal),
                                              attributes: [NSAttributedStringKey.font: valueFont,
                                                           NSAttributedStringKey.foregroundColor: color])
            let u = NSMutableAttributedString(string: "[kcal]",
                                              attributes: [NSAttributedStringKey.font: unitFont,
                                                           NSAttributedStringKey.foregroundColor: color2])
            main.append(v)
            main.append(u)
            return main
        }
        
        let unit = type.unitStr(isArea: isArea)
        let scale = type.meterScale(isArea: isArea)
        let res = rawValue * scale
        tmp_area = res
        if  res < 0.1 {
            return buildAttributeString(value: String(format: "%.3f", res), unit: unit)
        } else if res < 1 {
            return buildAttributeString(value: String(format: "%.2f", res), unit: unit)
        } else if  res < 10 {
            return buildAttributeString(value: String(format: "%.1f", res), unit: unit)
        } else {
            return buildAttributeString(value: String(format: "%.0f", res), unit: unit)
        }
    }
}
