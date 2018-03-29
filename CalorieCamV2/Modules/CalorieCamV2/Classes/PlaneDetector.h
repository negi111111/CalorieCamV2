//
//  PlaneDetector.h
//  CalorieCamV2
//
//  Created by Ryosuke Tanno on 18/02/24
//  Copyright © 2018年 RyosukeTanno. All rights reserved.
//


#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>

@interface PlaneDetector : NSObject

+ (SCNVector4)detectPlaneWithPoints:(NSArray <NSValue* >*)points;


@end
