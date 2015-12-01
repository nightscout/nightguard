//
//  NKPieChart.h
//  NKWatchChartDemo
//
//  Created by Peng on 8/8/15.
//  Copyright © 2015 Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NKPieChart : NSObject

@property (nonatomic, readonly) NSArray	*items;

@property (nonatomic) UIColor *chartBackgroundColor;

@property (nonatomic) UIFont  *descriptionTextFont;

/** Default is white. */
@property (nonatomic) UIColor *descriptionTextColor;

/** Show only values, this is useful when legend is present */
@property (nonatomic) BOOL showOnlyValues;

/** Show absolute values not relative i.e. percentages */
@property (nonatomic) BOOL showAbsoluteValues;

- (id)initWithFrame:(CGRect)frame items:(NSArray *)items;

- (UIImage *)drawImage;

@end
