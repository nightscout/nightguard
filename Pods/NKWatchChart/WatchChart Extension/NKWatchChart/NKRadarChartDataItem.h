//
//  NKRadarChartDataItem.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NKRadarChartDataItem : NSObject

+ (instancetype)dataItemWithValue:(CGFloat)value
                      description:(NSString *)description;

@property (nonatomic) CGFloat   value;
@property (nonatomic,copy) NSString *textDescription;

@end
