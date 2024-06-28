//
//  OASegmentedSlider.h
//  OsmAnd
//
//  Created by Skalii on 07.06.2022.
//  Copyright (c) 2022 OsmAnd. All rights reserved.
//

#import "OASlider.h"

@interface OASegmentedSlider : OASlider

@property (nonatomic) NSInteger selectedMark;
@property (nonatomic) CGFloat currentMarkX;
@property (nonatomic) CGFloat maximumForCurrentMark;

@property (nonatomic) NSInteger stepMinWithoutDrawMark;

- (NSInteger)getIndexForStepMinWithoutDrawMark;

- (void)setNumberOfMarks:(NSInteger)numberOfMarks
  additionalMarksBetween:(NSInteger)additionalMarksBetween;

- (void)makeCustom;

@end
