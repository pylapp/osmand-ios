//
//  OAOsmUploadGPXViewConroller.m
//  OsmAnd Maps
//
//  Created by nnngrach on 31.01.2023.
//  Copyright © 2023 OsmAnd. All rights reserved.
//

#import "OAOsmUploadGPXViewConroller.h"
#import "OAAppSettings.h"
#import "Localization.h"
#import "OAColors.h"
#import "OASizes.h"
#import "OASettingsTableViewCell.h"
#import "OAInputTableViewCell.h"
#import "OATableDataModel.h"
#import "OATableSectionData.h"
#import "OATableRowData.h"
#import "OAOsmAccountSettingsViewController.h"
#import "OAOsmLoginMainViewController.h"
#import "OAMappersViewController.h"
#import "OAUploadGPXFilesTask.h"
#import "OAPlugin.h"
#import "OAOsmEditingPlugin.h"
#import "OAProgressBarCell.h"
#import "OAValueTableViewCell.h"
#import "OATitleIconProgressbarCell.h"
#import "OABackupListeners.h"

#define kDefaultTag @"osmand"
#define kDescriptionTextFieldTag 0
#define kTagsTextFieldsTag 1

@interface OAOsmUploadGPXViewConroller () <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate, OAOsmUploadGPXVisibilityDelegate, OAAccountSettingDelegate, OAOnUploadFileListener>

@property (weak, nonatomic) IBOutlet UIView *buttonsContainerView;
@property (weak, nonatomic) IBOutlet UIButton *bottomButton;
@property (weak, nonatomic) IBOutlet UILabel *headerTitleLabel;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *bottomButtonNoTopButtonConstraint;

@property (strong, nonatomic) IBOutlet NSLayoutConstraint *buttonsContainerWithOneButtonConstraint;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *buttonsContainerWithTwoButtonsConstraint;

@end

@implementation OAOsmUploadGPXViewConroller
{
    OAAppSettings *_settings;
    NSArray<OAGPX *> *_uploadingGpxItems;
    OATableDataModel *_data;
    NSString *_descriptionText;
    NSString *_tagsText;
    EOAOsmUploadGPXVisibility _selectedVisibility;
    BOOL _isLogged;
    BOOL _isUploading;
    OAProgressBarCell *_progressBarCell;
    OAValueTableViewCell *_progressValueCell;
    OAUploadGPXFilesTask *_uploadTask;
    NSMutableDictionary<NSString *, NSNumber *> *_filesUploadingProgress;
}

- (instancetype)initWithGPXItems:(NSArray<OAGPX *> *)uploadingGpxItems
{
    self = [super initWithNibName:@"OAOsmUploadGPXViewConroller" bundle:nil];
    if (self)
    {
        _uploadingGpxItems = uploadingGpxItems;
        _isUploading = NO;
        _settings = [OAAppSettings sharedManager];
    }
    return self;
}

