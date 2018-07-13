//
//  RulerARProViewController.swift
//  CalorieCamV2
//
//  Created by Ryosuke Tanno on 18/02/24
//  Copyright © 2018年 RyosukeTanno. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Photos
import AudioToolbox
import VideoToolbox
import Vision
import CoreML
public var category_nam:String = "Food"
public var show_base:Float = 1
public var show_cbase:Float = 1
public var mode_select:Int = 0

typealias Localization = R.string.rulerString

// MARK: - Image Center Crop
extension UIImage {
    func cropping(to: CGRect) -> UIImage? {
        var opaque = false
        if let cgImage = cgImage {
            switch cgImage.alphaInfo {
            case .noneSkipLast, .noneSkipFirst:
                opaque = true
            default:
                break
            }
        }
        
        UIGraphicsBeginImageContextWithOptions(to.size, opaque, scale)
        draw(at: CGPoint(x: -to.origin.x, y: -to.origin.y))
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
    }
}

class RulerARProViewController: UIViewController {
    

    
    
    enum MeasurementMode {
        case length
        case area
        func toAttrStr() -> NSAttributedString {
            let str = self == .area ? R.string.rulerString.startArea() : R.string.rulerString.startLength()
            return NSAttributedString(string: str, attributes: [NSAttributedStringKey.font : UIFont.boldSystemFont(ofSize: 20),
                                                                 NSAttributedStringKey.foregroundColor: UIColor.blue])
        }
    }
    struct Image {
        struct Menu {
            static let area = #imageLiteral(resourceName: "menu_area")
            static let length = #imageLiteral(resourceName: "menu_length")
            static let reset = #imageLiteral(resourceName: "menu_reset")
            static let setting = #imageLiteral(resourceName: "menu_setting")
            static let save = #imageLiteral(resourceName: "menu_save")
        }
        struct More {
            static let close = #imageLiteral(resourceName: "more_off")
            static let open = #imageLiteral(resourceName: "more_on")
        }
        struct Place {
            static let area = #imageLiteral(resourceName: "place_area")
            static let length = #imageLiteral(resourceName: "place_length")
            static let done = #imageLiteral(resourceName: "place_done")
        }
        struct Close {
            static let delete = #imageLiteral(resourceName: "cancle_delete")
            static let cancle = #imageLiteral(resourceName: "cancle_back")
        }
        struct Indicator {
            static let enable = #imageLiteral(resourceName: "img_indicator_enable")
            static let disable = #imageLiteral(resourceName: "img_indicator_disable")
        }
        struct Result {
            static let copy = #imageLiteral(resourceName: "result_copy")
        }
    }
    
    struct Sound {
        static var soundID: SystemSoundID = 0
        static func install() {
            guard let path = Bundle.main.path(forResource: "SetPoint", ofType: "wav") else { return  }
            let url = URL(fileURLWithPath: path)
            AudioServicesCreateSystemSoundID(url as CFURL, &soundID)
        }
        static func play() {
            guard soundID != 0 else { return }
            AudioServicesPlaySystemSound(soundID)
        }
        static func dispose() {
            guard soundID != 0 else { return }
            AudioServicesDisposeSystemSoundID(soundID)
        }

    }
    private let sceneView: ARSCNView =  ARSCNView(frame: UIScreen.main.bounds)
    private let indicator = UIImageView()
    private let resultLabel = UILabel().then({
        $0.textAlignment = .center
        $0.textColor = UIColor.black
        $0.numberOfLines = 0
        $0.font = UIFont.systemFont(ofSize: 10, weight: UIFont.Weight.heavy)
    })

    
    private var line: LineNode?
    private var lineSet: LineSetNode?
    
    
    private var lines: [LineNode] = []
    private var lineSets: [LineSetNode] = []
    private var planes = [ARPlaneAnchor: Plane]()
    private var focusSquare: FocusSquare?
    
    
    
