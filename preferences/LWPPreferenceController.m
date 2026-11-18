#import "LWPPreferenceController.h"
#import <spawn.h>
#import <AudioToolbox/AudioToolbox.h>

#if __has_include(<rootless.h>)
#import <rootless.h>
#else
#define ROOT_PATH(path) path
#define ROOT_PATH_NS(path) path
#endif

@interface PSTableCell ()
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier;
@end

#pragma mark - Custom Cells

@implementation CSPImageCell {
    UIImageView *_headerImageView;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        _headerImageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.width, 180)];
        _headerImageView.contentMode = UIViewContentModeScaleAspectFit;
        _headerImageView.clipsToBounds = YES;
        _headerImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;

        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        UIImage *img = nil;
        NSString *bundlePath = [bundle pathForResource:@"Asteroid" ofType:@"png"];
        if (bundlePath) {
            img = [UIImage imageWithContentsOfFile:bundlePath];
        }
        if (!img) {
            img = [UIImage imageWithContentsOfFile:ROOT_PATH_NS(@"/Library/PreferenceBundles/Asteroid.bundle/Asteroid.png")];
        }
        if (!img) {
            img = [UIImage imageWithContentsOfFile:@"/var/jb/Library/PreferenceBundles/Asteroid.bundle/Asteroid.png"];
        }
        if (!img) {
            img = [UIImage imageNamed:@"Asteroid" inBundle:bundle compatibleWithTraitCollection:nil];
        }
        _headerImageView.image = img;
        [self.contentView addSubview:_headerImageView];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _headerImageView.frame = self.contentView.bounds;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width {
    return 180.0;
}

- (CGFloat)preferredHeightForWidth:(CGFloat)width inTableView:(id)tableView {
    return 180.0;
}
@end

@implementation CSPVersionCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.textLabel.text = @"Asteroid";
        self.textLabel.textColor = [UIColor labelColor];
        self.detailTextLabel.text = @"Version 4.0.0 (Rootless)";
        self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}
@end

@implementation CSPLinkCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = [specifier propertyForKey:@"label"] ?: specifier.name;
    self.textLabel.textColor = [UIColor labelColor];
    self.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightRegular];

    NSString *sublabel = [specifier propertyForKey:@"sublabel"];
    self.detailTextLabel.text = sublabel ?: @"";
    self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    self.detailTextLabel.font = [UIFont systemFontOfSize:13];
    self.detailTextLabel.numberOfLines = 0;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
}
@end

@implementation CSPDeveloperCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    NSString *title = [specifier propertyForKey:@"devTitle"] ?: [specifier propertyForKey:@"devName"] ?: [specifier propertyForKey:@"label"] ?: @"Developer";
    NSString *subtitle = [specifier propertyForKey:@"devSubtitle"] ?: [specifier propertyForKey:@"sublabel"] ?: @"";

    self.textLabel.text = title;
    self.textLabel.textColor = [UIColor labelColor];
    self.textLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];

    self.detailTextLabel.text = subtitle;
    self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    self.detailTextLabel.font = [UIFont systemFontOfSize:13];
    self.detailTextLabel.numberOfLines = 0;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
}
@end

@implementation CSPCalloutCell
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = [specifier propertyForKey:@"label"] ?: specifier.name;
    self.textLabel.textColor = [UIColor labelColor];
    self.textLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];

    NSString *sublabel = [specifier propertyForKey:@"sublabel"];
    self.detailTextLabel.text = sublabel ?: @"";
    self.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    self.detailTextLabel.font = [UIFont systemFontOfSize:13];
    self.detailTextLabel.numberOfLines = 0;
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
}
@end

@interface CSColorDisplayCell () <UIColorPickerViewControllerDelegate>
@end

@implementation CSColorDisplayCell {
    UIView *_colorIndicator;
}
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier specifier:(PSSpecifier *)specifier {
    self = [super initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:reuseIdentifier specifier:specifier];
    if (self) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        _colorIndicator = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
        _colorIndicator.layer.cornerRadius = 13;
        _colorIndicator.layer.borderWidth = 1.5;
        _colorIndicator.layer.borderColor = [UIColor separatorColor].CGColor;
        _colorIndicator.clipsToBounds = YES;
        self.accessoryView = _colorIndicator;
        [self updateIndicatorColor];
    }
    return self;
}

- (void)refreshCellContentsWithSpecifier:(PSSpecifier *)specifier {
    [super refreshCellContentsWithSpecifier:specifier];
    self.textLabel.text = [specifier propertyForKey:@"label"] ?: specifier.name;
    self.textLabel.textColor = [UIColor labelColor];
    self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    [self updateIndicatorColor];
}