- (void)applyLocalization
{
    [super applyLocalization];
    self.headerTitleLabel.text = OALocalizedString(@"upload_to_openstreetmap");
    [self.backButton setTitle:OALocalizedString(@"shared_string_cancel") forState:UIControlStateNormal];
    [self.bottomButton setTitle:OALocalizedString(@"shared_string_upload") forState:UIControlStateNormal];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.estimatedRowHeight = kEstimatedRowHeight;
    self.tableView.allowsSelection = YES;
    
    self.backImageButton.hidden = YES;
    self.backButton.hidden = NO;
    self.separatorView.hidden = NO;
    
    [self.bottomButton setBackgroundColor:UIColorFromRGB(color_primary_purple)];
    [self.bottomButton setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
    
    _selectedVisibility = EOAOsmUploadGPXVisibilityPublic;
    _descriptionText = @"";
    _tagsText = kDefaultTag;
    _isLogged = [_settings.osmUserName get].length > 0 && [_settings.osmUserPassword get].length > 0;
    [self setupView];
    
    if (!_isLogged)
    {
        OAOsmAccountSettingsViewController *accountSettings = [[OAOsmAccountSettingsViewController alloc] init];
        accountSettings.accountDelegate = self;
        [self presentViewController:accountSettings animated:YES completion:nil];
    }
}

- (void)setupView
{
    _data = [[OATableDataModel alloc] init];
    
    if (_isUploading)
    {
        _progressBarCell = [self getProgressBarCell];
        _progressValueCell = [self getProgressValueCell];
        
        OATableSectionData *uploadingSection = [OATableSectionData sectionData];
        uploadingSection.headerText = @" ";
        OATableRowData *progressValueCell = [OATableRowData rowData];
        [progressValueCell setCellType:[OAValueTableViewCell getCellIdentifier]];
        [uploadingSection addRow:progressValueCell];
        OATableRowData *progressBarCell = [OATableRowData rowData];
        [progressBarCell setCellType:[OAProgressBarCell getCellIdentifier]];
        [uploadingSection addRow:progressBarCell];
        [_data addSection:uploadingSection];
    }
    else
    {
        OATableSectionData *descriptionSection = [OATableSectionData sectionData];
        descriptionSection.headerText = OALocalizedString(@"shared_string_description");
        descriptionSection.footerText = OALocalizedString(@"osm_upload_gpx_description_footer");
        OATableRowData *descriptionTextInputCell = [OATableRowData rowData];
        [descriptionTextInputCell setCellType:[OAInputTableViewCell getCellIdentifier]];
        [descriptionTextInputCell setTitle:_descriptionText];
        [descriptionTextInputCell setObj:@(kDescriptionTextFieldTag) forKey:@"tag"];
        [descriptionSection addRow:descriptionTextInputCell];
        [_data addSection:descriptionSection];
        
        OATableSectionData *tagsSection = [OATableSectionData sectionData];
        tagsSection.headerText = OALocalizedString(@"gpx_tags_txt");
        tagsSection.footerText = OALocalizedString(@"osm_upload_gpx_tags_footer");
        OATableRowData *tagsTextInputCell = [OATableRowData rowData];
        [tagsTextInputCell setCellType:[OAInputTableViewCell getCellIdentifier]];
        [tagsTextInputCell setTitle:_tagsText];
        [tagsTextInputCell setObj:@(kTagsTextFieldsTag) forKey:@"tag"];
        [tagsSection addRow:tagsTextInputCell];
        [_data addSection:tagsSection];
        
        OATableSectionData *visibilitySection = [OATableSectionData sectionData];
        OATableRowData *visibilityCell = [OATableRowData rowData];
        [visibilityCell setCellType:[OASettingsTableViewCell getCellIdentifier]];
        [visibilityCell setTitle:OALocalizedString(@"visibility")];
        [visibilityCell setDescr:[OAOsmUploadGPXVisibilityViewConroller localizedNameForVisibilityType:_selectedVisibility]];
        [visibilityCell setObj: (^void(){ [self onVisibilityButtonClicked]; }) forKey:@"actionBlock"];
        [visibilitySection addRow:visibilityCell];
        [_data addSection:visibilitySection];
        
        OATableSectionData *accountSection = [OATableSectionData sectionData];
        accountSection.headerText = OALocalizedString(@"login_account");
        OATableRowData *accountCell = [OATableRowData rowData];
        [accountCell setCellType:[OASimpleTableViewCell getCellIdentifier]];
        [accountCell setTitle: _isLogged ? [_settings.osmUserName get] : OALocalizedString(@"login_open_street_map_org")];
        [accountCell setIconName:@"ic_custom_user_profile"];
        [accountCell setObj:(_isLogged ? UIColor.blackColor : UIColorFromRGB(color_primary_purple)) forKey:@"title_color"];
        [accountCell setObj:([UIFont systemFontOfSize:17. weight:_isLogged ? UIFontWeightRegular : UIFontWeightMedium]) forKey:@"title_font"];
        [accountCell setObj:(_isLogged ? @(UITableViewCellAccessoryDisclosureIndicator) : @(UITableViewCellAccessoryNone)) forKey:@"accessory_type"];
        [accountCell setObj: (^void(){ [self onAccountButtonClicked]; }) forKey:@"actionBlock"];
        [accountSection addRow:accountCell];
        [_data addSection:accountSection];
    }
}

- (OAValueTableViewCell *) getProgressValueCell
{
    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAValueTableViewCell getCellIdentifier] owner:self options:nil];
    OAValueTableViewCell *resultCell = (OAValueTableViewCell *)[nib objectAtIndex:0];
    
    resultCell.titleLabel.text = OALocalizedString(@"local_openstreetmap_uploading");
    resultCell.descriptionLabel.hidden = YES;
    resultCell.valueLabel.text = @"0%";
    resultCell.leftIconView.hidden = YES;
    
    return resultCell;
}

