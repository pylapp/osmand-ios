//
//  OsmAndAppProtocol.h
//  OsmAnd
//
//  Created by Alexey Pelykh on 2/25/14.
//  Copyright (c) 2014 OsmAnd. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "CommonTypes.h"
#import "OAObservable.h"
#import "OAAppData.h"
#import "OALocationServices.h"
#import "OAWorldRegion.h"
#import "OADownloadsManager.h"

#import "TTTLocationFormatter.h"

@protocol OsmAndAppProtocol <NSObject>

- (BOOL)initialize;

@property(readonly) OAAppData* data;
@property(readonly) OAWorldRegion* worldRegion;

@property(readonly) OALocationServices* locationServices;

@property(readonly) OADownloadsManager* downloadsManager;

@property(readonly) OAObservable* localResourcesChangedObservable;

@property(nonatomic) OAMapMode mapMode;
@property(readonly) OAObservable* mapModeObservable;

- (void)saveState;

- (TTTLocationFormatter*)locationFormatter;

@end