- (void)updateIndicatorColor {
    NSString *key = [self.specifier propertyForKey:@"key"];
    if (key) {
        _colorIndicator.backgroundColor = [prefs colorForKey:key];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    if (selected) {
        [self presentColorPicker];
    }
}

- (void)presentColorPicker {
    if (@available(iOS 14.0, *)) {
        UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
        picker.delegate = self;
        picker.supportsAlpha = YES;
        NSString *key = [self.specifier propertyForKey:@"key"];
        if (key) {
            picker.selectedColor = [prefs colorForKey:key];
        }
        UIViewController *rootVC = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *win in windowScene.windows) {
                    if (win.isKeyWindow) {
                        rootVC = win.rootViewController;
                        break;
                    }
                }
            }
            if (rootVC) break;
        }
        while (rootVC.presentedViewController) {
            rootVC = rootVC.presentedViewController;
        }
        if (rootVC) {
            [rootVC presentViewController:picker animated:YES completion:nil];
        }
    }
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController API_AVAILABLE(ios(14.0)) {
    UIColor *color = viewController.selectedColor;
    _colorIndicator.backgroundColor = color;

    CGFloat r, g, b, a;
    [color getRed:&r green:&g blue:&b alpha:&a];
    NSString *hexString = [NSString stringWithFormat:@"%02X%02X%02X", (int)(r * 255), (int)(g * 255), (int)(b * 255)];

    NSString *key = [self.specifier propertyForKey:@"key"];
    if (key) {
        [prefs setObject:hexString forKey:key];
        [prefs saveAndPostNotification];
    }
}
@end

@implementation CSPDatePickerCell
@end

#pragma mark - List Items Controller (Dark Mode Fix)

@implementation CSListItemsController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    if ([self respondsToSelector:@selector(table)]) {
        self.table.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        cell.tintColor = [UIColor systemBlueColor];
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector:@selector(textLabel)]) {
        cell.textLabel.textColor = [UIColor labelColor];
    }
    if ([cell respondsToSelector:@selector(titleLabel)]) {
        [(id)cell titleLabel].textColor = [UIColor labelColor];
    }
    if ([cell respondsToSelector:@selector(detailTextLabel)]) {
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.tintColor = [UIColor systemBlueColor];
}

@end

@implementation CSListFontsController

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (cell && cell.textLabel.text.length > 0) {
        UIFont *font = [UIFont fontWithName:cell.textLabel.text size:16];
        if (font) {
            cell.textLabel.font = font;
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell respondsToSelector:@selector(textLabel)]) {
        cell.textLabel.textColor = [UIColor labelColor];
    }
    if ([cell respondsToSelector:@selector(titleLabel)]) {
        [(id)cell titleLabel].textColor = [UIColor labelColor];
    }
    if ([cell respondsToSelector:@selector(detailTextLabel)]) {
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    }
    cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    cell.tintColor = [UIColor systemBlueColor];
}

@end

#pragma mark - ChangeLog & Backup Controllers

@implementation CSPChangeLogController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"ChangeLog";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    if ([self respondsToSelector:@selector(table)]) {
        self.table.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group4 = [PSSpecifier groupSpecifierWithName:@"Version 4.0.0 (Rootless iOS 15–16+)"];
        [specs addObject:group4];

        NSArray *items4 = @[
            @"- Modernized for iOS 15–16+ rootless jailbreaks (Dopamine, Palera1n).",
            @"- Added bundled official Apple CoreAnimation Mica weather animations (Tornado, Hurricane, Blizzard, Rain, Lightning, etc.).",
            @"- Fully removed legacy dependencies on libCSPreferences and RocketBootstrap.",
            @"- Added native iOS Dark Mode support across all settings pages and condition menus.",
            @"- Replaced deprecated SpringBoard hooks with safe CoverSheet introspection."
        ];
        for (NSString *item in items4) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:item target:self set:NULL get:NULL detail:Nil cell:PSStaticTextCell edit:Nil];
            [sp setProperty:[UIColor labelColor] forKey:@"textColor"];
            [specs addObject:sp];
        }

        PSSpecifier *group135 = [PSSpecifier groupSpecifierWithName:@"Version 1.3.5"];
        [specs addObject:group135];
        NSArray *items135 = @[
            @"- Redesigned lockscreen controller with new animations.",
            @"- Rewrote how lockscreen components are saved to file.",
            @"- Set the font size for dismiss button.",
            @"- Consolidated retrieving weather data (save battery).",
            @"- Pause animations when not visible."
        ];
        for (NSString *item in items135) {
            PSSpecifier *sp = [PSSpecifier preferenceSpecifierNamed:item target:self set:NULL get:NULL detail:Nil cell:PSStaticTextCell edit:Nil];
            [specs addObject:sp];
        }

        _specifiers = specs;
    }
    return _specifiers;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        cell.textLabel.textColor = [UIColor labelColor];
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.font = [UIFont systemFontOfSize:14];
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    return cell;
}

