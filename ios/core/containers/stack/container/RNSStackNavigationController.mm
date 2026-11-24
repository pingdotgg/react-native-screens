#import "RNSStackNavigationController.h"
#import "RNSAssert.h"
#import "RNSContainer.h"
#import "RNSContainerItem.h"
#import "RNSDefines.h"
#import "RNSLog.h"
#import "RNSParentContainerItemRegistry.h"
#import "RNSStackNavigationBar.h"
#import "RNSStackOperation.h"
#import "RNSStackScreenController.h"
#import "RNSStackScreenHeaderCoordinator.h"
#import "RNSViewControllerViewLifecycleEventsObserver.h"
#import "RNSViewFrameChangeDelegate.h"

@interface RNSStackNavigationController ()
- (BOOL)shouldPreventNativePopToController:(UIViewController *)controller;
@end

#if !TARGET_OS_TV
/**
 * Wraps UIKit's own delegate of a back gesture recognizer: refuses the gesture when the pop it would start is
 * prevented, and forwards everything else to the original delegate.
 */
@interface RNSStackPopGestureDelegate : NSObject <UIGestureRecognizerDelegate>
@property (nonatomic, weak) RNSStackNavigationController *navigationController;
@property (nonatomic, weak) id<UIGestureRecognizerDelegate> originalDelegate;
@end

@implementation RNSStackPopGestureDelegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
  RNSStackNavigationController *navigation = self.navigationController;
  if (navigation.viewControllers.count < 2) {
    return NO;
  }
  UIViewController *destination = navigation.viewControllers[navigation.viewControllers.count - 2];
  if ([navigation shouldPreventNativePopToController:destination]) {
    return NO;
  }
  if ([self.originalDelegate respondsToSelector:_cmd]) {
    return [self.originalDelegate gestureRecognizerShouldBegin:gestureRecognizer];
  }
  return YES;
}

- (BOOL)respondsToSelector:(SEL)selector
{
  return [super respondsToSelector:selector] || [self.originalDelegate respondsToSelector:selector];
}

- (id)forwardingTargetForSelector:(SEL)selector
{
  return self.originalDelegate;
}

@end
#endif // !TARGET_OS_TV

@implementation RNSStackNavigationController {
  NSMutableArray<RNSPushOperation *> *_Nonnull _pendingPushOperations;
  NSMutableArray<RNSPopOperation *> *_Nonnull _pendingPopOperations;
  RNSParentContainerItemRegistry *_Nonnull _parentContainerRegistry;
  // Pops requested by React are never prevented, only the ones UIKit starts.
  BOOL _performingReactUpdate;
#if !TARGET_OS_TV
  NSMutableDictionary<NSString *, UIBarButtonItem *> *_Nullable _toolbarIconButtons;
  RNSStackPopGestureDelegate *_Nullable _edgePopGestureDelegate;
  RNSStackPopGestureDelegate *_Nullable _contentPopGestureDelegate;
#endif // !TARGET_OS_TV
}

