//
//  Toast.swift
//  HeartRate
//
//  Created by Arijit Sengupta on 6/10/21.
//  Copyright © 2021 Jonny. All rights reserved.
//

import Foundation

extension UIViewController {
  func showToast(message: String, seconds: Double) {
    let alert = UIAlertController(title: nil, message: message,
      preferredStyle: .alert)
    alert.view.backgroundColor = UIColor.black
    alert.view.alpha = 0.6
    alert.view.layer.cornerRadius = 15
    present(alert, animated: true)
    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + seconds) {
            alert.dismiss(animated: true)
    }
  }
}
