//
//  NKLineChartData.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/7/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef NS_ENUM(NSUInteger, NKLineChartPointStyle) {
    NKLineChartPointStyleNone = 0,
    NKLineChartPointStyleCircle = 1,
    NKLineChartPointStyleSquare = 3,
    NKLineChartPointStyleTriangle = 4
};

@class NKLineChartDataItem;

typedef NKLineChartDataItem *(^LCLineChartDataGetter)(NSUInteger item);

@interface NKLineChartData : NSObject

@property (strong) UIColor *color;
@property (nonatomic) CGFloat alpha;
@property NSUInteger itemCount;
@property (copy) LCLineChartDataGetter getData;

@property (nonatomic, assign) NKLineChartPointStyle inflexionPointStyle;

/**
 * If NKLineChartPointStyle is circle, this returns the circle's diameter.
 * If NKLineChartPointStyle is square, each point is a square with each side equal in length to this value.
 */
@property (nonatomic, assign) CGFloat inflexionPointWidth;

@property (nonatomic, assign) CGFloat lineWidth;

@end
