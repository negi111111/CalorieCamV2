//
//  SettingViewController.swift
//  CalorieCamV2
//
//  Created by Ryosuke Tanno on 18/02/24
//  Copyright © 2018年 RyosukeTanno. All rights reserved.
//

import UIKit

class SettingViewController: UIViewController {
    
    
//    @IBOutlet weak var unitSegment: UISegmentedControl!
//    @IBOutlet weak var displaySwitch: UISwitch!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        unitSegment.selectedSegmentIndex = MeasurementUnit.Unit.all.index(of: ApplicationSetting.Status.defaultUnit)!
//        displaySwitch.isEnabled = ApplicationSetting.Status.displayFocus
//        displaySwitch.onTintColor = UIColor(red:0.996, green:0.835, blue:0.380, alpha:1.000)
    }
    
    
    @IBAction func lengthUnitDidChange(_ sender: UISegmentedControl) {
        ApplicationSetting.Status.defaultUnit = MeasurementUnit.Unit.all[sender.selectedSegmentIndex]
    }
    
    @IBAction func closeButtonDidClick(_ sender: Any) {
        dismiss(animated: true, completion: nil)
    }
    
//    @IBAction func planeFocusDidChange(_ sender: UISwitch) {
//        ApplicationSetting.Status.displayFocus = sender.isEnabled
//    }
    
}