- (OAProgressBarCell *) getProgressBarCell
{
    NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAProgressBarCell getCellIdentifier] owner:self options:nil];
    
    OAProgressBarCell *resultCell = (OAProgressBarCell *)[nib objectAtIndex:0];
    [resultCell.progressBar setProgress:0.0 animated:NO];
    [resultCell.progressBar setProgressTintColor:UIColorFromRGB(color_primary_purple)];
    //    resultCell.backgroundColor = [UIColor clearColor];
    resultCell.selectionStyle = UITableViewCellSelectionStyleNone;
    return resultCell;
}

- (void) setProgress:(float)progress fileName:(NSString *)fileName
{
    _filesUploadingProgress[fileName] = [NSNumber numberWithFloat:progress];
    
    float progressSum = 0;
    for (NSNumber *value in _filesUploadingProgress.allValues)
        progressSum += value.floatValue;
    
    progressSum = progressSum / _uploadingGpxItems.count;
    
    _progressValueCell.valueLabel.text = [NSString stringWithFormat:@"%d%%", (int)progressSum];
    [_progressBarCell.progressBar setProgress:progressSum / 100 animated:YES];
    
    if (progressSum == 100)
        [self setToUploadingMode:YES];
}

- (void) setToUploadingMode:(BOOL)finished
{
    [self.bottomButton setTitle:OALocalizedString(@"shared_string_done") forState:UIControlStateNormal];
    [self.bottomButton setBackgroundColor:UIColorFromRGB(color_route_button_inactive)];
    if (finished)
    {
        [self.bottomButton setTitleColor:UIColorFromRGB(color_primary_purple ) forState:UIControlStateNormal];
        self.bottomButton.enabled = YES;
    }
    else
    {
        [self.bottomButton setTitleColor:UIColorFromRGB(color_text_footer ) forState:UIControlStateNormal];
        self.bottomButton.enabled = NO;
    }
}

- (void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
    [self setupView];
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
    if (@available(iOS 13.0, *))
        return UIStatusBarStyleDarkContent;
    return UIStatusBarStyleDefault;
}


#pragma mark - Actions

- (IBAction)backButtonClicked:(id)sender
{
    if (_isUploading)
    {
        if (_uploadTask)
            [_uploadTask setInterrupted:YES];
        [super backButtonClicked:sender];
    }
    else
    {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:OALocalizedString(@"exit_without_saving") message:OALocalizedString(@"unsaved_changes_will_be_lost") preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_cancel") style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:OALocalizedString(@"shared_string_exit") style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [super backButtonClicked:sender];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void) onVisibilityButtonClicked
{
    OAOsmUploadGPXVisibilityViewConroller *vc = [[OAOsmUploadGPXVisibilityViewConroller alloc] initWithVisibility:_selectedVisibility];
    vc.visibilityDelegate = self;
    [self presentViewController:vc animated:YES completion:nil];
}

- (void) onAccountButtonClicked
{
    if (_isLogged)
    {
        OAOsmAccountSettingsViewController *accountSettings = [[OAOsmAccountSettingsViewController alloc] init];
        accountSettings.accountDelegate = self;
        [self presentViewController:accountSettings animated:YES completion:nil];
    }
    else
    {
        OAOsmLoginMainViewController *loginMainViewController = [[OAOsmLoginMainViewController alloc] init];
        loginMainViewController.delegate = self;
        [self presentViewController:loginMainViewController animated:YES completion:nil];
    }
}

- (IBAction)onUploadButtonPressed:(id)sender
{
    if (_isUploading)
    {
        [super backButtonClicked:sender];
    }
    else
    {
        if (_isLogged)
        {
            _isUploading = YES;
            [self setToUploadingMode:NO];
            [self setupView];
            [self.tableView reloadData];
            
            NSString *visibility = [OAOsmUploadGPXVisibilityViewConroller toUrlParam:_selectedVisibility];
            if (!visibility)
                visibility = [OAOsmUploadGPXVisibilityViewConroller toUrlParam:EOAOsmUploadGPXVisibilityPrivate];
            
            _filesUploadingProgress = [NSMutableDictionary dictionary];
            
            OAOsmEditingPlugin *plugin = (OAOsmEditingPlugin *)[OAPlugin getPlugin:OAOsmEditingPlugin.class];
            _uploadTask = [[OAUploadGPXFilesTask alloc] initWithPlugin:plugin uploadingGpxItems:_uploadingGpxItems tags:_tagsText visibility:visibility description:_descriptionText listener:self];
            [_uploadTask uploadTracks];
        }
    }
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return _data.sectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_data rowCount:section];
}

- (NSString *) tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [_data sectionDataForIndex:section].headerText;
}

