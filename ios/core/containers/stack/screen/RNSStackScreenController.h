#pragma once

#import <UIKit/UIKit.h>
#import "RNSContainerItem.h"

NS_ASSUME_NONNULL_BEGIN

@class RNSStackController;
@class RNSStackScreenHeaderCoordinator;
@protocol RNSStackContainerItemConfigProviding;
@protocol RNSStackScreenControllerDelegate;

@interface RNSStackScreenController : UIViewController <RNSContainerItem>

@property (nonatomic, strong, readonly, nonnull) RNSStackScreenHeaderCoordinator *headerCoordinator;

@property (nonatomic, weak, nullable) id<RNSStackScreenControllerDelegate> delegate;
@property (nonatomic, weak, nullable) id<RNSStackContainerItemConfigProviding> configProvider;

/**
 * Whether the screen currently refuses to be removed natively. See `RNSStackContainerItemConfigProviding`.
 */
@property (nonatomic, readonly) BOOL preventsNativeDismiss;

/**
 * Tells the delegate that a native pop removing this screen was refused.
 */
- (void)notifyNativeDismissPrevented;

@end

/**
 * Receives the lifecycle of a stack screen from its controller.
 */
@protocol RNSStackScreenControllerDelegate <NSObject>

- (void)viewControllerViewWillAppear:(RNSStackScreenController *)controller;
- (void)viewControllerViewDidAppear:(RNSStackScreenController *)controller;
- (void)viewControllerViewWillDisappear:(RNSStackScreenController *)controller;
- (void)viewControllerViewDidDisappear:(RNSStackScreenController *)controller;

/**
 * Called when the controller has been removed from its navigation controller, after the pop transition completed.
 * The removal may have been requested by the owner of the screen or made by UIKit (e.g. the back gesture); the
 * delegate tells them apart.
 */
- (void)stackScreenControllerDidLeaveStack:(RNSStackScreenController *)controller;

@optional

/**
 * Called when the navigation controller refused a native pop (back button, back gesture, back menu) that would have
 * removed this screen, because the screen prevents native dismissal.
 */
- (void)stackScreenControllerDidPreventNativeDismiss:(RNSStackScreenController *)controller;

@end

/**
 * What the view of a stack screen provides to its `RNSStackScreenController`.
 */
@protocol RNSStackContainerItemConfigProviding <NSObject>

@property (nonatomic, readonly, nullable) NSString *screenKey;

/**
 * Content scroll view registered within the screen, or nil if none has been registered.
 */
- (nullable UIScrollView *)cachedContentScrollView;

/**
 * Whether pushing the screen onto the stack is animated.
 */
@property (nonatomic, readonly) BOOL animatesPush;

@optional

/**
 * Whether UIKit may not remove the screen natively (back button, back gesture, back menu) while it is attached.
 */
@property (nonatomic, readonly) BOOL preventsNativeDismiss;

@end

NS_ASSUME_NONNULL_END
