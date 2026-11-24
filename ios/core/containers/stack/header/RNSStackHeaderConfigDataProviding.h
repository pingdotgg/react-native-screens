#pragma once

#import <UIKit/UIKit.h>
#import "RNSDefines.h"

@class RNSStackHeaderMenuData;

NS_ASSUME_NONNULL_BEGIN

@protocol RNSStackHeaderConfigDataProviding <NSObject>

@property (nonatomic, readonly, nullable) NSString *title;
@property (nonatomic, readonly, nullable) NSString *subtitle;
@property (nonatomic, readonly) BOOL hidden;
@property (nonatomic, readonly) BOOL backButtonHidden;
/**
 * Tint of the navigation bar and toolbar while the screen is on top; nil means the default system tint.
 * Named headerTintColor to avoid clashing with UIView's tintColor on conforming views.
 */
@property (nonatomic, readonly, nullable) UIColor *headerTintColor;
#if !TARGET_OS_TV
@property (nonatomic, readonly) UINavigationItemStyle navigationItemStyle API_AVAILABLE(ios(16.0));
#endif // !TARGET_OS_TV
@property (nonatomic, readonly, nullable) NSString *largeTitle;
@property (nonatomic, readonly, nullable) NSString *largeSubtitle;
@property (nonatomic, readonly) BOOL largeTitleEnabled;
@property (nonatomic, readonly, nullable) NSString *prompt;
#if RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_VISION && !TARGET_OS_TV
@property (nonatomic, readonly) UIBarMinimizationBehavior minimizationBehavior API_AVAILABLE(ios(27.0));
@property (nonatomic, readonly) UIBarMinimizationRestorationBehavior restorationBehavior API_AVAILABLE(ios(27.0));
@property (nonatomic, readonly) UIBarMinimizationSafeAreaAdjustment safeAreaAdjustment API_AVAILABLE(ios(27.0));
#endif // Check for iOS >= 27 && !TARGET_OS_VISION && !TARGET_OS_TV
@property (nonatomic, readonly, nullable) NSString *backButtonTitle;
@property (nonatomic, readonly) UINavigationItemBackButtonDisplayMode backButtonDisplayMode;
@property (nonatomic, readonly) BOOL backButtonMenuEnabled;
@property (nonatomic, readonly, nullable) RNSStackHeaderMenuData *titleMenu;
@property (nonatomic, readonly, nullable) UINavigationBarAppearance *standardAppearance;
@property (nonatomic, readonly, nullable) UINavigationBarAppearance *scrollEdgeAppearance;

#if !TARGET_OS_TV
/**
 Search controller of the header's search bar, or nil when the header has none.
 The properties below are read only when it is set.
 */
@property (nonatomic, readonly, nullable) UISearchController *searchController;
@property (nonatomic, readonly) BOOL hidesSearchBarWhenScrolling;
@property (nonatomic, readonly) UINavigationItemSearchBarPlacement preferredSearchBarPlacement API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) BOOL searchBarAllowsToolbarIntegration;
#endif // !TARGET_OS_TV

/**
 Children are expected to conform to either RNSStackHeaderItemDataProviding
 or RNSStackHeaderItemSpacerDataProviding, other types (e.g. the search bar) are ignored.
 */
@property (nonatomic, readonly) NSArray<id> *children;

@end

NS_ASSUME_NONNULL_END