    private var mode = MeasurementMode.area //最初のモード
    private var finishButtonState = false
    private var lastState: ARCamera.TrackingState = .notAvailable {
        didSet {
            switch lastState {
            case .notAvailable:
                guard HUG.isVisible else { return }
                HUG.show(title: Localization.aRNotAvailable())
            case .limited(let reason):
                switch reason {
                case .initializing:
                    HUG.show(title: Localization.aRInitializing(), message: Localization.aRInitializingMessage(), inSource: self, autoDismissDuration: nil)
                case .insufficientFeatures:
                    HUG.show(title: Localization.aRExcessiveMotion(), message: Localization.aRInitializingMessage(), inSource: self, autoDismissDuration: 5)
                case .excessiveMotion:
                    HUG.show(title: Localization.aRExcessiveMotion(), message: Localization.aRExcessiveMotionMessage(), inSource: self, autoDismissDuration: 5)
                default:
                    break
                }
            case .normal:
                HUG.dismiss()
            }
        }
    }
    private var measureUnit = ApplicationSetting.Status.defaultUnit {
        didSet {
            let v = measureValue
            measureValue = v
        }
    }
    private var measureValue: MeasurementUnit? {
        didSet {
            if let m = measureValue {
                resultLabel.text = nil
                resultLabel.attributedText = m.attributeString(type: measureUnit)
            } else {
                resultLabel.attributedText = mode.toAttrStr()
            }
        }
    }
    
    
    
    private lazy var menuButtonSet: PopButton = PopButton(buttons: menuButton.measurement,
                                                          menuButton.save,
                                                          menuButton.reset,
                                                          menuButton.setting,
                                                          menuButton.more)
    private let placeButton = UIButton(size: CGSize(width: 80, height: 80), image: Image.Place.area)
    private let cancleButton = UIButton(size: CGSize(width: 60, height: 60), image: Image.Close.delete)
    private let finishButton = UIButton(size: CGSize(width: 60, height: 60), image: Image.Place.done)
    private let menuButton = (measurement: UIButton(size: CGSize(width: 50, height: 50), image: Image.Menu.length),
                         save: UIButton(size: CGSize(width: 50, height: 50), image: Image.Menu.save),
                        reset: UIButton(size: CGSize(width: 50, height: 50), image: Image.Menu.reset),
                        setting: UIButton(size: CGSize(width: 50, height: 50), image: Image.Menu.setting),
                        more: UIButton(size: CGSize(width: 60, height: 60), image: Image.More.close))