@end

@implementation CSPBackupListViewController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = @"Backup & Restore";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    if ([self respondsToSelector:@selector(table)]) {
        self.table.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSMutableArray *specs = [NSMutableArray array];
        PSSpecifier *group = [PSSpecifier groupSpecifierWithName:@"Preferences Management"];
        [group setProperty:@"Reset Asteroid to factory defaults or backup your configuration." forKey:@"footerText"];
        [specs addObject:group];

        PSSpecifier *resetBtn = [PSSpecifier preferenceSpecifierNamed:@"Reset to Defaults" target:self set:NULL get:NULL detail:Nil cell:PSButtonCell edit:Nil];
        resetBtn->action = @selector(resetDefaults);
        [resetBtn setProperty:@YES forKey:@"isDestructive"];
        [specs addObject:resetBtn];

        _specifiers = specs;
    }
    return _specifiers;
}

- (void)resetDefaults {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Defaults" message:@"Are you sure you want to reset all Asteroid settings to defaults?" preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [prefs resetToDefaults];
        [prefs saveAndPostNotification];
        UIAlertController *done = [UIAlertController alertControllerWithTitle:@"Reset Complete" message:@"Preferences have been reset. A respring is recommended." preferredStyle:UIAlertControllerStyleAlert];
        [done addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:done animated:YES completion:nil];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

#pragma mark - Main Preference Controller

@implementation LWPPreferenceController

- (NSString *)localizedStringForKey:(NSString *)key table:(NSString *)table {
    if (!key || ![key isKindOfClass:[NSString class]] || key.length == 0) return @"";
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];

    // 1. Try explicit plist table first
    if (table && table.length > 0) {
        NSString *val = [bundle localizedStringForKey:key value:nil table:table];
        if (val && ![val isEqualToString:key]) {
            return val;
        }
    }

    // 2. Try known string tables
    NSArray *tables = @[@"Localizable", @"Root", @"liveWeather", @"lockScreen", @"lockScreenViewKeys", @"homeScreen", @"statusBar", @"genSettings", @"icon", @"AsteroidSupport"];
    for (NSString *t in tables) {
        if ([t isEqualToString:table]) continue;
        NSString *val = [bundle localizedStringForKey:key value:nil table:t];
        if (val && ![val isEqualToString:key]) {
            return val;
        }
    }

    // 3. Fallback: If it's a key with underscores, format nicely with spaces
    if ([key containsString:@"_"]) {
        NSString *cleaned = [key stringByReplacingOccurrencesOfString:@"_" withString:@" "];
        if ([cleaned hasSuffix:@"X"]) {
            cleaned = [cleaned substringToIndex:cleaned.length - 1];
        }
        return cleaned;
    }

    return key;
}

- (NSArray *)localizeAndFormatSpecifiers:(NSArray *)specifiers plistName:(NSString *)plistName {
    for (PSSpecifier *spec in specifiers) {
        // Localize main label / name
        NSString *rawLabel = [spec propertyForKey:@"label"] ?: spec.name;
        if (rawLabel) {
            NSString *locLabel = [self localizedStringForKey:rawLabel table:plistName];
            spec.name = locLabel;
            [spec setProperty:locLabel forKey:@"label"];
        }

        // Localize sublabel
        NSString *rawSublabel = [spec propertyForKey:@"sublabel"];
        if (rawSublabel) {
            NSString *locSublabel = [self localizedStringForKey:rawSublabel table:plistName];
            [spec setProperty:locSublabel forKey:@"sublabel"];

            // If it's a link cell without a custom cellClass, give it our subtitle link cell class
            Class currentCellClass = (Class)[spec propertyForKey:@"cellClass"];
            if (!currentCellClass && spec.cellType == PSLinkCell) {
                [spec setProperty:[CSPLinkCell class] forKey:@"cellClass"];
            }
        }

        // Localize footerText
        NSString *rawFooter = [spec propertyForKey:@"footerText"];
        if (rawFooter && rawFooter.length > 0) {
            NSString *locFooter = [self localizedStringForKey:rawFooter table:plistName];
            [spec setProperty:locFooter forKey:@"footerText"];
        }

        // Localize title if present
        NSString *rawTitle = [spec propertyForKey:@"title"];
        if (rawTitle) {
            NSString *locTitle = [self localizedStringForKey:rawTitle table:plistName];
            [spec setProperty:locTitle forKey:@"title"];
        }

        // Map detail classes to our implementations
        NSString *detail = [spec propertyForKey:@"detail"];
        if ([detail isEqualToString:@"CSListItemsController"] || (spec.cellType == PSLinkListCell && !detail)) {
            [spec setProperty:@"CSListItemsController" forKey:@"detail"];
        } else if ([detail isEqualToString:@"CSListFontsController"]) {
            [spec setProperty:@"CSListFontsController" forKey:@"detail"];
        } else if ([detail isEqualToString:@"CSPChangeLogController"]) {
            [spec setProperty:@"CSPChangeLogController" forKey:@"detail"];
        } else if ([detail isEqualToString:@"CSPBackupListViewController"]) {
            [spec setProperty:@"CSPBackupListViewController" forKey:@"detail"];
        }
    }
    return specifiers;
}

