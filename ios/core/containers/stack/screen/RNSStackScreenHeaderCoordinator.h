#pragma once

#import <UIKit/UIKit.h>
#import "RNSImageLoading.h"
#import "RNSStackHeaderConfigDataProviding.h"
#import "RNSStackHeaderEventsDelegate.h"
#import "RNSStackHeaderMenuData.h"
#import "RNSViewFrameChangeDelegate.h"

NS_ASSUME_NONNULL_BEGIN

@class RNSStackNavigationController;
@class RNSStackScreenController;

@interface RNSStackScreenHeaderCoordinator : NSObject

- (instancetype)initWithScreenController:(RNSStackScreenController *)controller;

@property (nonatomic, weak, nullable) id<RNSStackHeaderConfigDataProviding> configDataProvider;
@property (nonatomic, weak, nullable) id<RNSViewFrameChangeDelegate> frameChangeDelegate;
@property (nonatomic, weak, nullable) id<RNSStackHeaderEventsDelegate> eventsDelegate;
@property (nonatomic, weak, nullable) id<RNSImageLoading> imageLoader;

/**
 * Whether the navigation bar is shown while the screen has no header configuration. Defaults to NO: a screen without
 * a header configuration hides the navigation bar.
 */
@property (nonatomic) BOOL showsNavigationBarWithoutHeaderConfig;

- (void)rebuild;

- (void)applyConfigProperties;

- (void)rebuildItemWithId:(nullable NSString *)itemId;

- (void)reapplyMenuForItemWithId:(nullable NSString *)itemId;

- (void)resetTrackerForItemWithId:(nullable NSString *)itemId;

- (void)reapplyTitleMenu;

- (void)resetTitleMenuTracker;

- (void)setToggleState:(BOOL)state
      forMenuElementId:(NSString *)elementId
         trackerItemId:(NSString *)trackerItemId
              rootMenu:(RNSStackHeaderMenuData *)rootMenu
            parentMenu:(nullable RNSStackHeaderMenuData *)parentMenu;

- (void)clearHeaderConfiguration;

- (void)updateNavigationBarVisibilityAnimated:(BOOL)animated;

/**
 * Sets the custom title view again when the navigation bar shows the item without hosting the view.
 */
- (void)restoreDetachedTitleView;

#if !TARGET_OS_TV
/**
 * Hands this screen's toolbar items to its view controller.
 */
- (void)applyToolbarItems;

/**
 * Hands this screen's toolbar items to its view controller before `navigationController` shows the screen, i.e.
 * before UIKit reads the items of the incoming screen for its transition.
 */
- (void)applyToolbarItemsInNavigationController:(RNSStackNavigationController *)navigationController;

/**
 * Shows the shared toolbar when the screen is on top and has toolbar items, hides it otherwise.
 */
- (void)updateToolbarVisibilityAnimated:(BOOL)animated;

- (void)updateBackButtonMenuEnabled;

- (void)clearAppliedBackButtonConfig;
#endif // !TARGET_OS_TV

@end

NS_ASSUME_NONNULL_END