    private var model: VNCoreMLModel!
    private var latestResult: VNClassificationObservation?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        layoutViewController()
        setupFocusSquare()
        Sound.install()
        model = try! VNCoreMLModel(for: Food101().model)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        restartSceneView()
    }
    
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    private func layoutViewController() {
        let width = view.bounds.width
        let height = view.bounds.height
        view.backgroundColor = UIColor.black
        
        
        do {
            view.addSubview(sceneView)
            sceneView.frame = view.bounds
            sceneView.delegate = self
        }
        do {
            

            let resultLabelBg = UIView()
            resultLabelBg.backgroundColor = UIColor.white.withAlphaComponent(0.8)
            resultLabelBg.layer.cornerRadius = 45
            resultLabelBg.clipsToBounds = true
            
            let copy = UIButton(size: CGSize(width: 30, height: 30), image: Image.Result.copy)
            copy.addTarget(self, action: #selector(RulerARProViewController.copyAction(_:)), for: .touchUpInside)
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(RulerARProViewController.changeMeasureUnitAction(_:)))
            resultLabel.addGestureRecognizer(tap)
            resultLabel.isUserInteractionEnabled = false
            
            
            resultLabelBg.frame = CGRect(x: 30, y: 30, width: width - 60, height: 90)
            copy.frame = CGRect(x: resultLabelBg.frame.maxX - 10 - 30,
                                y: resultLabelBg.frame.minY + (resultLabelBg.frame.height - 30)/2,
                                width: 30, height: 30)
            resultLabel.frame = resultLabelBg.frame.insetBy(dx: 10, dy: 0)
            resultLabel.attributedText = mode.toAttrStr()
            
            view.addSubview(resultLabelBg)
            view.addSubview(resultLabel)
            view.addSubview(copy)

            
            
        }
        
        do {
            indicator.image = Image.Indicator.disable
            view.addSubview(indicator)
            indicator.frame = CGRect(x: (width - 60)/2, y: (height - 60)/2, width: 60, height: 60)
        }
        do {
            view.addSubview(finishButton)
            view.addSubview(placeButton)
            finishButton.addTarget(self, action: #selector(RulerARProViewController.finishAreaAction(_:)), for: .touchUpInside)
            placeButton.addTarget(self, action: #selector(RulerARProViewController.placeAction(_:)), for: .touchUpInside)
            placeButton.frame = CGRect(x: (width - 80)/2, y: (height - 20 - 80), width: 80, height: 80)
            finishButton.center = placeButton.center
        }
        do {
            view.addSubview(cancleButton)
            cancleButton.addTarget(self, action: #selector(RulerARProViewController.deleteAction(_:)), for: .touchUpInside)
            cancleButton.frame = CGRect(x: 40, y: placeButton.frame.origin.y + 10, width: 60, height: 60)
        }
        do {
            view.addSubview(menuButtonSet)
            menuButton.more.addTarget(self, action: #selector(RulerARProViewController.showMenuAction(_:)), for: .touchUpInside)
            menuButton.setting.addTarget(self, action: #selector(RulerARProViewController.moreAction(_:)), for: .touchUpInside)
            menuButton.reset.addTarget(self, action: #selector(RulerARProViewController.restartAction(_:)), for: .touchUpInside)
            menuButton.measurement.addTarget(self, action: #selector(RulerARProViewController.changeMeasureMode(_:)), for: .touchUpInside)
            menuButton.save.addTarget(self, action: #selector(RulerARProViewController.saveImage(_:)), for: .touchUpInside)
            menuButtonSet.frame = CGRect(x: (width - 40 - 60), y: placeButton.frame.origin.y + 10, width: 60, height: 60)
            

        }
        
    }
    
    
    private func configureObserver() {
        func cleanLine() {
            line?.removeFromParent()
            line = nil
            for node in lines {
                node.removeFromParent()
            }
            
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: OperationQueue.main) { _ in
            cleanLine()
        }
    }
    
    deinit {
        Sound.dispose()
        NotificationCenter.default.removeObserver(self)
    }
}


// MARK: - Target Action
@objc private extension RulerARProViewController {
    func saveImage(_ sender: UIButton) {
        func buffer(from image: UIImage) -> CVPixelBuffer? {
            let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue, kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
            var pixelBuffer : CVPixelBuffer?
            let status = CVPixelBufferCreate(kCFAllocatorDefault, Int(image.size.width), Int(image.size.height), kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
            guard (status == kCVReturnSuccess) else {
                return nil
            }
            
            CVPixelBufferLockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
            let pixelData = CVPixelBufferGetBaseAddress(pixelBuffer!)
            
            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
            let context = CGContext(data: pixelData, width: Int(image.size.width), height: Int(image.size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer!), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
            
            context?.translateBy(x: 0, y: image.size.height)
            context?.scaleBy(x: 1.0, y: -1.0)
            
            UIGraphicsPushContext(context!)
            image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
            UIGraphicsPopContext()
            CVPixelBufferUnlockBaseAddress(pixelBuffer!, CVPixelBufferLockFlags(rawValue: 0))
            
            return pixelBuffer
        }
        let cal_db:[String:[Float]] = [
            "apple_pie":[500, 100],
            "baby_back_ribs":[500, 100],
            "baklava":[500, 100],
            "beef_carpaccio":[500, 100],
            "beef_tartare":[500, 100],
            "beet_salad":[500, 100],
            "beignets":[500, 100],
            "bibimbap":[500, 100],
            "bread_pudding":[500, 100],
            "breakfast_burrito":[500, 100],
            "bruschetta":[500, 100],
            "caesar_salad":[500, 100],
            "cannoli":[500, 100],
            "caprese_salad":[500, 100],
            "carrot_cake":[500, 100],
            "ceviche":[500, 100],
            "cheese_plate":[500, 100],
            "cheesecake":[500, 100],
            "chicken_curry":[500, 100],
            "chicken_quesadilla":[500, 100],
            "chicken_wings":[500, 100],
            "chocolate_cake":[500, 100],
            "chocolate_mousse":[500, 100],
            "churros":[500, 100],
            "clam_chowder":[500, 100],
            "club_sandwich":[500, 100],
            "crab_cakes":[500, 100],
            "creme_brulee":[500, 100],
            "croque_madame":[500, 100],
            "cup_cakes":[500, 100],
            "deviled_eggs":[500, 100],
            "donuts":[500, 100],
            "dumplings":[500, 100],
            "edamame":[500, 100],
            "eggs_benedict":[500, 100],
            "escargots":[500, 100],
            "falafel":[500, 100],
            "filet_mignon":[500, 100],
            "fish_and_chips":[500, 100],
            "foie_gras":[500, 100],
            "french_fries":[500, 100],
            "french_onion_soup":[500, 100],
            "french_toast":[500, 100],
            "fried_calamari":[500, 100],
            "fried_rice":[500, 100],
            "frozen_yogurt":[500, 100],
            "garlic_bread":[500, 100],
            "gnocchi":[500, 100],
            "greek_salad":[500, 100],
            "grilled_cheese_sandwich":[500, 100],
            "grilled_salmon":[500, 100],
            "guacamole":[500, 100],
            "gyoza":[192, 100],
            "hamburger":[500, 100],
            "hot_and_sour_soup":[500, 100],
            "hot_dog":[500, 100],
            "huevos_rancheros":[500, 100],
            "hummus":[500, 100],
            "ice_cream":[500, 100],
            "lasagna":[500, 100],
            "lobster_bisque":[500, 100],
            "lobster_roll_sandwich":[500, 100],
            "macaroni_and_cheese":[500, 100],
            "macarons":[500, 100],
            "miso_soup":[500, 100],
            "mussels":[500, 100],
            "nachos":[500, 100],
            "omelette":[500, 100],
            "onion_rings":[500, 100],
            "oysters":[500, 100],
            "pad_thai":[500, 100],
            "paella":[500, 100],
            "pancakes":[500, 100],
            "panna_cotta":[500, 100],
            "peking_duck":[500, 100],
            "pho":[500, 100],
            "pizza":[326, 144],
            "pork_chop":[500, 100],
            "poutine":[500, 100],
            "prime_rib":[500, 100],
            "pulled_pork_sandwich":[500, 100],
            "ramen":[454, 117.75],
            "ravioli":[500, 100],
            "red_velvet_cake":[500, 100],
            "risotto":[500, 100],
            "samosa":[500, 100],
            "sashimi":[500, 100],
            "scallops":[500, 100],
            "seaweed_salad":[500, 100],
            "shrimp_and_grits":[500, 100],
            "spaghetti_bolognese":[500, 100],
            "spaghetti_carbonara":[500, 100],
            "spring_rolls":[500, 100],
            "steak":[500, 100],
            "strawberry_shortcake":[500, 100],
            "sushi":[500, 100],
            "tacos":[500, 100],
            "takoyaki":[500, 100],
            "tiramisu":[500, 100],
            "tuna_tartare":[500, 100],
            "waffles":[500, 100]
        ]
        
        
        func coreMLRequest() -> VNCoreMLRequest {
            let request = VNCoreMLRequest(model: model, completionHandler: { (request, error) in
                guard let best = request.results?.first as? VNClassificationObservation  else {
                    return
                }
                let TMP_cal: Float = cal_db[best.identifier.components(separatedBy: ",").first!]![0]
                let TMP_base: Float = cal_db[best.identifier.components(separatedBy: ",").first!]![1]
                category_nam = best.identifier.components(separatedBy: ",").first!
                show_cbase = TMP_cal
                show_base = TMP_base
            })
            
            request.preferBackgroundProcessing = true
            
            request.imageCropAndScaleOption = .centerCrop
            
            return request
        }
        
        
        func saveImage(image: UIImage) {
            PHPhotoLibrary.shared().performChanges({
            }) { (isSuccess: Bool, error: Error?) in
                if let e = error {
                    HUG.show(title: Localization.saveFail(), message: e.localizedDescription)
                } else{
                    HUG.show(title: category_nam, message: "認識結果はこれで正解ですか？")
                }
            }
        }
        var image = sceneView.snapshot()
        image = image.cropping(to: CGRect(x: 0, y: 468, width: 1125, height: 1500))!
        
        var pixelbuffer: CVPixelBuffer? = nil
        pixelbuffer = buffer(from: image)
        
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelbuffer!)
        let request = coreMLRequest()
        do {
            try handler.perform([request])
        } catch {
            print(error)
        }
        
        
        switch PHPhotoLibrary.authorizationStatus() {
        case .authorized:
            saveImage(image: image)
        default:
            PHPhotoLibrary.requestAuthorization { (status) in
                switch status {
                case .authorized:
                    saveImage(image: image)
                default:
                    HUG.show(title: Localization.saveFail(), message: Localization.saveNeedPermission())
                }
            }
        }
    }
    func placeAction(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [.allowUserInteraction,.curveEaseOut], animations: {
            sender.transform = CGAffineTransform(scaleX: 1.2, y: 1.2)
        }) { (value) in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: [.allowUserInteraction,.curveEaseIn], animations: {
                sender.transform = CGAffineTransform.identity
            }) { (value) in
            }
        }
        Sound.play()
        switch mode {
            ///
        case .area:
            if let l = lineSet {
                l.addLine()
            } else {
                let startPos = sceneView.worldPositionFromScreenPosition(indicator.center, objectPos: nil)
                if let p = startPos.position {
                    lineSet = LineSetNode(startPos: p, sceneV: sceneView)
                }
            }
        case .length:
            if let l = line {
                lines.append(l)
                line = nil
            } else  {
                let startPos = sceneView.worldPositionFromScreenPosition(indicator.center, objectPos: nil)
                if let p = startPos.position {
                    line = LineNode(startPos: p, sceneV: sceneView)
                }
            }
        }
    }

    func restartAction(_ sender: UIButton) {
        showMenuAction(sender)
        line?.removeFromParent()
        line = nil
        for node in lines {
            node.removeFromParent()
        }
        
        lineSet?.removeFromParent()
        lineSet = nil
        for node in lineSets {
            node.removeFromParent()
        }
        restartSceneView()
        measureValue = nil
    }
    func deleteAction(_ sender: UIButton) {
        switch mode {
            ///
        case .area:
            if let ls = lineSet {
                if !ls.removeLine() {
                    lineSet = nil
                }
            } else if let lineSetLast = lineSets.popLast() {
                lineSetLast.removeFromParent()
            } else {
                lines.popLast()?.removeFromParent()
            }
        case .length:
            if line != nil {
                line?.removeFromParent()
                line = nil
            } else if let lineLast = lines.popLast() {
                lineLast.removeFromParent()
            } else {
                lineSets.popLast()?.removeFromParent()
            }
            ///
        }
        cancleButton.normalImage = Image.Close.delete
        measureValue = nil
    }
    func copyAction(_ sender: UIButton) {
        UIPasteboard.general.string = resultLabel.text
        HUG.show(title: "Copied to clipboard")
    }

    func moreAction(_ sender: UIButton) {
        guard let vc = UIStoryboard(name: "SettingViewController", bundle: nil).instantiateInitialViewController() else {
            return
        }
        showMenuAction(sender)
        present(vc, animated: true, completion: nil)
    }
    func showMenuAction(_ sender: UIButton) {
        if menuButtonSet.isOn {
            menuButtonSet.dismiss()
            menuButton.more.normalImage = Image.More.close
        } else {
            menuButtonSet.show()
            menuButton.more.normalImage = Image.More.open
        }
    }

    func finishAreaAction(_ sender: UIButton) {
        guard mode == .area,
            let line = lineSet,
            line.lines.count >= 2 else {
                lineSet = nil
                return
        }
        lineSets.append(line)
        lineSet = nil
        changeFinishState(state: false)
    }
    func changeFinishState(state: Bool) {
        guard finishButtonState != state else { return }
        finishButtonState = state
        var center = placeButton.center
        if state {
            center.y -= 100
        }
        UIView.animate(withDuration: 0.3) {
            self.finishButton.center = center
        }
    }

    func changeMeasureUnitAction(_ sender: UITapGestureRecognizer) {
        measureUnit = measureUnit.next()
    }
    
    
    func changeMeasureMode(_ sender: UIButton) {
        showMenuAction(sender)
        lineSet = nil
        line = nil
        switch mode {
            ///
        case .area:
            changeFinishState(state: false)
            menuButton.measurement.normalImage = Image.Menu.area
            placeButton.normalImage  = Image.Place.length
            placeButton.disabledImage = Image.Place.length
            mode = .length
        case .length:
            menuButton.measurement.normalImage = Image.Menu.length
            placeButton.normalImage  = Image.Place.area
            placeButton.disabledImage = Image.Place.area
            mode = .area
        }
        
        resultLabel.attributedText = mode.toAttrStr()
    }
}
// MARK: - UI
fileprivate extension RulerARProViewController {
    
    func restartSceneView() {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
//        sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        measureUnit = ApplicationSetting.Status.defaultUnit
        resultLabel.attributedText = mode.toAttrStr()
        updateFocusSquare()
    }
    
    func updateLine() -> Void {
        let startPos = sceneView.worldPositionFromScreenPosition(self.indicator.center, objectPos: nil)
        if let p = startPos.position {
            let camera = self.sceneView.session.currentFrame?.camera
            let cameraPos = SCNVector3.positionFromTransform(camera!.transform)
            if cameraPos.distanceFromPos(pos: p) < 0.05 {
                if line == nil {
                    placeButton.isEnabled = false
                    indicator.image = Image.Indicator.disable
                }
                return;
            }
            placeButton.isEnabled = true
            indicator.image = Image.Indicator.enable
            switch mode {
            case .area:
                guard let set = lineSet else {
                    changeFinishState(state: false)
                    cancleButton.normalImage = Image.Close.delete
                    return
                }
                let area = set.updatePosition(pos: p, camera: self.sceneView.session.currentFrame?.camera, unit: measureUnit)
                measureValue =  MeasurementUnit(meterUnitValue: area, isArea: true)
                changeFinishState(state: set.lines.count >= 2)
                cancleButton.normalImage = Image.Close.cancle

            case .length:
                guard let currentLine = line else {
                    cancleButton.normalImage = Image.Close.delete
                    return
                }
                let length = currentLine.updatePosition(pos: p, camera: self.sceneView.session.currentFrame?.camera, unit: measureUnit)
                measureValue =  MeasurementUnit(meterUnitValue: length, isArea: false)
                cancleButton.normalImage = Image.Close.cancle
            }
        }
    }
}

// MARK: - Plane
fileprivate extension RulerARProViewController {
    func addPlane(node: SCNNode, anchor: ARPlaneAnchor) {
        
        let plane = Plane(anchor, false)
        planes[anchor] = plane
        node.addChildNode(plane)
        indicator.image = Image.Indicator.enable
    }
    
    func updatePlane(anchor: ARPlaneAnchor) {
        if let plane = planes[anchor] {
            plane.update(anchor)
        }
    }
    
    func removePlane(anchor: ARPlaneAnchor) {
        if let plane = planes.removeValue(forKey: anchor) {
            plane.removeFromParentNode()
        }
    }
}

// MARK: - FocusSquare
fileprivate extension RulerARProViewController {
    
    func setupFocusSquare() {
        focusSquare?.isHidden = true
        focusSquare?.removeFromParentNode()
        focusSquare = FocusSquare()
//        sceneView.scene.rootNode.addChildNode(focusSquare!)
    }
    
    func updateFocusSquare() {
        if ApplicationSetting.Status.displayFocus {
            focusSquare?.hide()
        } else {
            focusSquare?.unhide()
        }
        let (worldPos, planeAnchor, _) = sceneView.worldPositionFromScreenPosition(sceneView.bounds.mid, objectPos: focusSquare?.position)
        if let worldPos = worldPos {
            focusSquare?.update(for: worldPos, planeAnchor: planeAnchor, camera: sceneView.session.currentFrame?.camera)
        }
    }
}
// MARK: - ARSCNViewDelegate
extension RulerARProViewController: ARSCNViewDelegate {
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        DispatchQueue.main.async {
            HUG.show(title: (error as NSError).localizedDescription)
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            self.updateFocusSquare()
            self.updateLine()
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.addPlane(node: node, anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.updatePlane(anchor: planeAnchor)
            }
        }
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        DispatchQueue.main.async {
            if let planeAnchor = anchor as? ARPlaneAnchor {
                self.removePlane(anchor: planeAnchor)
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        let state = camera.trackingState
        DispatchQueue.main.async {
            self.lastState = state
        }
    }
}
