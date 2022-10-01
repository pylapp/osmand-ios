//
//  OAWeatherForecastDetailsViewController.mm
//  OsmAnd
//
//  Created by Skalii on 05.08.2022.
//  Copyright (c) 2022 OsmAnd. All rights reserved.
//

#import "OAWeatherForecastDetailsViewController.h"
#import "OAWeatherCacheSettingsViewController.h"
#import "OAWeatherFrequencySettingsViewController.h"
#import "OATableViewCellSimple.h"
#import "OATableViewCellRightIcon.h"
#import "OATableViewCellValue.h"
#import "OATableViewCellSwitch.h"
#import "MBProgressHUD.h"
#import "OATableViewCustomHeaderView.h"
#import "OAResourcesUIHelper.h"
#import "OAWeatherHelper.h"
#import "OASizes.h"
#import "OAColors.h"
#import "Localization.h"

@interface OAWeatherForecastDetailsViewController  () <UITableViewDelegate, UITableViewDataSource, OAWeatherCacheSettingsDelegate, OAWeatherFrequencySettingsDelegate>

@end

@implementation OAWeatherForecastDetailsViewController
{
    OAWeatherHelper *_weatherHelper;
    OAWorldRegion *_region;
    NSMutableArray<NSMutableArray<NSMutableDictionary *> *> *_data;
    NSMutableDictionary<NSNumber *, NSString *> *_headers;
    NSMutableDictionary<NSNumber *, NSString *> *_footers;
    NSInteger _accuracySection;

    MBProgressHUD *_progressHUD;
    NSIndexPath *_sizeIndexPath;
    NSIndexPath *_updateNowIndexPath;

    OAAutoObserverProxy *_weatherSizeCalculatedObserver;
    OAAutoObserverProxy *_weatherForecastDownloadingObserver;
}

- (instancetype)initWithRegion:(OAWorldRegion *)region
{
    self = [super init];
    if (self)
    {
        _region = region;
        [self commonInit];
    }
    return self;
}

- (void)commonInit
{
    _weatherHelper = [OAWeatherHelper sharedInstance];
    _weatherSizeCalculatedObserver =
            [[OAAutoObserverProxy alloc] initWith:self
                                      withHandler:@selector(onWeatherSizeCalculated:withKey:andValue:)
                                       andObserve:[OAWeatherHelper sharedInstance].weatherSizeCalculatedObserver];
    _weatherForecastDownloadingObserver =
            [[OAAutoObserverProxy alloc] initWith:self
                                      withHandler:@selector(onWeatherForecastDownloading:withKey:andValue:)
                                       andObserve:[OAWeatherHelper sharedInstance].weatherForecastDownloadingObserver];
    _headers = [NSMutableDictionary dictionary];
    _footers = [NSMutableDictionary dictionary];
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.backButton.hidden = YES;
    self.backImageButton.hidden = NO;

    self.titleLabel.text = _region.name;

    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.sectionFooterHeight = 0.001;
    self.tableView.sectionHeaderHeight = kHeaderHeightDefault;
    [self.tableView registerClass:OATableViewCustomHeaderView.class forHeaderFooterViewReuseIdentifier:[OATableViewCustomHeaderView getCellIdentifier]];

    [self setupView];

    _progressHUD = [[MBProgressHUD alloc] initWithView:self.view];
    [self.view addSubview:_progressHUD];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_weatherHelper calculateCacheSize:_region onComplete:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];

    if (_weatherSizeCalculatedObserver)
    {
        [_weatherSizeCalculatedObserver detach];
        _weatherSizeCalculatedObserver = nil;
    }
    if (_weatherForecastDownloadingObserver)
    {
        [_weatherForecastDownloadingObserver detach];
        _weatherForecastDownloadingObserver = nil;
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (@available(iOS 13.0, *))
        return UIStatusBarStyleDarkContent;

    return UIStatusBarStyleDefault;
}

- (NSString *)getTableHeaderTitle
{
    return _region.name;
}