- (NSString *) tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    return [_data sectionDataForIndex:section].footerText;
}

- (void)tableView:(UITableView *)tableView willDisplayHeaderView:(UIView *)view forSection:(NSInteger)section
{
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    [header.textLabel setTextColor:UIColorFromRGB(color_text_footer)];
}

- (void)tableView:(UITableView *)tableView willDisplayFooterView:(UIView *)view forSection:(NSInteger)section
{
    UITableViewHeaderFooterView *footer = (UITableViewHeaderFooterView *)view;
    [footer.textLabel setTextColor:UIColorFromRGB(color_text_footer)];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OATableRowData *item = [_data itemForIndexPath:indexPath];
    NSString *cellType = item.cellType;
    
    if ([cellType isEqualToString:[OAInputTableViewCell getCellIdentifier]])
    {
        OAInputTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OAInputTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OAInputTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OAInputTableViewCell *) nib[0];
            [cell leftIconVisibility:NO];
            [cell titleVisibility:NO];
            [cell clearButtonVisibility:NO];
            [cell.inputField removeTarget:self action:NULL forControlEvents:UIControlEventEditingChanged];
            [cell.inputField addTarget:self action:@selector(textViewDidChange:) forControlEvents:UIControlEventEditingChanged];
            cell.inputField.autocapitalizationType = UITextAutocapitalizationTypeNone;
            cell.inputField.autocorrectionType = UITextAutocorrectionTypeNo;
            cell.inputField.spellCheckingType = UITextSpellCheckingTypeNo;
            cell.inputField.textAlignment = NSTextAlignmentNatural;
        }
        if (cell)
        {
            cell.inputField.text = item.title;
            cell.inputField.delegate = self;
            cell.inputField.tag = [item integerForKey:@"tag"];
        }
        return cell;
    }
    else if ([cellType isEqualToString:[OASettingsTableViewCell getCellIdentifier]])
    {
        OASettingsTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:[OASettingsTableViewCell getCellIdentifier]];
        if (cell == nil)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASettingsTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OASettingsTableViewCell *)[nib objectAtIndex:0];
            cell.descriptionView.font = [UIFont systemFontOfSize:17.0];
            cell.descriptionView.numberOfLines = 1;
            cell.iconView.image = [UIImage templateImageNamed:@"ic_custom_arrow_right"].imageFlippedForRightToLeftLayoutDirection;
            cell.iconView.tintColor = UIColorFromRGB(color_tint_gray);
        }
        if (cell)
        {
            cell.textView.text = item.title;
            cell.descriptionView.text = item.descr;
        }
        return cell;
    }
    else if ([cellType isEqualToString:OASimpleTableViewCell.getCellIdentifier])
    {
        OASimpleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[OASimpleTableViewCell getCellIdentifier]];
        if (!cell)
        {
            NSArray *nib = [[NSBundle mainBundle] loadNibNamed:[OASimpleTableViewCell getCellIdentifier] owner:self options:nil];
            cell = (OASimpleTableViewCell *) nib[0];
        }
        if (cell)
        {
            NSString *title = item.title;
            [cell titleVisibility:title != nil];
            cell.titleLabel.text = title;
            cell.titleLabel.textColor = [item objForKey:@"title_color"];
            cell.titleLabel.font = [item objForKey:@"title_font"];
            cell.leftIconView.image = [UIImage templateImageNamed:item.iconName];
            cell.leftIconView.tintColor = UIColorFromRGB(color_primary_purple);
            [cell leftIconVisibility:YES];
            [cell descriptionVisibility:NO];
            cell.accessoryType = (UITableViewCellAccessoryType) [item integerForKey:@"accessory_type"];
        }
        return cell;
    }
    else if ([cellType isEqualToString:[OAProgressBarCell getCellIdentifier]])
    {
        return _progressBarCell;
    }
    else if ([cellType isEqualToString:[OAValueTableViewCell getCellIdentifier]])
    {
        return _progressValueCell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OATableRowData *item = [_data itemForIndexPath:indexPath];
    NSString *cellType = item.cellType;
    if ([cellType isEqualToString:[OAProgressBarCell getCellIdentifier]])
        return 22;
    return UITableViewAutomaticDimension;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return _isUploading ? 35 : UITableViewAutomaticDimension;
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    OATableRowData *item = [_data itemForIndexPath:indexPath];
    void (^actionBlock)() = [item objForKey:@"actionBlock"];
    if (actionBlock)
        actionBlock();
}

