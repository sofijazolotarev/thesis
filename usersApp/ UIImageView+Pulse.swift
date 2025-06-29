//
//   UIImageView+Pulse.swift
//  usersApp
//
//  Created by Sofija Zolotarev on 2.6.25..
//

import UIKit

@IBDesignable
extension UIImageView {
    @IBInspectable var pulses: Bool {
        get {
            return layer.animation(forKey: "pulse") != nil
        }
        set {
            if newValue {
                let pulse = CABasicAnimation(keyPath: "transform.scale")
                pulse.fromValue = 1.0
                pulse.toValue = 1.15
                pulse.duration = 0.7
                pulse.autoreverses = true
                pulse.repeatCount = .infinity
                pulse.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                layer.add(pulse, forKey: "pulse")
            } else {
                layer.removeAnimation(forKey: "pulse")
            }
        }
    }
}
