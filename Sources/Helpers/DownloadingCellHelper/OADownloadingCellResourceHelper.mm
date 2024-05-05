//
//  OADownloadingCellResourceHelper.m
//  OsmAnd Maps
//
//  Created by Max Kojin on 03/05/24.
//  Copyright © 2024 OsmAnd. All rights reserved.
//

#import "OADownloadingCellResourceHelper.h"
#import "OAResourcesUIHelper.h"
#import "OAPluginPopupViewController.h"
#import "OAManageResourcesViewController.h"
#import "GeneratedAssetSymbols.h"
#import "OsmAnd_Maps-Swift.h"

@implementation OADownloadingCellResourceHelper
{
    NSMutableDictionary<NSString *, OAResourceItem *> *_resourceItems;
    
    OAAutoObserverProxy* _downloadTaskProgressObserver;
    OAAutoObserverProxy* _downloadTaskCompletedObserver;
    OAAutoObserverProxy* _localResourcesChangedObserver;
}

- (instancetype)init
{
    self = [super init];
    if (self)
    {
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _resourceItems = [NSMutableDictionary dictionary];
    _downloadTaskProgressObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onDownloadResourceTaskProgressChanged:withKey:andValue:) andObserve:OsmAndApp.instance.downloadsManager.progressCompletedObservable];
    _downloadTaskCompletedObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onDownloadResourceTaskFinished:withKey:andValue:) andObserve:OsmAndApp.instance.downloadsManager.completedObservable];
    _localResourcesChangedObserver = [[OAAutoObserverProxy alloc] initWith:self withHandler:@selector(onLocalResourcesChanged:withKey:andValue:) andObserve:OsmAndApp.instance.localResourcesChangedObservable];
}

- (void)dealloc
{
    if (_downloadTaskProgressObserver)
    {
        [_downloadTaskProgressObserver detach];
        _downloadTaskProgressObserver = nil;
    }
    if (_downloadTaskCompletedObserver)
    {
        [_downloadTaskCompletedObserver detach];
        _downloadTaskCompletedObserver = nil;
    }
    if (_localResourcesChangedObserver)
    {
        [_localResourcesChangedObserver detach];
        _localResourcesChangedObserver = nil;
    }
}

#pragma mark - Resource methods

- (BOOL) isDisabled:(NSString *)resourceId
{
    OAResourceItem *resourceItem = _resourceItems[resourceId];
    if (resourceItem)
    {
        OAIAPHelper *iapHelper = OAIAPHelper.sharedInstance;
        if ((resourceItem.resourceType == OsmAndResourceType::WikiMapRegion) && ![iapHelper.wiki isActive])
            return YES;
        else if ((resourceItem.resourceType == OsmAndResourceType::SrtmMapRegion || resourceItem.resourceType == OsmAndResourceType::HillshadeRegion || resourceItem.resourceType == OsmAndResourceType::SlopeRegion)
                 && ![iapHelper.srtm isActive])
            return YES;
    }
    return NO;
}

// Override
- (BOOL) isInstalled:(NSString *)resourceId
{
    OAResourceItem *resourceItem = _resourceItems[resourceId];
    if (resourceItem)
        return resourceItem.isInstalled || [super isInstalled:resourceId];
    return NO;
}

// Override
- (BOOL) isDownloading:(NSString *)resourceId
{
    OAResourceItem *resourceItem = _resourceItems[resourceId];
    if (resourceItem)
        return resourceItem.downloadTask != nil && [super isDownloading:resourceId];
    return NO;
}

// Override
- (void) startDownload:(NSString *)resourceId
{
    OAResourceItem *resourceItem = _resourceItems[resourceId];
    if (resourceItem)
        [OAResourcesUIHelper offerDownloadAndInstallOf:((OARepositoryResourceItem *)resourceItem) onTaskCreated:nil onTaskResumed:nil];
}

// Override
- (void) stopDownload:(NSString *)resourceId
{
    if (_stopWithAlertMessage)
    {
        OAResourceItem *resourceItem = _resourceItems[resourceId];
        if (resourceItem)
        {
            [OAResourcesUIHelper offerCancelDownloadOf:resourceItem onTaskStop:nil completionHandler:^(UIAlertController *alert) {
                if (_hostViewController)
                    [_hostViewController presentViewController:alert animated:YES completion:nil];
            }];
        }
    }
    else
    {
        // Stop immediately
        id<OADownloadTask> task = [self getDownloadTask:resourceId];
        if (task)
            [task stop];
    }
    
}

- (id<OADownloadTask>) getDownloadTask:(NSString*)resourceId
{
    return [[[OsmAndApp instance].downloadsManager downloadTasksWithKey:[@"resource:" stringByAppendingString:resourceId]] firstObject];
}

- (BOOL) isUndefinedDownloadState:(NSString*)resourceId
{
    auto state = [self getDownloadTask:resourceId].state;
    return state != OADownloadTaskStateRunning && state != OADownloadTaskStateFinished;
}

#pragma mark - Cell setup methods

- (OADownloadingCell *) getOrCreateCellForResourceId:(NSString *)resourceId resourceItem:(OAResourceItem *)resourceItem
{
    if (!_resourceItems[resourceId])
    {
        _resourceItems[resourceId] = resourceItem;
    
        if (resourceItem.downloadTask)
            [self saveStatus:EOAItemStatusInProgressType resourceId:resourceId];
    }
    
    return [super getOrCreateCell:resourceId];
}

