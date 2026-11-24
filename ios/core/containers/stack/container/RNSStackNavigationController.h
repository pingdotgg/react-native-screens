#pragma once

#import "RNSContainer.h"
#import "RNSContainerTransactionSupporting.h"
#include "RNSStackNavigationBarCoordinator.h"

@class RNSStackNavigationController;
@class RNSStackScreenController;
@protocol RNSViewControllerViewLifecycleEventsObserver;
@protocol RNSViewFrameChangeDelegate;

/**
 * Observes the back gestures of an `RNSStackNavigationController`.
 */
@protocol RNSStackPopGestureObserver <NSObject>

/**
 * Called when a back gesture (edge or, on iOS 26, content swipe) has been recognized. It consumes the touch that
 * started it, also when the pop is cancelled later.
 */
- (void)stackNavigationController:(nonnull RNSStackNavigationController *)navigationController
           popGestureDidBegin:(nonnull UIGestureRecognizer *)gestureRecognizer;

@end

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

@property (nonatomic, weak, nullable) id<RNSStackPopGestureObserver> popGestureObserver;

#if !TARGET_OS_TV
/**
 * The toolbar button that carries plain symbol items with `identifier` for all screens of this stack.
 */
- (nonnull UIBarButtonItem *)toolbarIconButtonForIdentifier:(nonnull NSString *)identifier;
#endif // !TARGET_OS_TV

/**
 * A stack that navigates a Split column can have no attached screens. It shows a native placeholder then, as UIKit
 * cannot show an empty navigation controller in a collapsed Split. A standalone stack keeps its root screen.
 */
@property (nonatomic) BOOL allowsEmptyStack;

/**
 * Whether the stack has no screen of its own, i.e. it is empty or shows the placeholder.
 */
@property (nonatomic, readonly, getter=isStackEmpty) BOOL stackEmpty;

- (void)enqueuePushOperation:(nonnull RNSStackScreenController *)screenController;

- (void)enqueuePopOperation:(nonnull RNSStackScreenController *)screenController;

@end