- (instancetype)init
{
#if !TARGET_OS_TV
  self = [super initWithNavigationBarClass:RNSStackNavigationBar.class toolbarClass:nil];
#else // !TARGET_OS_TV
  self = [super init];
#endif // !TARGET_OS_TV
  if (self != nil) {
    _navigationBarCoordinator = [RNSStackNavigationBarCoordinator new];
    [_navigationBarCoordinator initializeNavigationBarOfNavigationController:self];
    [self initState];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
#if !TARGET_OS_TV
  _edgePopGestureDelegate = [RNSStackPopGestureDelegate new];
  _edgePopGestureDelegate.navigationController = self;
  _edgePopGestureDelegate.originalDelegate = self.interactivePopGestureRecognizer.delegate;
  self.interactivePopGestureRecognizer.delegate = _edgePopGestureDelegate;
  [self.interactivePopGestureRecognizer addTarget:self action:@selector(popGestureRecognizerDidChangeState:)];
#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  if (@available(iOS 26.0, *)) {
    _contentPopGestureDelegate = [RNSStackPopGestureDelegate new];
    _contentPopGestureDelegate.navigationController = self;
    _contentPopGestureDelegate.originalDelegate = self.interactiveContentPopGestureRecognizer.delegate;
    self.interactiveContentPopGestureRecognizer.delegate = _contentPopGestureDelegate;
    [self.interactiveContentPopGestureRecognizer addTarget:self
                                                    action:@selector(popGestureRecognizerDidChangeState:)];
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
#endif // !TARGET_OS_TV
}

- (void)initState
{
  _pendingPushOperations = [NSMutableArray array];
  _pendingPopOperations = [NSMutableArray array];
  _parentContainerRegistry = [RNSParentContainerItemRegistry new];
}

#if !TARGET_OS_TV
- (UIBarButtonItem *)toolbarIconButtonForIdentifier:(NSString *)identifier
{
  if (_toolbarIconButtons == nil) {
    _toolbarIconButtons = [NSMutableDictionary new];
  }
  UIBarButtonItem *button = _toolbarIconButtons[identifier];
  if (button == nil) {
    button = [[UIBarButtonItem alloc] initWithTitle:nil style:UIBarButtonItemStylePlain target:nil action:nil];
    _toolbarIconButtons[identifier] = button;
  }
  return button;
}
#endif // !TARGET_OS_TV

#if !TARGET_OS_TV
- (void)popGestureRecognizerDidChangeState:(UIGestureRecognizer *)gestureRecognizer
{
  if (gestureRecognizer.state == UIGestureRecognizerStateBegan) {
    [_popGestureObserver stackNavigationController:self popGestureDidBegin:gestureRecognizer];
  }
}
#endif // !TARGET_OS_TV

#pragma mark - Native dismissal prevention

/**
 * The screen that prevents its native dismissal in `controller`, or in the stack nested in it: a parent screen can be
 * popped while its nested stack shows the guarded screen.
 */
- (nullable RNSStackScreenController *)preventingScreenInController:(nullable UIViewController *)controller
{
  if ([controller isKindOfClass:RNSStackScreenController.class]) {
    auto *screenController = static_cast<RNSStackScreenController *>(controller);
    if (screenController.preventsNativeDismiss) {
      return screenController;
    }
  }
  if ([controller conformsToProtocol:@protocol(RNSContainerItem)]) {
    id<RNSContainer> nested = [(id<RNSContainerItem>)controller resolveNestedContainer];
    if ([nested isKindOfClass:UINavigationController.class]) {
      return [self preventingScreenInController:static_cast<UINavigationController *>(nested).topViewController];
    }
  }
  return nil;
}

/**
 * Whether a native pop to `controller` is refused, because one of the screens it would remove prevents its native
 * dismissal. That screen is notified.
 */
- (BOOL)shouldPreventNativePopToController:(UIViewController *)controller
{
  if (_performingReactUpdate) {
    return NO;
  }
  NSUInteger destinationIndex = [self.viewControllers indexOfObject:controller];
  if (destinationIndex == NSNotFound) {
    return NO;
  }
  for (NSUInteger index = self.viewControllers.count; index > destinationIndex + 1; index--) {
    RNSStackScreenController *screenController = [self preventingScreenInController:self.viewControllers[index - 1]];
    if (screenController != nil) {
      [screenController notifyNativeDismissPrevented];
      return YES;
    }
  }
  return NO;
}

#pragma mark - Navigation

/**
 * UIKit reads the toolbar items of the incoming screen when the transition starts, so they are applied first.
 */
- (void)prepareToolbarForController:(nullable UIViewController *)controller
{
#if !TARGET_OS_TV
  if ([controller isKindOfClass:RNSStackScreenController.class]) {
    [static_cast<RNSStackScreenController *>(controller).headerCoordinator applyToolbarItemsInNavigationController:self];
  }
#endif // !TARGET_OS_TV
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated
{
  [self prepareToolbarForController:viewController];
  [super pushViewController:viewController animated:animated];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
  if (self.viewControllers.count > 1) {
    UIViewController *destination = self.viewControllers[self.viewControllers.count - 2];
    if ([self shouldPreventNativePopToController:destination]) {
      return nil;
    }
    [self prepareToolbarForController:destination];
  }
  return [super popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
  if ([self shouldPreventNativePopToController:viewController]) {
    return nil;
  }
  [self prepareToolbarForController:viewController];
  return [super popToViewController:viewController animated:animated];
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated
{
  if ([self shouldPreventNativePopToController:self.viewControllers.firstObject]) {
    return nil;
  }
  [self prepareToolbarForController:self.viewControllers.firstObject];
  return [super popToRootViewControllerAnimated:animated];
}

#pragma mark-- Layout

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  [_navigationBarFrameChangeDelegate viewFrameDidChange:self.navigationBar];
  [_viewFrameChangeDelegate viewFrameDidChange:self.view];
}

#pragma mark - View lifecycle events

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [_viewLifecycleEventsObserver viewControllerViewWillAppear:self];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [_viewLifecycleEventsObserver viewControllerViewDidAppear:self];
}

- (void)viewWillDisappear:(BOOL)animated
{
  [super viewWillDisappear:animated];
  [_viewLifecycleEventsObserver viewControllerViewWillDisappear:self];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [_viewLifecycleEventsObserver viewControllerViewDidDisappear:self];
}

#pragma mark - RNSContainer

- (nullable UIScrollView *)resolveCurrentContentScrollView
{
  // We assume `topViewController` corresponds to the currently presented screen.
  UIViewController *topController = self.topViewController;
  if (![topController isKindOfClass:RNSStackScreenController.class]) {
    return nil;
  }
  return [static_cast<RNSStackScreenController *>(topController) findContentScrollView];
}

- (void)attachToParentContainerItem
{
  [_parentContainerRegistry attachContainer:self];
}

- (void)detachFromParentContainerItem
{
  [_parentContainerRegistry detachContainer:self];
}

#pragma mark - View controller containment

- (void)didMoveToParentViewController:(UIViewController *)parent
{
  [super didMoveToParentViewController:parent];

  if (parent != nil) {
    [self attachToParentContainerItem];
  } else {
    [self detachFromParentContainerItem];
  }
}

- (BOOL)hasPendingOperations
{
  return _pendingPushOperations.count > 0 || _pendingPopOperations.count > 0;
}

- (void)enqueuePushOperation:(nonnull RNSStackScreenController *)screenController
{
  RNSPushOperation *operation = [[RNSPushOperation alloc] initWithScreenController:screenController];
  [_pendingPushOperations addObject:operation];
}

- (void)enqueuePopOperation:(nonnull RNSStackScreenController *)screenController
{
  RNSPopOperation *operation = [[RNSPopOperation alloc] initWithScreenController:screenController];
  [_pendingPopOperations addObject:operation];
}

#pragma mark - RNSContainerTransactionSupporting

- (void)beginTransaction
{
  // noop
}

- (void)commitTransaction
{
  // NOTE: We consider UINavigationController.viewControllers to be part of
  // the internal state of our stack implementation and expect it to be
  // *synchronously* updated by UIKit while we perform our pop and push operations
  //
  // The assertions below work under this assumption

  if (![self hasPendingOperations]) {
    return;
  }

  _performingReactUpdate = YES;
  for ([[maybe_unused]] RNSPopOperation *op in _pendingPopOperations) {
    RNSAssert([self.viewControllers count] > 1, @"[RNScreens] Attempt to pop last screen from the stack");
    RNSAssert(self.topViewController == static_cast<UIViewController *>(op.screenController),
              @"[RNScreens] Attempt to pop non-top screen");
    [self popViewControllerAnimated:YES];
  }

  for (RNSPushOperation *op in _pendingPushOperations) {
    [self pushViewController:op.screenController animated:YES];
  }

  RNSAssert([self.viewControllers count] > 0, @"[RNScreens] Stack should never be empty after updates");
  _performingReactUpdate = NO;

  [self dumpStackModel];

  [_pendingPopOperations removeAllObjects];
  [_pendingPushOperations removeAllObjects];
}

#pragma mark - Debug

- (void)dumpStackModel
{
#ifdef RNS_DEBUG_LOGGING
  RNSLogD(@"[RNScreens] StackContainer [%ld] MODEL BEGIN", self.view.tag);
  for (UIViewController *viewController in self.viewControllers) {
    RNSLogD(@"[RNScreens] %@", static_cast<RNSStackScreenController *>(viewController).configProvider.screenKey);
  }
#endif // RNS_DEBUG_LOGGING
}

@end