- (OADownloadingCell *) getOrCreateSwiftCellForResourceId:(NSString *)resourceId swiftResourceItem:(OAResourceSwiftItem *)swiftResourceItem
{
    if (swiftResourceItem && swiftResourceItem.objcResourceItem)
    {
        OAResourceItem *resourceItem = (OAResourceItem *)swiftResourceItem.objcResourceItem;
        if (!_resourceItems[resourceId])
            _resourceItems[resourceId] = resourceItem;
        
        return [super getOrCreateCell:resourceId];
    }
    return nil;
}

// Override
- (OADownloadingCell *) getOrCreateCell:(NSString *)resourceId
{
    // use new method instead
    return nil;
}

// Override
- (OADownloadingCell *) setupCell:(NSString *)resourceId
{
    OAResourceItem *resourceItem = _resourceItems[resourceId];
    if (resourceItem)
    {
        uint64_t _sizePkg = resourceItem.sizePkg;
        NSString *subtitle = [NSString stringWithFormat:@"%@  •  %@", [OAResourceType resourceTypeLocalized:resourceItem.resourceType], [NSByteCountFormatter stringFromByteCount:_sizePkg countStyle:NSByteCountFormatterCountStyleFile]];
        NSString *title = resourceItem.title;
        NSString *iconName = [OAResourceType getIconName:resourceItem.resourceType];
        BOOL isDownloading = [self isDownloading:resourceId];
        
        // get cell with default settings
        OADownloadingCell *cell = [super setupCell:resourceId title:title isTitleBold:NO desc:subtitle leftIconName:iconName rightIconName:[self getRightIconName] isDownloading:isDownloading];
        
        if ([self isDisabled:resourceId])
        {
            cell.titleLabel.textColor = [UIColor colorNamed:ACColorNameTextColorSecondary];
            [cell rightIconVisibility:NO];
        }
        return cell;
    }
    return nil;
}

#pragma mark - Cell behavior methods

// Override
- (void) onCellClicked:(NSString *)resourceId
{
    if (![self isInstalled:resourceId] || self.isAlwaysClickable)
    {
        if (![self isDownloading:resourceId])
        {
            if (![self isDisabled:resourceId])
                [self startDownload:resourceId];
            else
                [self showActivatePluginPopup:resourceId];
        }
        else
        {
            [self stopDownload:resourceId];
        }
    }
    else
    {
        // do nothing
    }
}

- (void)showActivatePluginPopup:(NSString *)resourceId
{
    OAResourceItem *resourceItem = _resourceItems[resourceId];
    if (resourceItem)
    {
        if (resourceItem.resourceType == OsmAndResourceType::WikiMapRegion)
            [OAPluginPopupViewController askForPlugin:kInAppId_Addon_Wiki];
        else if (resourceItem.resourceType == OsmAndResourceType::SrtmMapRegion || resourceItem.resourceType == OsmAndResourceType::HillshadeRegion || resourceItem.resourceType == OsmAndResourceType::SlopeRegion)
            [OAPluginPopupViewController askForPlugin:kInAppId_Addon_Srtm];
    }
}

#pragma mark - Downloading cell progress observer's methods

- (void)onDownloadResourceTaskProgressChanged:(id<OAObservableProtocol>)observer withKey:(id)key andValue:(id)value
{
    id<OADownloadTask> task = key;
    NSString *taskKey = task.key;
    float progress = ((NSNumber *)value).floatValue;
    
    // Skip all downloads that are not resources
    if (![taskKey hasPrefix:@"resource:"])
        return;
    
    taskKey = [taskKey stringByReplacingOccurrencesOfString:@"resource:" withString:@""];
    
    // Skip downloadings from another screens
    OAResourceItem *resourceItem = _resourceItems[taskKey];
    if (resourceItem)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            [super setCellProgress:taskKey progress:progress status:EOAItemStatusInProgressType];
        });
    }
}

- (void)onDownloadResourceTaskFinished:(id<OAObservableProtocol>)observer withKey:(id)key andValue:(id)value
{
    id<OADownloadTask> task = key;
    NSString *taskKey = task.key;
    float progress = task.progressCompleted;
    
    // Skip all downloads that are not resources
    if (![taskKey hasPrefix:@"resource:"])
        return;
    
    taskKey = [taskKey stringByReplacingOccurrencesOfString:@"resource:" withString:@""];


    // Skip downloadings from another screens
    OAResourceItem *resourceItem = _resourceItems[taskKey];
    if (resourceItem)
    {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            [self setCellProgress:taskKey progress:progress status:EOAItemStatusFinishedType];
            
            // Start next downloading if needed
            if ([OsmAndApp.instance.downloadsManager.keysOfDownloadTasks count] > 0)
            {
                id<OADownloadTask> nextTask = [OsmAndApp.instance.downloadsManager firstDownloadTasksWithKey:OsmAndApp.instance.downloadsManager.keysOfDownloadTasks[0]];
                [nextTask resume];
            }
        });
    }
}

- (void)onLocalResourcesChanged:(id<OAObservableProtocol>)observer withKey:(id)key andValue:(id)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (!_hostViewController.isViewLoaded || _hostViewController.view.window == nil)
            return;

        [[OARootViewController instance].mapPanel.mapViewController updatePoiLayer];
        [OAManageResourcesViewController prepareData];
        if (_delegate && [_delegate respondsToSelector:@selector(onDownldedResourceInstalled)])
            [_delegate onDownldedResourceInstalled];
    });
}

@end
