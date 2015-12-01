//
//  NKLineChartDataItem.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/7/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NKLineChartDataItem : NSObject

+ (NKLineChartDataItem *)dataItemWithY:(CGFloat)y;

@property (readonly) CGFloat y; // should be within the y range


@end