- (void)setTableHeaderView:(NSString *)label
{
    UIView *headerView = [OAUtilities setupTableHeaderViewWithText:label
                                                              font:[UIFont systemFontOfSize:34.0 weight:UIFontWeightBold]
                                                         textColor:UIColor.blackColor
                                                       lineSpacing:0.0
                                                           isTitle:YES];
    
    UIView *separator = [[UIView alloc] initWithFrame:CGRectMake(
        0.,
        headerView.layer.frame.size.height + 7.,
        DeviceScreenWidth,
        1.
    )];
    separator.backgroundColor = UIColorFromRGB(color_tint_gray);
    [headerView addSubview:separator];

    CGRect frame = headerView.frame;
    frame.size.height += 8.;
    headerView.frame = frame;
    
    self.tableView.tableHeaderView = headerView;
}

- (void)setupView
{
    NSMutableArray<NSMutableArray<NSMutableDictionary *> *> *data = [NSMutableArray array];

    NSMutableArray<NSMutableDictionary *> *infoCells = [NSMutableArray array];
    [data addObject:infoCells];
    _accuracySection = data.count - 1;
    _headers[@(_accuracySection)] = [OAWeatherHelper getAccuracyDescription:_region.regionId];

    NSMutableDictionary *updatedData = [NSMutableDictionary dictionary];
    updatedData[@"key"] = @"updated_cell";
    updatedData[@"type"] = [OATableViewCellValue getCellIdentifier];
    updatedData[@"title"] = OALocalizedString(@"shared_string_updated");
    updatedData[@"value"] = [OAWeatherHelper getUpdatesDateFormat:_region.regionId next:NO];
    updatedData[@"value_color"] = UIColor.blackColor;
    updatedData[@"selection_style"] = @(UITableViewCellSelectionStyleNone);
    [infoCells addObject:updatedData];

    NSMutableDictionary *nextUpdateData = [NSMutableDictionary dictionary];
    nextUpdateData[@"key"] = @"next_update_cell";
    nextUpdateData[@"type"] = [OATableViewCellValue getCellIdentifier];
    nextUpdateData[@"title"] = OALocalizedString(@"shared_string_next_update");
    nextUpdateData[@"value"] = [OAWeatherHelper getUpdatesDateFormat:_region.regionId next:YES];
    nextUpdateData[@"value_color"] = UIColor.blackColor;
    nextUpdateData[@"selection_style"] = @(UITableViewCellSelectionStyleNone);
    [infoCells addObject:nextUpdateData];

    NSMutableDictionary *updatesSizeData = [NSMutableDictionary dictionary];
    updatesSizeData[@"key"] = @"updates_size_cell";
    updatesSizeData[@"type"] = [OATableViewCellValue getCellIdentifier];
    updatesSizeData[@"title"] = OALocalizedString(@"shared_string_updates_size");
    updatesSizeData[@"value"] = [NSByteCountFormatter stringFromByteCount:[[OAWeatherHelper sharedInstance] getOfflineForecastSizeInfo:_region.regionId local:YES]
                                                                     countStyle:NSByteCountFormatterCountStyleFile];
    updatesSizeData[@"value_color"] = UIColorFromRGB(color_text_footer);
    updatesSizeData[@"selection_style"] = @(UITableViewCellSelectionStyleDefault);
    [infoCells addObject:updatesSizeData];
    _sizeIndexPath = [NSIndexPath indexPathForRow:infoCells.count - 1 inSection:data.count - 1];

    NSMutableDictionary *updateNowData = [NSMutableDictionary dictionary];
    updateNowData[@"key"] = @"update_now_cell";
    updateNowData[@"type"] = [OATableViewCellRightIcon getCellIdentifier];
    updateNowData[@"title"] = OALocalizedString(@"osmand_live_update_now");
    updateNowData[@"title_color"] = UIColorFromRGB(color_primary_purple);
    updateNowData[@"title_font"] = [UIFont systemFontOfSize:17. weight:UIFontWeightMedium];
    updateNowData[@"right_icon"] = @"ic_custom_download";
    updateNowData[@"right_icon_color"] = UIColorFromRGB(color_primary_purple);
    [infoCells addObject:updateNowData];
    _updateNowIndexPath = [NSIndexPath indexPathForRow:infoCells.count - 1 inSection:data.count - 1];

    NSMutableArray<NSMutableDictionary *> *updatesCells = [NSMutableArray array];
    [data addObject:updatesCells];
    _headers[@(data.count - 1)] = OALocalizedString(@"update_parameters");
    _footers[@(data.count - 1)] = OALocalizedString(@"weather_updates_automatically");

    NSMutableDictionary *updatesFrequencyData = [NSMutableDictionary dictionary];
    updatesFrequencyData[@"key"] = @"updates_frequency_cell";
    updatesFrequencyData[@"type"] = [OATableViewCellValue getCellIdentifier];
    updatesFrequencyData[@"title"] = OALocalizedString(@"shared_string_updates_frequency");
    updatesFrequencyData[@"value"] = [OAWeatherHelper getFrequencyFormat:[OAWeatherHelper getPreferenceFrequency:_region.regionId]];
    updatesFrequencyData[@"value_color"] = UIColorFromRGB(color_text_footer);
    updatesFrequencyData[@"selection_style"] = @(UITableViewCellSelectionStyleDefault);
    [updatesCells addObject:updatesFrequencyData];

    NSMutableDictionary *updateOnlyWiFiData = [NSMutableDictionary dictionary];
    updateOnlyWiFiData[@"key"] = @"update_only_wifi_cell";
    updateOnlyWiFiData[@"type"] = [OATableViewCellSwitch getCellIdentifier];
    updateOnlyWiFiData[@"title"] = OALocalizedString(@"update_only_over_wi_fi");
    [updatesCells addObject:updateOnlyWiFiData];

    NSMutableArray<NSMutableDictionary *> *removeCells = [NSMutableArray array];
    [data addObject:removeCells];

    NSMutableDictionary *removeForecastData = [NSMutableDictionary dictionary];
    removeForecastData[@"key"] = @"remove_forecast_cell";
    removeForecastData[@"type"] = [OATableViewCellSimple getCellIdentifier];
    removeForecastData[@"title"] = OALocalizedString(@"weather_remove_forecast");
    removeForecastData[@"title_color"] = UIColorFromRGB(color_primary_red);
    removeForecastData[@"title_alignment"] = @(NSTextAlignmentCenter);
    removeForecastData[@"title_font"] = [UIFont systemFontOfSize:17. weight:UIFontWeightMedium];
    [removeCells addObject:removeForecastData];

    _data = data;
}

