#pragma once

#import "RNSContainer.h"
#import "RNSContainerTransactionSupporting.h"
#include "RNSStackNavigationBarCoordinator.h"

@class RNSStackScreenController;
@protocol RNSViewControllerViewLifecycleEventsObserver;
@protocol RNSViewFrameChangeDelegate;

@interface RNSStackNavigationController : UINavigationController <RNSContainer, RNSContainerTransactionSupporting>

@property (nonatomic, weak, nullable) id<RNSViewFrameChangeDelegate> navigationBarFrameChangeDelegate;

/**
 * Notified when this controller lays out its view.
 */
@property (nonatomic, weak, nullable) id<RNSViewFrameChangeDelegate> viewFrameChangeDelegate;

/**
 * Notified about the lifecycle events of this controller's view.
 */
@property (nonatomic, weak, nullable) id<RNSViewControllerViewLifecycleEventsObserver> viewLifecycleEventsObserver;

@property (nonatomic, readonly, nonnull) RNSStackNavigationBarCoordinator *navigationBarCoordinator;

#if !TARGET_OS_TV
/**
 * The toolbar button that carries plain symbol items with `identifier` for all screens of this stack.
 */
- (nonnull UIBarButtonItem *)toolbarIconButtonForIdentifier:(nonnull NSString *)identifier;
#endif // !TARGET_OS_TV

- (void)enqueuePushOperation:(nonnull RNSStackScreenController *)screenController;

- (void)enqueuePopOperation:(nonnull RNSStackScreenController *)screenController;

@end
