//
//  NKRadarChartDataItem.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import "NKRadarChartDataItem.h"

@implementation NKRadarChartDataItem

+ (instancetype)dataItemWithValue:(CGFloat)value
                      description:(NSString *)description {
    NKRadarChartDataItem *item = [NKRadarChartDataItem new];
    item.value = value;
    item.textDescription = description;
    return item;
}

- (void)setValue:(CGFloat)value {
    if (value<0) {
        _value = 0;
        NSLog(@"Value value can not be negative");
    }
    _value = value;
}

@end
