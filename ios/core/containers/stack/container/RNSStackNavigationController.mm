#import "RNSStackNavigationController.h"
#import "RNSAssert.h"
#import "RNSContainer.h"
#import "RNSLog.h"
#import "RNSParentContainerItemRegistry.h"
#import "RNSStackNavigationBar.h"
#import "RNSStackOperation.h"
#import "RNSStackScreenController.h"
#import "RNSStackScreenHeaderCoordinator.h"
#import "RNSViewControllerViewLifecycleEventsObserver.h"
#import "RNSViewFrameChangeDelegate.h"

@implementation RNSStackNavigationController {
  NSMutableArray<RNSPushOperation *> *_Nonnull _pendingPushOperations;
  NSMutableArray<RNSPopOperation *> *_Nonnull _pendingPopOperations;
  RNSParentContainerItemRegistry *_Nonnull _parentContainerRegistry;
#if !TARGET_OS_TV
  NSMutableDictionary<NSString *, UIBarButtonItem *> *_Nullable _toolbarIconButtons;
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
    [self prepareToolbarForController:self.viewControllers[self.viewControllers.count - 2]];
  }
  return [super popViewControllerAnimated:animated];
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
  [self prepareToolbarForController:viewController];
  return [super popToViewController:viewController animated:animated];
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated
{
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
