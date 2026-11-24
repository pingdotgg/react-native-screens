#pragma once

#import <UIKit/UIKit.h>

#import "RNSHeaderItemAxisBehavior.h"
#import "RNSHeaderItemPlacement.h"
#import "RNSHeaderItemVisibilityPriority.h"
#import "RNSStackHeaderIconData.h"
#import "RNSStackHeaderMenuData.h"

NS_ASSUME_NONNULL_BEGIN

@protocol RNSStackHeaderItemDataProviding <NSObject>

@property (nonatomic, readonly) RNSHeaderItemPlacement placement;
@property (nonatomic, readonly, nullable) NSString *itemId;
@property (nonatomic, readonly, nullable) NSString *identifier;
@property (nonatomic, readonly, nullable) NSString *title;
@property (nonatomic, readonly, nullable) RNSStackHeaderIconData *icon;
@property (nonatomic, readonly, nullable) RNSStackHeaderMenuData *menu;
@property (nonatomic, readonly, nullable) RNSStackHeaderMenuData *menuRepresentation;
@property (nonatomic, readonly, nullable) UIView *customView;
@property (nonatomic, readonly) UIBarButtonItemStyle style;

/**
 Tint color of the bar button item; nil means the default system tint.
 Named itemTintColor to avoid clashing with UIView's tintColor on conforming views.
 */
@property (nonatomic, readonly, nullable) UIColor *itemTintColor;
@property (nonatomic, readonly) BOOL disabled;
@property (nonatomic, readonly) BOOL respondsToOnPress;
@property (nonatomic, readonly) BOOL hidesSharedBackground;
/**
 Whether the item is UIKit's search placement bar button item (iOS 26+), which shows the header's search bar.
 */
@property (nonatomic, readonly) BOOL searchBarPlacement;
@property (nonatomic, readonly) RNSHeaderItemAxisBehavior axisBehavior;
@property (nonatomic, readonly) RNSHeaderItemVisibilityPriority visibilityPriority;

@end

NS_ASSUME_NONNULL_END
