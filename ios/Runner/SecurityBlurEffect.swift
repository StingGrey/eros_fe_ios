//
//  SecurityBlurEffect.swift
//  Runner
//
//  Created by 三夜 on 2021/2/9.
//

import UIKit

public class SecurityBlurEffect {
    private static let blurViewTag = 19999

    class func addBlurEffect(to window: UIWindow?) {
        guard let window, window.viewWithTag(blurViewTag) == nil else { return }
        let blurEffect = UIBlurEffect(style: .regular)
        let blurEffectView = UIVisualEffectView(effect: blurEffect)
        
        blurEffectView.tag = blurViewTag
        blurEffectView.alpha = 0.99
        blurEffectView.frame = window.bounds
        blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(blurEffectView)
    }

    class func removeBlurEffect(from window: UIWindow?) {
        guard let blurView = window?.viewWithTag(blurViewTag) as? UIVisualEffectView else { return }
        blurView.removeFromSuperview()
    }
}
