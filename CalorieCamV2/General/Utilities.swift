//
//  Utilities.swift
//  CalorieCamV2
//
//  Created by Ryosuke Tanno on 18/02/24
//  Copyright © 2018年 RyosukeTanno. All rights reserved.
//

import Foundation
import SceneKit
import ARKit

func planeDetectWithFeatureCloud(featureCloud: [SCNVector3]) -> (detectPlane: SCNVector3, planePoint: SCNVector3) {
    let warpFeatures = featureCloud.map({ (feature) -> NSValue in
        return NSValue(scnVector3: feature)
    })
    let result = PlaneDetector.detectPlane(withPoints: warpFeatures)
    var planePoint = SCNVector3Zero
    if result.x != 0 {
        planePoint = SCNVector3(result.w/result.x,0,0)
    }else if result.y != 0 {
        planePoint = SCNVector3(0,result.w/result.y,0)
    }else {
        planePoint = SCNVector3(0,0,result.w/result.z)
    }
    let detectPlane = SCNVector3(result.x, result.y, result.z)
    return (detectPlane, planePoint)
}

func planeLineIntersectPoint(planeVector: SCNVector3 , planePoint: SCNVector3, lineVector: SCNVector3, linePoint: SCNVector3) -> SCNVector3? {
    let vpt = planeVector.x * lineVector.x + planeVector.y * lineVector.y + planeVector.z * lineVector.z
    if vpt != 0 {
        let t = ((planePoint.x-linePoint.x)*planeVector.x + (planePoint.y-linePoint.y)*planeVector.y + (planePoint.z-linePoint.z)*planeVector.z)/vpt
        let cross = SCNVector3Make(linePoint.x + lineVector.x*t, linePoint.y + lineVector.y*t, linePoint.z + lineVector.z*t)
        if (cross-linePoint).length() < 5 {
            return cross
        }
    }
    return nil
}

func area3DPolygonFormPointCloud(points: [SCNVector3]) -> Float32 {
    let (detectPlane, planePoint) = planeDetectWithFeatureCloud(featureCloud: points)
    var newPoints = [SCNVector3]()
    for p in points {
        guard let ip = planeLineIntersectPoint(planeVector: detectPlane, planePoint: planePoint, lineVector: detectPlane, linePoint: p) else {
            return 0
        }
        newPoints.append(ip)
    }
    return area3DPolygon(points: newPoints, plane: detectPlane)
}
func area3DPolygon(points: [SCNVector3], plane: SCNVector3 ) -> Float32 {
    let n = points.count
    guard n >= 3 else { return 0 }
    var V = points
    V.append(points[0])
    V.append(points[1])
    let N = plane
    var area = Float(0)
    var (an, ax, ay, az) = (Float(0), Float(0), Float(0), Float(0))
    var coord = 0   // 1=x, 2=y, 3=z
    var (i, j, k) = (0, 0, 0)
    
    ax = (N.x>0 ? N.x : -N.x)
    ay = (N.y>0 ? N.y : -N.y)
    az = (N.z>0 ? N.z : -N.z)
    
    coord = 3;
    if (ax > ay) {
        if (ax > az) {
            coord = 1
        }
    } else if (ay > az) {
        coord = 2
    }
    (i, j, k) = (1, 2, 0)
    while i<=n {
        switch (coord) {
        case 1:
            area += (V[i].y * (V[j].z - V[k].z))
        case 2:
            area += (V[i].x * (V[j].z - V[k].z))
        case 3:
            area += (V[i].x * (V[j].y - V[k].y))
        default:
            break
        }
        i += 1
        j += 1
        k += 1
    }

    an = sqrt( ax*ax + ay*ay + az*az)
    switch (coord) {
    case 1:
        area *= (an / (2*ax))
    case 2:
        area *= (an / (2*ay))
    case 3:
        area *= (an / (2*az))
    default:
        break
    }
    return area
}