- (NSArray *)specifiers {
    if (!_specifiers) {
        NSString *name = self.plistName ?: @"Root";
        NSArray *rawSpecs = [self loadSpecifiersFromPlistName:name target:self];
        _specifiers = [[self localizeAndFormatSpecifiers:rawSpecs plistName:name] mutableCopy];
    }
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.title = [self localizedStringForKey:(self.plistName ?: @"Asteroid") table:self.plistName];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    if ([self respondsToSelector:@selector(table)]) {
        self.table.backgroundColor = [UIColor systemGroupedBackgroundColor];
    }
    if (!self.plistName || [self.plistName isEqualToString:@"Root"]) {
        UIBarButtonItem *applyButton = [[UIBarButtonItem alloc] initWithTitle:@"Respring" style:UIBarButtonItemStyleDone target:self action:@selector(applySettings)];
        self.navigationItem.rightBarButtonItem = applyButton;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    if (cell) {
        if (![cell isKindOfClass:[CSPImageCell class]]) {
            if (cell.textLabel && cell.textLabel.textColor != [UIColor secondaryLabelColor]) {
                cell.textLabel.textColor = [UIColor labelColor];
            }
            if (cell.detailTextLabel) {
                cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
            }
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (![cell isKindOfClass:[CSPImageCell class]]) {
        if (cell.textLabel && cell.textLabel.textColor != [UIColor secondaryLabelColor]) {
            cell.textLabel.textColor = [UIColor labelColor];
        }
        if ([cell respondsToSelector:@selector(titleLabel)]) {
            [(id)cell titleLabel].textColor = [UIColor labelColor];
        }
        if (cell.detailTextLabel) {
            cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        }
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    id val = [prefs objectForKey:key];
    return val ?: [specifier propertyForKey:@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *key = [specifier propertyForKey:@"key"];
    if (key) {
        [prefs setObject:value forKey:key];
        [prefs saveAndPostNotification];
    }
}

- (void)pushToView:(PSSpecifier *)specifier {
    NSString *pushToPlist = [specifier propertyForKey:@"pushToPlist"];
    if (pushToPlist) {
        LWPPreferenceController *vc = [[LWPPreferenceController alloc] init];
        vc.plistName = pushToPlist;
        NSString *rawTitle = [specifier propertyForKey:@"label"] ?: pushToPlist;
        vc.title = [self localizedStringForKey:rawTitle table:self.plistName];
        [self.navigationController pushViewController:vc animated:YES];
    }
}

- (void)openInBrowser:(PSSpecifier *)specifier {
    NSString *urlStr = [specifier propertyForKey:@"url"];
    if (!urlStr || urlStr.length == 0) {
        NSString *username = [specifier propertyForKey:@"username"];
        NSString *provider = [NSString stringWithFormat:@"%@", [specifier propertyForKey:@"provider"] ?: @""];
        if (username.length > 0) {
            username = [username stringByReplacingOccurrencesOfString:@"%5f" withString:@"_"];
            if ([provider isEqualToString:@"0"] || [provider isEqualToString:@"twitter"]) {
                urlStr = [NSString stringWithFormat:@"https://twitter.com/%@", username];
            } else if ([provider isEqualToString:@"1"] || [provider isEqualToString:@"github"]) {
                urlStr = [NSString stringWithFormat:@"https://github.com/%@", username];
            }
        }
    }
    if (urlStr) {
        NSURL *url = [NSURL URLWithString:urlStr];
        if (url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

- (void)email:(PSSpecifier *)specifier {
    NSString *mailto = [specifier propertyForKey:@"mailto"] ?: [specifier propertyForKey:@"email"];
    if (mailto) {
        if (![mailto hasPrefix:@"mailto:"]) {
            mailto = [NSString stringWithFormat:@"mailto:%@", mailto];
        }
        NSURL *url = [NSURL URLWithString:mailto];
        if (url) {
            [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
        }
    }
}

- (void)copyTweakList {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = @"Asteroid v4.0.0 (Rootless)";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Asteroid" message:@"Copied to clipboard." preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSArray *)getImageType {
    return @[@"Filled Solid Color", @"Outline Image"];
}

- (NSArray *)fontNames {
    static NSArray *cachedFonts = nil;
    if (!cachedFonts) {
        NSMutableArray *names = [NSMutableArray array];
        for (NSString *family in [UIFont familyNames]) {
            NSArray *fontsInFamily = [UIFont fontNamesForFamilyName:family];
            if (fontsInFamily.count > 0) {
                [names addObjectsFromArray:fontsInFamily];
            } else {
                [names addObject:family];
            }
        }
        cachedFonts = [names sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    }
    return cachedFonts;
}

- (void)resetLoc {
    [prefs setObject:@(YES) forKey:@"resetXY"];
    [prefs saveAndPostNotification];
    [self applySettings];
}

- (void)resetSizeMethod {
    [prefs setObject:@(YES) forKey:@"resetSizing"];
    [prefs saveAndPostNotification];
}

- (NSArray *)weatherConditionsKeys {
    NSDictionary *conditions = [self weatherConditionsDict];
    NSArray *unorganizedKeys = [conditions allKeys];
    return [unorganizedKeys sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
}

- (NSArray *)weatherConditionsValues {
    NSDictionary *conditions = [self weatherConditionsDict];
    NSArray *organizedKeys = [self weatherConditionsKeys];
    NSMutableArray *organizedValues = [[NSMutableArray alloc] init];
    for (NSString *key in organizedKeys) {
        [organizedValues addObject:conditions[key]];
    }
    return organizedValues;
}

- (NSDictionary *)weatherConditionsDict {
    return @{
        @"Tornado": @0,
        @"Tropical Storm": @1,
        @"Hurricane": @2,
        @"Severe Thunderstorm": @3,
        @"Thunderstorm": @4,
        @"Mixed Rain & Snow": @5,
        @"Mixed Rain & Sleet": @6,
        @"Mixed Snow & Sleet": @7,
        @"Drizzle": @9,
        @"Showers": @11,
        @"Rain": @12,
        @"Flurries": @13,
        @"Snow Showers": @14,
        @"Blowing Snow": @15,
        @"Snow": @16,
        @"Hail": @17,
        @"Sleet": @18,
        @"Dust": @19,
        @"Fog": @20,
        @"Haze": @21,
        @"Smoke": @22,
        @"Breezy": @23,
        @"Windy": @24,
        @"Frigid": @25,
        @"Cloudy": @26,
        @"Mostly Cloudy (Night)": @27,
        @"Mostly Cloudy (Day)": @28,
        @"Partly Cloudy (Night)": @29,
        @"Partly Cloudy (Day)": @30,
        @"Clear (Night)": @31,
        @"Sunny": @32,
        @"Mostly Clear (Night)": @33,
        @"Mostly Sunny (Day)": @34,
        @"Mixed Rainfall": @35,
        @"Hot": @36,
        @"Isolated Thunderstorms": @37,
        @"Scattered Thunderstorms": @38,
        @"Scattered Showers": @39,
        @"Heavy Rain": @40,
        @"Scattered Snow Showers": @41,
        @"Heavy Snow": @42,
        @"Blizzard": @43,
        @"Isolated Thundershowers": @47
    };
}

- (void)gplInfo {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"License Information"
                                                                   message:@"Asteroid is licensed under the GPL-3.0 License."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"View on GitHub" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [self openGPL];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)openGPL {
    NSURL *url = [NSURL URLWithString:@"https://github.com/midnightchip/Asteroid/blob/master/LICENSE.md"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)applySettings {
    UIAlertController *respringAlert = [UIAlertController alertControllerWithTitle:@"Respring"
                                                                           message:@"Applying changes will respring SpringBoard."
                                                                    preferredStyle:UIAlertControllerStyleAlert];
    [respringAlert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [respringAlert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [self startRespring];
    }]];
    [self presentViewController:respringAlert animated:YES completion:nil];
}

- (void)startRespring {
    pid_t pid;
    const char *args[] = {"killall", "-9", "backboardd", NULL};
    posix_spawn(&pid, ROOT_PATH("/usr/bin/killall"), NULL, NULL, (char *const *)args, NULL);
}

@end
