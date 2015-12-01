//
//  NKLineChartData.m
//  NKWatchChartDemo
//
//  Created by Peng on 8/7/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import "NKLineChartData.h"

@implementation NKLineChartData

- (id)init
{
    self = [super init];
    if (self) {
        [self setupDefaultValues];
    }
    
    return self;
}

- (void)setupDefaultValues
{
    _inflexionPointStyle = NKLineChartPointStyleNone;
    _inflexionPointWidth = 4.f;
    _lineWidth = 2.f;
    _alpha = 1.f;
}

@end