- (void)onWeatherSizeCalculated:(id)sender withKey:(id)key andValue:(id)value
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (value != _region || !_sizeIndexPath)
            return;

        uint64_t sizeLocal = [_weatherHelper getOfflineForecastSizeInfo:_region.regionId local:YES];
        NSMutableDictionary *totalSizeData = _data[_sizeIndexPath.section][_sizeIndexPath.row];
        NSString *sizeString = [NSByteCountFormatter stringFromByteCount:sizeLocal
                                                              countStyle:NSByteCountFormatterCountStyleFile];
        totalSizeData[@"value"] = sizeString;
        [self.tableView reloadRowsAtIndexPaths:@[_sizeIndexPath] withRowAnimation:UITableViewRowAnimationNone];
    });
}

- (void)onWeatherForecastDownloading:(id)sender withKey:(id)key andValue:(id)value
{
    if (value != _region)
        return;

    if (_updateNowIndexPath && _sizeIndexPath)
    {
        BOOL statusSizeCalculating = ![[OAWeatherHelper sharedInstance] isOfflineForecastSizesInfoCalculated:_region.regionId];
        if ([OAWeatherHelper getPreferenceDownloadState:_region.regionId] == EOAWeatherForecastDownloadStateUndefined && !statusSizeCalculating)
            return;

        dispatch_async(dispatch_get_main_queue(), ^{
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:statusSizeCalculating ? _sizeIndexPath : _updateNowIndexPath];
            if (!cell.accessoryView)
            {
                [self.tableView reloadRowsAtIndexPaths:@[statusSizeCalculating ? _sizeIndexPath : _updateNowIndexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
                cell = [self.tableView cellForRowAtIndexPath:statusSizeCalculating ? _sizeIndexPath : _updateNowIndexPath];
            }

            FFCircularProgressView *progressView = (FFCircularProgressView *) cell.accessoryView;
            NSInteger progressDownloading = [_weatherHelper getOfflineForecastProgressInfo:_region.regionId];
            NSInteger progressDownloadDestination = [[OAWeatherHelper sharedInstance] getProgressDestination:_region.regionId];
            CGFloat progressCompleted = (CGFloat) progressDownloading / progressDownloadDestination;
            if (progressCompleted >= 0.001 && [OAWeatherHelper getPreferenceDownloadState:_region.regionId] == EOAWeatherForecastDownloadStateInProgress)
            {
                progressView.iconPath = nil;
                if (progressView.isSpinning)
                    [progressView stopSpinProgressBackgroundLayer];
                progressView.progress = progressCompleted - 0.001;
            }
            else if ([OAWeatherHelper getPreferenceDownloadState:_region.regionId] == EOAWeatherForecastDownloadStateFinished && !statusSizeCalculating)
            {
                progressView.iconPath = [OAResourcesUIHelper tickPath:progressView];
                progressView.progress = 0.;
                if (!progressView.isSpinning)
                    [progressView startSpinProgressBackgroundLayer];

                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1. * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self setupView];
                    [self.tableView reloadData];
                    if (self.delegate)
                        [self.delegate onUpdateForecast];
                });
            }
            else
            {
                progressView.iconPath = [UIBezierPath bezierPath];
                progressView.progress = 0.;
                if (!progressView.isSpinning)
                    [progressView startSpinProgressBackgroundLayer];
                [progressView setNeedsDisplay];
            }
        });
    }
}

