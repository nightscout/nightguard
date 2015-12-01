//
//  NKPieChartDataItem.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import "NKPieChartDataItem.h"

@implementation NKPieChartDataItem

+ (instancetype)dataItemWithValue:(CGFloat)value
                            color:(UIColor*)color{
    NKPieChartDataItem *item = [NKPieChartDataItem new];
    item.value = value;
    item.color  = color;
    return item;
}

+ (instancetype)dataItemWithValue:(CGFloat)value
                            color:(UIColor*)color
                      description:(NSString *)description {
    NKPieChartDataItem *item = [NKPieChartDataItem dataItemWithValue:value color:color];
    item.textDescription = description;
    return item;
}

- (void)setValue:(CGFloat)value{
    NSAssert(value >= 0, @"value should >= 0");
    if (value != _value){
        _value = value;
    }
}

@end
