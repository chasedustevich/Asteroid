#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import <Preferences/PSTableCell.h>
#import <Preferences/PSListItemsController.h>
#import "../source/LWPProvider.h"

@interface LWPPreferenceController : PSListController
@property (nonatomic, copy) NSString *plistName;
- (void)pushToView:(PSSpecifier *)specifier;
- (id)readPreferenceValue:(PSSpecifier *)specifier;
- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier;
- (NSString *)localizedStringForKey:(NSString *)key table:(NSString *)table;
- (NSArray *)fontNames;
- (NSArray *)weatherConditionsKeys;
- (NSArray *)weatherConditionsValues;
- (NSDictionary *)weatherConditionsDict;
@end

@interface CSListItemsController : PSListItemsController
@end

@interface CSListFontsController : CSListItemsController
@end

@interface CSPChangeLogController : PSListController
@end

@interface CSPBackupListViewController : PSListController
@end

@interface CSPLinkCell : PSTableCell
@end

@interface CSPImageCell : PSTableCell
@end

@interface CSPVersionCell : PSTableCell
@end

@interface CSPDeveloperCell : PSTableCell
@end

@interface CSPCalloutCell : PSTableCell
@end

@interface CSColorDisplayCell : PSTableCell
@end

@interface CSPDatePickerCell : PSTableCell
@end
