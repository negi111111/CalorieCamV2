//
//  LineSetNode.swift
//  Ruler
//
//  Created by Ryosuke Tanno on 18/02/24
//  Copyright © 2018年 RyosukeTanno. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class LineSetNode: NSObject {
    private(set) var lines = [LineNode]()
    var currentNode: LineNode
    var closeNode: LineNode?
    let sceneView: ARSCNView
    let textNode: SCNNode

    
    
    init(startPos: SCNVector3, sceneV: ARSCNView) {
        sceneView = sceneV
        let line = LineNode(startPos: startPos,
                            sceneV: sceneV,
                            color: (UIColor.green, UIColor.green),
                            font: UIFont.systemFont(ofSize: 0.1)) //最初のライン上の文字フォントサイズ
        currentNode = line
        lines.append(line)
        
        let text = SCNText (string: "--", extrusionDepth: 0.1)
        text.font = UIFont.boldSystemFont(ofSize: 8)  //面積結果のフォント大きさ
        text.firstMaterial?.diffuse.contents = UIColor.cyan
        text.alignmentMode  = kCAAlignmentCenter
        text.truncationMode = kCATruncationMiddle
        text.firstMaterial?.isDoubleSided = true
        textNode = SCNNode(geometry: text)
        textNode.scale = SCNVector3(1/500.0, 1/500.0, 1/500.0)
        textNode.isHidden = true
        
        super.init()
    }
    
    
    func addLine() {
        currentNode = LineNode(startPos: currentNode.endNode.position,
                               sceneV: sceneView,
                               color: (UIColor.green, UIColor.green),
                               font: UIFont.systemFont(ofSize: 0.1)) //次のライン上の文字フォントサイズ
        lines.append(currentNode)
        resetCloseLine()
    }
    
    func removeLine() -> Bool {
        guard let n = lines.popLast(), lines.count >= 1 else {
            resetCloseLine()
            return false
        }
        n.removeFromParent()
        currentNode = lines.last!
        resetCloseLine()
        return true
    }
    
    
    func removeFromParent() {
        lines.forEach({ $0.removeFromParent() })
        textNode.removeFromParentNode()
    }
    
    private func resetCloseLine() {
        closeNode?.removeFromParent()
        closeNode = nil
        if lines.count > 1 {
            let closeNodeTemp = LineNode(startPos: lines[0].startNode.position,
                                         sceneV: sceneView,
                                         color: (UIColor.green, UIColor.green),
                                         font: UIFont.systemFont(ofSize: 0.1)) //最後のライン上の文字フォントサイズ
            closeNode = closeNodeTemp
        }
    }
    
    public func updatePosition(pos: SCNVector3, camera: ARCamera?, unit: MeasurementUnit.Unit = MeasurementUnit.Unit.centimeter) -> Float {
        _ = closeNode?.updatePosition(pos: pos, camera: camera, unit: unit)
        _ = currentNode.updatePosition(pos: pos, camera: camera, unit: unit)
        guard lines.count >= 2 else {
            textNode.isHidden = true
            return 0
        }
        var points = lines.map({ $0.endNode.position })
        points.append(lines[0].startNode.position)
        
        var center = points.average ?? points[0]
        center.y += 0.002
        let text = textNode.geometry as! SCNText
        let area = computePolygonArea(points: points)
        text.string = MeasurementUnit(meterUnitValue: area, isArea: true).string(type: unit)
        textNode.setPivot()
        textNode.position = center
        textNode.isHidden = false
        if textNode.parent == nil {
            sceneView.scene.rootNode.addChildNode(textNode)
        }
        return area
    }
    
    private func computePolygonArea(points: [SCNVector3]) -> Float {
        return abs(area3DPolygonFormPointCloud(points: points))
    }

    
}