#pragma mark - UITextFieldDelegate

- (BOOL) textFieldShouldReturn:(UITextField *)sender
{
    [sender resignFirstResponder];
    return YES;
}

- (void) textViewDidChange:(UITextView *)textView
{
    if (textView.tag == kDescriptionTextFieldTag)
    {
        _descriptionText = textView.text;
    }
    else if (textView.tag == kTagsTextFieldsTag)
    {
        _tagsText = textView.text;
    }
}

#pragma mark - Keyboard Notifications

- (void) keyboardWillShow:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    NSValue *keyboardBoundsValue = userInfo[UIKeyboardFrameEndUserInfoKey];
    CGFloat keyboardHeight = [keyboardBoundsValue CGRectValue].size.height;
    
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIEdgeInsets insets = [[self tableView] contentInset];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        [[self tableView] setContentInset:UIEdgeInsetsMake(insets.top, insets.left, keyboardHeight, insets.right)];
        [[self view] layoutIfNeeded];
    } completion:nil];
}

- (void) keyboardWillHide:(NSNotification *)notification;
{
    NSDictionary *userInfo = [notification userInfo];
    CGFloat duration = [userInfo[UIKeyboardAnimationDurationUserInfoKey] floatValue];
    NSInteger animationCurve = [userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    UIEdgeInsets insets = [[self tableView] contentInset];
    [UIView animateWithDuration:duration delay:0. options:animationCurve animations:^{
        [[self tableView] setContentInset:UIEdgeInsetsMake(insets.top, insets.left, 0., insets.right)];
        [[self view] layoutIfNeeded];
    } completion:nil];
}

#pragma mark - OAOsmUploadGPXVisibilityDelegate

- (void) onVisibilityChanged:(EOAOsmUploadGPXVisibility)visibility
{
    _selectedVisibility = visibility;
    [self setupView];
    [self.tableView reloadData];
}

#pragma mark - OAAccontSettingDelegate

- (void)onAccountInformationUpdated
{
    _isLogged = [_settings.osmUserName get].length > 0 && [_settings.osmUserPassword get].length > 0;
    [self setupView];
    [self.tableView reloadData];
}

- (void)onAccountInformationUpdatedFromBenefits
{
    [self onAccountInformationUpdated];
    if (_isLogged)
    {
        OAMappersViewController *benefitsViewController = [[OAMappersViewController alloc] init];
        [self presentViewController:benefitsViewController animated:YES completion:nil];
    }
}

#pragma mark - OAOnUploadFileListener

- (void)onFileUploadProgress:(NSString *)type fileName:(NSString *)fileName progress:(NSInteger)progress deltaWork:(NSInteger)deltaWork {
   
    NSLog(@"!onFileUploadProgress progress: %ld  deltaWork: %ld", (long)progress, (long)deltaWork);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setProgress: progress fileName:fileName];
    });
}

- (void)onFileUploadDone:(NSString *)type fileName:(NSString *)fileName uploadTime:(long)uploadTime error:(NSString *)error {
    
    NSLog(@"!onFileUploadDone");
    
    //TODO: Add error handling
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setProgress: 100 fileName:fileName];
    });
}

@end