- (BOOL)isEnabled:(NSString *)key
{
    if ([key isEqualToString:@"update_only_wifi_cell"])
        return [OAWeatherHelper getPreferenceWifi:_region.regionId];

    return NO;
}

- (NSMutableDictionary *)getItem:(NSIndexPath *)indexPath
{
    return _data[indexPath.section][indexPath.row];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _data[section].count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"type"] isEqualToString:[OATableViewCellSimple getCellIdentifier]])
    {
        OATableViewCellSimple *cell = [tableView dequeueReusableCellWithIdentifier:[OATableViewCellSimple getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATableViewCellSimple getCellIdentifier] owner:self options:nil];
            cell = (OATableViewCellSimple *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];
            cell.titleLabel.textColor = [item.allKeys containsObject:@"title_color"] ? item[@"title_color"] : UIColor.blackColor;
            cell.titleLabel.textAlignment = [item.allKeys containsObject:@"title_alignment"] ? (NSTextAlignment) [item[@"title_alignment"] integerValue] : NSTextAlignmentNatural;
            cell.titleLabel.font = [item.allKeys containsObject:@"title_font"] ? item[@"title_font"] : [UIFont systemFontOfSize:17.];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:[OATableViewCellRightIcon getCellIdentifier]])
    {
        OATableViewCellRightIcon *cell = [tableView dequeueReusableCellWithIdentifier:[OATableViewCellRightIcon getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATableViewCellRightIcon getCellIdentifier] owner:self options:nil];
            cell = (OATableViewCellRightIcon *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];
            cell.titleLabel.textColor = [item.allKeys containsObject:@"title_color"] ? item[@"title_color"] : UIColor.blackColor;
            cell.titleLabel.font = [item.allKeys containsObject:@"title_font"] ? item[@"title_font"] : [UIFont systemFontOfSize:17.];

            BOOL hasRightIcon = [item.allKeys containsObject:@"right_icon"];
            if (([item[@"key"] isEqualToString:@"update_now_cell"] && [OAWeatherHelper getPreferenceDownloadState:_region.regionId] == EOAWeatherForecastDownloadStateInProgress))
            {
                FFCircularProgressView *progressView = [[FFCircularProgressView alloc] initWithFrame:CGRectMake(0., 0., 25., 25.)];
                progressView.iconView = [[UIView alloc] init];
                progressView.tintColor = UIColorFromRGB(color_primary_purple);

                cell.accessoryView = progressView;
                cell.rightIconView.image = nil;
                hasRightIcon = NO;
            }
            else
            {
                cell.accessoryView = nil;
                cell.rightIconView.image = hasRightIcon ? [UIImage templateImageNamed:item[@"right_icon"]] : nil;
                cell.rightIconView.tintColor = item[@"right_icon_color"];
            }
            [cell rightIconVisibility:hasRightIcon];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:[OATableViewCellValue getCellIdentifier]])
    {
        OATableViewCellValue *cell = [tableView dequeueReusableCellWithIdentifier:[OATableViewCellValue getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATableViewCellValue getCellIdentifier] owner:self options:nil];
            cell = (OATableViewCellValue *) nib[0];
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.selectionStyle = (UITableViewCellSelectionStyle) [item[@"selection_style"] integerValue];
            cell.accessoryType = cell.selectionStyle == UITableViewCellSelectionStyleDefault ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
            cell.titleLabel.text = item[@"title"];
            cell.valueLabel.text = item[@"value"];
            cell.valueLabel.textColor = item[@"value_color"];
        }
        return cell;
    }
    else if ([item[@"type"] isEqualToString:[OATableViewCellSwitch getCellIdentifier]])
    {
        OATableViewCellSwitch *cell = [tableView dequeueReusableCellWithIdentifier:[OATableViewCellSwitch getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OATableViewCellSwitch getCellIdentifier] owner:self options:nil];
            cell = (OATableViewCellSwitch *) nib[0];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell leftIconVisibility:NO];
            [cell descriptionVisibility:NO];
        }
        if (cell)
        {
            cell.titleLabel.text = item[@"title"];

            cell.switchView.on = [self isEnabled:item[@"key"]];
            cell.switchView.tag = indexPath.section << 10 | indexPath.row;
            [cell.switchView removeTarget:self action:NULL forControlEvents:UIControlEventValueChanged];
            [cell.switchView addTarget:self action:@selector(onSwitchPressed:) forControlEvents:UIControlEventValueChanged];
        }
        return cell;
    }

    return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return _headers[@(section)];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return _footers[@(section)];
}

#pragma mark - UITableViewDelegate

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    OATableViewCustomHeaderView *customHeader = [tableView dequeueReusableHeaderFooterViewWithIdentifier:[OATableViewCustomHeaderView getCellIdentifier]];
    if (section == _accuracySection)
    {
        customHeader.label.text = _headers[@(section)];
        customHeader.label.font = [UIFont systemFontOfSize:13];
        [customHeader setYOffset:20.];
        return customHeader;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    NSString *header = _headers[@(section)];
    if (header)
    {
        if (section == _accuracySection)
        {
            return [OATableViewCustomHeaderView getHeight:header
                                                    width:tableView.bounds.size.width
                                                  xOffset:kPaddingOnSideOfContent
                                                  yOffset:20.
                                                     font:[UIFont systemFontOfSize:13.]] + 15.;
        }
        else
        {
            UIFont *font = [UIFont systemFontOfSize:13.];
            CGFloat headerHeight = [OAUtilities calculateTextBounds:header
                                                            width:tableView.frame.size.width - (kPaddingOnSideOfContent + [OAUtilities getLeftMargin]) * 2
                                                             font:font].height + kPaddingOnSideOfHeaderWithText;
            return headerHeight;
        }
    }

    return kHeaderHeightDefault;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    NSString *footer = _footers[@(section)];
    if (footer)
    {
        UIFont *font = [UIFont systemFontOfSize:13.];
        CGFloat footerHeight = [OAUtilities calculateTextBounds:[_footers objectForKey:@(section)]
                                                        width:tableView.frame.size.width - (kPaddingOnSideOfContent + [OAUtilities getLeftMargin]) * 2
                                                        font:font].height + kPaddingOnSideOfFooterWithText;

        return footerHeight;
    }

    return 0.001;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSDictionary *item = [self getItem:indexPath];
    if ([item[@"key"] isEqualToString:@"updates_size_cell"])
    {
        OAWeatherCacheSettingsViewController *controller = [[OAWeatherCacheSettingsViewController alloc] initWithRegion:_region];
        controller.cacheDelegate = self;
        [self presentViewController:controller animated:YES completion:nil];
    }
    else if ([item[@"key"] isEqualToString:@"update_now_cell"])
    {
        if ([OAWeatherHelper getPreferenceDownloadState:_region.regionId] == EOAWeatherForecastDownloadStateInProgress)
        {
            [_weatherHelper prepareToStopDownloading:_region.regionId];
            [_weatherHelper calculateCacheSize:_region onComplete:nil];
        }
        else
        {
            [_weatherHelper downloadForecastByRegion:_region];
        }
    }
    else if ([item[@"key"] isEqualToString:@"remove_forecast_cell"])
    {
        UIAlertController *alert =
                [UIAlertController alertControllerWithTitle:OALocalizedString(@"weather_remove_forecast")
                                                    message:[NSString stringWithFormat:OALocalizedString(@"weather_remove_forecast_description"), _region.name]
                                             preferredStyle:UIAlertControllerStyleAlert];

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_cancel")
                                                               style:UIAlertActionStyleDefault
                                                             handler:nil];

        UIAlertAction *clearCacheAction = [UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_remove")
                                                                   style:UIAlertActionStyleDefault
                                                                 handler:^(UIAlertAction * _Nonnull action)
                                                                 {
                                                                     [_progressHUD showAnimated:YES whileExecutingBlock:^{
                                                                         [_weatherHelper prepareToStopDownloading:_region.regionId];
                                                                         [_weatherHelper removeLocalForecast:_region.regionId refreshMap:YES];
                                                                     } completionBlock:^{
                                                                         [self dismissViewController];
                                                                         if (self.delegate)
                                                                             [self.delegate onRemoveForecast];
                                                                     }];
                                                                 }
        ];

        [alert addAction:cancelAction];
        [alert addAction:clearCacheAction];

        alert.preferredAction = clearCacheAction;

        [self presentViewController:alert animated:YES completion:nil];
    }
    else if ([item[@"key"] isEqualToString:@"updates_frequency_cell"])
    {
        OAWeatherFrequencySettingsViewController *frequencySettingsViewController =
                [[OAWeatherFrequencySettingsViewController alloc] initWithRegion:_region];
        frequencySettingsViewController.frequencyDelegate = self;
        [self presentViewController:frequencySettingsViewController animated:YES completion:nil];
    }

    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - Selectors

- (void)onSwitchPressed:(id)sender
{
    UISwitch *switchView = (UISwitch *) sender;
    if (switchView)
    {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:switchView.tag & 0x3FF inSection:switchView.tag >> 10];
        NSDictionary *item = [self getItem:indexPath];

        if ([item[@"key"] isEqualToString:@"update_only_wifi_cell"])
            [OAWeatherHelper setPreferenceWifi:_region.regionId value:switchView.isOn];
    }
}

#pragma mark - OAWeatherCacheSettingsDelegate

- (void)onCacheClear
{
    [_weatherHelper calculateCacheSize:_region onComplete:nil];
}

#pragma mark - OAWeatherFrequencySettingsDelegate

- (void)onFrequencySelected
{
    for (NSInteger i = 0; i < _data.count; i++)
    {
        NSArray<NSMutableDictionary *> *cells = _data[i];
        for (NSInteger j = 0; j < cells.count; j++)
        {
            NSMutableDictionary *cell = cells[j];
            if ([cell[@"key"] isEqualToString:@"next_update_cell"])
            {
                cell[@"value"] = [OAWeatherHelper getUpdatesDateFormat:_region.regionId next:YES];
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:j inSection:i]]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
            else if ([cell[@"key"] isEqualToString:@"updates_frequency_cell"])
            {
                cell[@"value"] = [OAWeatherHelper getFrequencyFormat:[OAWeatherHelper getPreferenceFrequency:_region.regionId]];
                [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:j inSection:i]]
                                      withRowAnimation:UITableViewRowAnimationAutomatic];
            }
        }
    }
}

@end