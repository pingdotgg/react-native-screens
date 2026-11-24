#import "RNSStackScreenHeaderCoordinator.h"
#import "RNSAssert.h"
#import "RNSDefines.h"
#import "RNSLog.h"
#import "RNSStackHeaderContentFactory.h"
#import "RNSStackHeaderItemDataProviding.h"
#import "RNSStackHeaderItemSpacerDataProviding.h"
#import "RNSStackHeaderMenuCoordinator.h"
#import "RNSStackHeaderMenuFinder.h"
#import "RNSStackHeaderMenuTrackerRegistry.h"
#import "RNSStackNavigationBarCoordinator.h"
#import "RNSStackNavigationController.h"
#import "RNSStackScreenController.h"

#if RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_TV && !TARGET_OS_VISION
API_AVAILABLE(ios(27.0))
static UIBarButtonItemVisibilityPriority RNSBarButtonItemVisibilityPriorityFromVisibilityPriority(
    RNSHeaderItemVisibilityPriority visibilityPriority);
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_TV && !TARGET_OS_VISION

@implementation RNSStackScreenHeaderCoordinator {
  __weak RNSStackScreenController *_Nullable _screenController;

#if !TARGET_OS_TV
  // Navigation item of the screen below, onto which the back button
  // configuration has been applied. Kept so that the configuration can be
  // cleared when the owning screen is popped from the stack.
  __weak UINavigationItem *_Nullable _backButtonConfigTargetItem;
#endif // !TARGET_OS_TV

  RNSStackHeaderMenuTrackerRegistry *_Nonnull _trackerRegistry;

  NSMutableArray<UIBarButtonItem *> *_Nonnull _leadingBarButtonItems;
  NSMutableArray<UIBarButtonItem *> *_Nonnull _trailingBarButtonItems;
  NSMutableArray<UIBarButtonItem *> *_Nonnull _toolbarBarButtonItems;
  NSMutableDictionary<NSString *, UIBarButtonItem *> *_Nonnull _barButtonItemsByItemId;
}

- (instancetype)initWithScreenController:(RNSStackScreenController *)controller
{
  if (self = [super init]) {
    _screenController = controller;
    _trackerRegistry = [RNSStackHeaderMenuTrackerRegistry new];
    _leadingBarButtonItems = [NSMutableArray new];
    _trailingBarButtonItems = [NSMutableArray new];
    _toolbarBarButtonItems = [NSMutableArray new];
    _barButtonItemsByItemId = [NSMutableDictionary new];
  }
  return self;
}

#pragma mark - Public

- (void)updateNavigationBarVisibilityAnimated:(BOOL)animated
{
  RNSStackNavigationController *navController = [self getNavigationController];
  if (navController == nil || navController.topViewController != _screenController) {
    return;
  }

  // The bars are shared by all screens of the stack: the visible screen owns their tint, including after a native pop.
  UIColor *tintColor = _configDataProvider.headerTintColor;
  navController.navigationBar.tintColor = tintColor;
#if !TARGET_OS_TV
  navController.toolbar.tintColor = tintColor;
#endif // !TARGET_OS_TV

  BOOL hidden = _configDataProvider == nil ? !_showsNavigationBarWithoutHeaderConfig : _configDataProvider.hidden;
  [navController.navigationBarCoordinator setHidden:hidden forNavigationController:navController animated:animated];
}

- (void)rebuild
{
  if (_configDataProvider == nil) {
    return;
  }

  RNSStackScreenController *controller = [self requireScreenController];

  [_leadingBarButtonItems removeAllObjects];
  [_trailingBarButtonItems removeAllObjects];
  [_toolbarBarButtonItems removeAllObjects];
  [_barButtonItemsByItemId removeAllObjects];
  [_trackerRegistry clear];

  UIView *titleView = nil;
  UIView *subtitleView = nil;
  UIView *largeSubtitleView = nil;

  for (UIView *child in _configDataProvider.children) {
    if ([child conformsToProtocol:@protocol(RNSStackHeaderItemDataProviding)]) {
      id<RNSStackHeaderItemDataProviding> item = (id<RNSStackHeaderItemDataProviding>)child;

      switch (item.placement) {
        case RNSHeaderItemPlacementLeading:
          [_leadingBarButtonItems addObject:[self buildBarButtonItemForItem:item]];
          break;
        case RNSHeaderItemPlacementTrailing:
          [_trailingBarButtonItems addObject:[self buildBarButtonItemForItem:item]];
          break;
        case RNSHeaderItemPlacementToolbar:
#if !TARGET_OS_TV
          [_toolbarBarButtonItems addObject:[self buildBarButtonItemForItem:item]];
#endif // !TARGET_OS_TV
          break;
        case RNSHeaderItemPlacementTitle:
          if (item.customView != nil) {
            titleView = [RNSStackHeaderContentFactory wrappedViewForHeaderItem:item
                                                           frameChangeDelegate:_frameChangeDelegate];
          }
          break;
        case RNSHeaderItemPlacementSubtitle:
          if (item.customView != nil) {
            subtitleView = [RNSStackHeaderContentFactory wrappedViewForHeaderItem:item
                                                              frameChangeDelegate:_frameChangeDelegate];
          }
          break;
        case RNSHeaderItemPlacementLargeSubtitle:
          if (item.customView != nil) {
            largeSubtitleView = [RNSStackHeaderContentFactory wrappedViewForHeaderItem:item
                                                                   frameChangeDelegate:_frameChangeDelegate];
          }
          break;
      }
    } else if ([child conformsToProtocol:@protocol(RNSStackHeaderItemSpacerDataProviding)]) {
      id<RNSStackHeaderItemSpacerDataProviding> spacer = (id<RNSStackHeaderItemSpacerDataProviding>)child;
      UIBarButtonItem *barButtonItem = [RNSStackHeaderContentFactory spacerForHeaderSpacerItem:spacer];
      switch (spacer.placement) {
        case RNSHeaderItemSpacerPlacementLeading:
          [_leadingBarButtonItems addObject:barButtonItem];
          break;
        case RNSHeaderItemSpacerPlacementTrailing:
          [_trailingBarButtonItems addObject:barButtonItem];
          break;
        case RNSHeaderItemSpacerPlacementToolbar:
#if !TARGET_OS_TV
          [_toolbarBarButtonItems addObject:barButtonItem];
#endif // !TARGET_OS_TV
          break;
      }
    }
  }

  [self applyConfigPropertiesForController:controller];
  [self applyItemsWithTitleView:titleView
                   subtitleView:subtitleView
              largeSubtitleView:largeSubtitleView
                  forController:controller];

  [self applyTitleMenuForController:controller];
  [self updateNavigationBarVisibilityAnimated:YES];
#if !TARGET_OS_TV
  [self updateToolbarVisibilityAnimated:YES];
  [self updateBackButtonMenuEnabled];
#endif // !TARGET_OS_TV
}

- (void)applyConfigProperties
{
  if (_configDataProvider == nil) {
    return;
  }

  [self applyConfigPropertiesForController:[self requireScreenController]];
#if !TARGET_OS_TV
  [self applyToolbarItemsForController:[self requireScreenController]];
#endif // !TARGET_OS_TV
  [self updateNavigationBarVisibilityAnimated:YES];
#if !TARGET_OS_TV
  [self updateToolbarVisibilityAnimated:YES];
  [self updateBackButtonMenuEnabled];
#endif // !TARGET_OS_TV
}

#if !TARGET_OS_TV
- (void)applyToolbarItems
{
  [self applyToolbarItemsForController:[self requireScreenController]];
}

- (void)applyToolbarItemsInNavigationController:(RNSStackNavigationController *)navigationController
{
  [self applyToolbarItemsForController:[self requireScreenController]
                  navigationController:navigationController
                              activate:YES];
}

- (void)updateToolbarVisibilityAnimated:(BOOL)animated
{
  RNSStackNavigationController *navController = [self getNavigationController];
  if (navController == nil || navController.topViewController != _screenController) {
    return;
  }

  // Items belong to each screen. Only the visible screen may change the shared toolbar.
  [navController setToolbarHidden:_screenController.toolbarItems.count == 0 animated:animated];
}

- (void)updateBackButtonMenuEnabled
{
  RNSStackNavigationController *navController = [self getNavigationController];
  if (navController == nil || navController.topViewController != _screenController) {
    return;
  }

  BOOL enabled = _configDataProvider == nil || _configDataProvider.backButtonMenuEnabled;
  [navController.navigationBarCoordinator setBackButtonMenuEnabled:enabled forNavigationController:navController];
}
#endif // !TARGET_OS_TV

/**
 Rebuilds an existing item: sets all props and applies the menu config.
 */
- (void)rebuildItemWithId:(NSString *)itemId
{
  if (_configDataProvider == nil || itemId == nil) {
    return;
  }

  UIBarButtonItem *oldBarButtonItem = _barButtonItemsByItemId[itemId];

  id<RNSStackHeaderItemDataProviding> targetItem = [self findItemWithId:itemId];
  if (targetItem == nil) {
    return;
  }

  RNSStackScreenController *controller = [self requireScreenController];

  switch (targetItem.placement) {
    case RNSHeaderItemPlacementLeading: {
      UIBarButtonItem *newBarButtonItem = [self buildBarButtonItemForItem:targetItem];

      if (oldBarButtonItem != nil) {
        NSUInteger index = [_leadingBarButtonItems indexOfObject:oldBarButtonItem];
        if (index != NSNotFound) {
          _leadingBarButtonItems[index] = newBarButtonItem;
        } else {
          RNSLogW(@"[RNScreens] Item %@ not found for rebuild.", oldBarButtonItem);
        }
      }

      [controller.navigationItem setLeftBarButtonItems:[_leadingBarButtonItems copy] animated:YES];
      break;
    }
    case RNSHeaderItemPlacementTrailing: {
      UIBarButtonItem *newBarButtonItem = [self buildBarButtonItemForItem:targetItem];

      if (oldBarButtonItem != nil) {
        NSUInteger index = [_trailingBarButtonItems indexOfObject:oldBarButtonItem];
        if (index != NSNotFound) {
          _trailingBarButtonItems[index] = newBarButtonItem;
        } else {
          RNSLogW(@"[RNScreens] Item %@ not found for rebuild.", oldBarButtonItem);
        }
      }

      [controller.navigationItem setRightBarButtonItems:[_trailingBarButtonItems copy] animated:YES];
      break;
    }
    case RNSHeaderItemPlacementToolbar: {
#if !TARGET_OS_TV
      UIBarButtonItem *newBarButtonItem = [self buildBarButtonItemForItem:targetItem];
      NSUInteger index = oldBarButtonItem == nil ? NSNotFound : [_toolbarBarButtonItems indexOfObject:oldBarButtonItem];
      if (index != NSNotFound) {
        _toolbarBarButtonItems[index] = newBarButtonItem;
      } else {
        RNSLogW(@"[RNScreens] Item %@ not found for rebuild.", oldBarButtonItem);
      }
      [self applyToolbarItemsForController:controller];
      [self updateToolbarVisibilityAnimated:YES];
#endif // !TARGET_OS_TV
      break;
    }
    case RNSHeaderItemPlacementTitle:
      controller.navigationItem.titleView = targetItem.customView != nil
          ? [RNSStackHeaderContentFactory wrappedViewForHeaderItem:targetItem frameChangeDelegate:_frameChangeDelegate]
          : nil;
      break;
    case RNSHeaderItemPlacementSubtitle:
#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
      if (@available(iOS 26.0, *)) {
        controller.navigationItem.subtitleView = targetItem.customView != nil
            ? [RNSStackHeaderContentFactory wrappedViewForHeaderItem:targetItem
                                                 frameChangeDelegate:_frameChangeDelegate]
            : nil;
      }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
      break;
    case RNSHeaderItemPlacementLargeSubtitle:
#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
      if (@available(iOS 26.0, *)) {
        controller.navigationItem.largeSubtitleView = targetItem.customView != nil
            ? [RNSStackHeaderContentFactory wrappedViewForHeaderItem:targetItem
                                                 frameChangeDelegate:_frameChangeDelegate]
            : nil;
      }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
      break;
  }
}

- (void)resetTrackerForItemWithId:(NSString *)itemId
{
  if (itemId != nil) {
    [_trackerRegistry resetTrackerForItemId:itemId];
  }
}

- (void)reapplyTitleMenu
{
  if (_configDataProvider == nil) {
    return;
  }
  [self applyTitleMenuForController:[self requireScreenController]];
}

- (void)resetTitleMenuTracker
{
  [_trackerRegistry resetTrackerForItemId:RNSTitleMenuTrackerItemId];
}

- (void)setToggleState:(BOOL)state
      forMenuElementId:(NSString *)elementId
         trackerItemId:(NSString *)trackerItemId
              rootMenu:(RNSStackHeaderMenuData *)rootMenu
            parentMenu:(nullable RNSStackHeaderMenuData *)parentMenu
{
  if (_configDataProvider == nil || elementId == nil || trackerItemId == nil || rootMenu == nil) {
    return;
  }

  RNSStackHeaderMenuToggleStateTracker *tracker = [_trackerRegistry trackerForItemId:trackerItemId];

  if ([tracker toggleStateEquals:state forItemWithId:elementId]) {
    return;
  }

  RNSStackHeaderMenuData *singleSelectionRoot = [RNSStackHeaderMenuFinder singleSelectionRootForElementWithId:elementId
                                                                                                       inMenu:rootMenu];

  NSString *eventMenuId = nil;
  NSArray<NSString *> *toggleIds = nil;

  if (singleSelectionRoot != nil) {
    if (!state) {
      // Setting false in singleSelection is ignored — one item must always be selected.
      return;
    }
    toggleIds = [RNSStackHeaderMenuCoordinator getAllToggleItemsIdsInSingleSelectionHierarchy:singleSelectionRoot];
    [tracker selectItemWithId:elementId fromIds:toggleIds];
    eventMenuId = singleSelectionRoot.menuElementId;
  } else {
    [tracker setToggleState:state forItemWithId:elementId];
    toggleIds = parentMenu != nil ? [RNSStackHeaderMenuCoordinator getToggleItemsIdsInMenu:parentMenu] : @[ elementId ];
    eventMenuId = parentMenu != nil ? parentMenu.menuElementId : nil;
  }

  if (eventMenuId != nil) {
    NSMutableArray<NSString *> *selectedIds = [NSMutableArray new];
    for (NSString *toggleId in toggleIds) {
      if ([tracker getToggleStateForItemWithId:toggleId initialState:NO]) {
        [selectedIds addObject:toggleId];
      }
    }
    [_eventsDelegate didChangeSelectionForMenu:eventMenuId selectedMenuItemIds:selectedIds];
  }
}

- (void)clearHeaderConfiguration
{
  _configDataProvider = nil;
  _frameChangeDelegate = nil;
  _eventsDelegate = nil;
  _imageLoader = nil;

  [_leadingBarButtonItems removeAllObjects];
  [_trailingBarButtonItems removeAllObjects];
  [_toolbarBarButtonItems removeAllObjects];
  [_barButtonItemsByItemId removeAllObjects];
  [_trackerRegistry clear];

  RNSStackScreenController *controller = [self requireScreenController];
  UINavigationItem *navItem = controller.navigationItem;

  navItem.title = nil;
  navItem.titleView = nil;
  navItem.standardAppearance = nil;
  navItem.scrollEdgeAppearance = nil;
  [navItem setLeftBarButtonItems:@[] animated:YES];
  [navItem setRightBarButtonItems:@[] animated:YES];

#if !TARGET_OS_TV
  if (@available(iOS 16.0, *)) {
    navItem.style = UINavigationItemStyleNavigator;
    navItem.titleMenuProvider = nil;
  }
#endif // !TARGET_OS_TV

#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  if (@available(iOS 26.0, *)) {
    navItem.subtitle = nil;
    navItem.largeTitle = nil;
    navItem.largeSubtitle = nil;
    navItem.subtitleView = nil;
    navItem.largeSubtitleView = nil;
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)

#if RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_VISION && !TARGET_OS_TV
  if (@available(iOS 27.0, *)) {
    navItem.navigationBarMinimization = [UIBarMinimization new];
  }
#endif // Check for iOS >= 27 && !TARGET_OS_VISION && !TARGET_OS_TV

#if !TARGET_OS_TV
  [controller setToolbarItems:nil animated:NO];
  navItem.prompt = nil;
  navItem.hidesBackButton = NO;
  navItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;

  [self clearAppliedBackButtonConfig];
#endif // !TARGET_OS_TV

  [self updateNavigationBarVisibilityAnimated:YES];
#if !TARGET_OS_TV
  [self updateToolbarVisibilityAnimated:YES];
  [self updateBackButtonMenuEnabled];
#endif // !TARGET_OS_TV
}

/**
 Finds an existing barButtonItem and its corresponding config, then applies it again.
 If the config is missing, it clears the menu.
 */
- (void)reapplyMenuForItemWithId:(NSString *)itemId
{
  if (_configDataProvider == nil || itemId == nil) {
    return;
  }

  UIBarButtonItem *barButtonItem = _barButtonItemsByItemId[itemId];
  if (barButtonItem == nil) {
    return;
  }

  id<RNSStackHeaderItemDataProviding> item = [self findItemWithId:itemId];
  if (item == nil) {
    return;
  }

  if (item.menu == nil) {
    barButtonItem.menu = nil;
  } else {
    RNSStackHeaderMenuToggleStateTracker *tracker = [_trackerRegistry trackerForItemId:itemId];
    __weak auto weakSelf = self;
    [RNSStackHeaderMenuCoordinator applyMenu:item.menu
                             toBarButtonItem:barButtonItem
                    withHeaderEventsDelegate:_eventsDelegate
                                stateTracker:tracker
                             withImageLoader:_imageLoader
                     menuInvalidatedCallback:^{
                       [weakSelf reapplyMenuForItemWithId:itemId];
                     }];
  }

  [self reapplyMenuRepresentationForItemWithId:itemId];
}

/**
 Finds an existing barButtonItem and its corresponding config, then applies the menu
 representation again. If the config is missing, it clears the representation.
 */
- (void)reapplyMenuRepresentationForItemWithId:(NSString *)itemId
{
  if (_configDataProvider == nil || itemId == nil) {
    return;
  }

  UIBarButtonItem *barButtonItem = _barButtonItemsByItemId[itemId];
  if (barButtonItem == nil) {
    return;
  }

  id<RNSStackHeaderItemDataProviding> item = [self findItemWithId:itemId];
  if (item == nil) {
    return;
  }

  RNSStackHeaderMenuToggleStateTracker *tracker = [_trackerRegistry trackerForItemId:itemId];
  __weak auto weakSelf = self;
  [RNSStackHeaderMenuCoordinator applyMenuRepresentation:item.menuRepresentation
                                         toBarButtonItem:barButtonItem
                                withHeaderEventsDelegate:_eventsDelegate
                                            stateTracker:tracker
                                         withImageLoader:_imageLoader
                                 menuInvalidatedCallback:^{
                                   [weakSelf reapplyMenuRepresentationForItemWithId:itemId];
                                 }];
}

- (nullable id<RNSStackHeaderItemDataProviding>)findItemWithId:(NSString *)itemId
{
  for (UIView *child in _configDataProvider.children) {
    if ([child conformsToProtocol:@protocol(RNSStackHeaderItemDataProviding)]) {
      id<RNSStackHeaderItemDataProviding> item = (id<RNSStackHeaderItemDataProviding>)child;
      if ([item.itemId isEqualToString:itemId]) {
        return item;
      }
    }
  }
  return nil;
}

#pragma mark - Private

- (RNSStackScreenController *)requireScreenController
{
  RNSAssert(_screenController != nil, @"[RNScreens] Screen Controller cannot be nil");
  return _screenController;
}

- (nullable RNSStackNavigationController *)getNavigationController
{
  RNSStackScreenController *screenController = [self requireScreenController];
  UINavigationController *navController = screenController.navigationController;
  if (navController == nil) {
    return nil;
  }

  RNSAssert([navController isKindOfClass:RNSStackNavigationController.class],
            @"[RNScreens] NavigationController should be instance of RNSStackNavigationController");
  return (RNSStackNavigationController *)navController;
}

- (void)applyConfigPropertiesForController:(RNSStackScreenController *)controller
{
  UINavigationItem *navItem = controller.navigationItem;

#if !TARGET_OS_TV
  if (@available(iOS 16.0, *)) {
    UINavigationItemStyle style = _configDataProvider.navigationItemStyle;
    if (navItem.style != style) {
      navItem.style = style;
      if (@available(iOS 26.0, *)) {
        // The style setter does not invalidate an already visible bar on iOS 26.
        // Reapplying its title content makes UIKit recompute the layout without
        // rebuilding the header items or their menu state.
        UIView *titleView = navItem.titleView;
        if (titleView != nil) {
          navItem.titleView = nil;
          navItem.titleView = titleView;
        } else {
          // A nonempty temporary title also invalidates a bar with no title.
          navItem.title = navItem.title.length == 0 ? @" " : nil;
        }
      }
    }
  }
#endif // !TARGET_OS_TV

  navItem.title = _configDataProvider.title;
  navItem.standardAppearance = _configDataProvider.standardAppearance;
  navItem.scrollEdgeAppearance = _configDataProvider.scrollEdgeAppearance;

#if !TARGET_OS_TV
  navItem.hidesBackButton = _configDataProvider.backButtonHidden;

  NSString *prompt = _configDataProvider.prompt;
  if (navItem.prompt != prompt && ![navItem.prompt isEqualToString:prompt]) {
    navItem.prompt = prompt;
    // UIKit does not resize an already visible navigation bar when the prompt
    // of its navigation item changes - request layout explicitly.
    [controller.navigationController.view setNeedsLayout];
  }

  [self applyBackButtonConfigForController:controller];
#endif // !TARGET_OS_TV

#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  if (@available(iOS 26.0, *)) {
    navItem.largeTitle = _configDataProvider.largeTitle;
    navItem.subtitle = _configDataProvider.subtitle;
    navItem.largeSubtitle = _configDataProvider.largeSubtitle;
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)

#if RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_VISION && !TARGET_OS_TV
  if (@available(iOS 27.0, *)) {
    UIBarMinimization *minimization = [UIBarMinimization new];
    minimization.minimizationBehavior = _configDataProvider.minimizationBehavior;
    minimization.restorationBehavior = _configDataProvider.restorationBehavior;
    minimization.safeAreaAdjustment = _configDataProvider.safeAreaAdjustment;
    navItem.navigationBarMinimization = minimization;
  }
#endif // Check for iOS >= 27 && !TARGET_OS_VISION && !TARGET_OS_TV

#if !TARGET_OS_TV
  navItem.largeTitleDisplayMode = _configDataProvider.largeTitleEnabled ? UINavigationItemLargeTitleDisplayModeAlways
                                                                        : UINavigationItemLargeTitleDisplayModeNever;
#endif // !TARGET_OS_TV
}

#if !TARGET_OS_TV
- (void)applyBackButtonConfigForController:(RNSStackScreenController *)controller
{
  NSArray<UIViewController *> *viewControllers = controller.navigationController.viewControllers;
  NSUInteger index = [viewControllers indexOfObject:controller];
  if (index == NSNotFound || index == 0) {
    return;
  }

  UINavigationItem *prevItem = viewControllers[index - 1].navigationItem;
  _backButtonConfigTargetItem = prevItem;
  prevItem.backButtonTitle = _configDataProvider.backButtonTitle;
  prevItem.backButtonDisplayMode = _configDataProvider.backButtonDisplayMode;
}
#endif // !TARGET_OS_TV

#if !TARGET_OS_TV
- (void)clearAppliedBackButtonConfig
{
  UINavigationItem *targetItem = _backButtonConfigTargetItem;
  _backButtonConfigTargetItem = nil;
  targetItem.backButtonTitle = nil;
  targetItem.backButtonDisplayMode = UINavigationItemBackButtonDisplayModeDefault;
}
#endif // !TARGET_OS_TV

#if !TARGET_OS_TV
- (void)applyToolbarItemsForController:(RNSStackScreenController *)controller
{
  RNSStackNavigationController *navController = [self getNavigationController];
  [self applyToolbarItemsForController:controller
                  navigationController:navController
                              activate:navController.topViewController == controller];
}

/**
 Hands the toolbar items to the controller. On iOS 26 a plain symbol button with an identifier is carried by one
 button per identifier, shared by all screens of the navigation controller. UIKit's integrated-search morph can offset
 an incoming icon inside its glass until the search field finishes laying out; keeping the same button, not only the
 same transition identifier, avoids that. `activate` copies this screen's contents onto the shared button; a screen
 that is not becoming visible leaves a button another screen already shows untouched.
 */
- (void)applyToolbarItemsForController:(RNSStackScreenController *)controller
                  navigationController:(nullable RNSStackNavigationController *)navController
                              activate:(BOOL)activate
{
  // The navigation controller already animates toolbar contents during a push/pop.
  // Animating each Fabric rebuild again hides custom items until a second fade completes.
#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  if (@available(iOS 26.0, *)) {
    if (navController != nil) {
      NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray new];
      for (UIBarButtonItem *source in _toolbarBarButtonItems) {
        if (source.identifier.length == 0 || !source.image.isSymbolImage || source.customView != nil ||
            source.menu != nil || source.style != UIBarButtonItemStylePlain) {
          [items addObject:source];
          continue;
        }

        UIBarButtonItem *button = [navController toolbarIconButtonForIdentifier:source.identifier];
        if (!activate && button.image != nil) {
          [items addObject:button];
          continue;
        }
        // The screen's source item stays unchanged, so a pop or a cancelled
        // interactive pop can restore that screen's image and action.
        button.primaryAction = source.primaryAction;
        button.target = source.target;
        button.action = source.action;
        button.title = source.title;
        button.image = source.image;
        button.tintColor = source.tintColor;
        button.enabled = source.enabled;
        button.hidden = source.hidden;
        button.selected = source.selected;
        button.accessibilityLabel = source.accessibilityLabel;
        button.identifier = source.identifier;
        button.hidesSharedBackground = source.hidesSharedBackground;
        button.symbolAnimationEnabled = NO;
        [items addObject:button];
      }
      [controller setToolbarItems:items animated:NO];
      return;
    }
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  [controller setToolbarItems:[_toolbarBarButtonItems copy] animated:NO];
}
#endif // !TARGET_OS_TV

- (void)applyItemsWithTitleView:(nullable UIView *)titleView
                   subtitleView:(nullable UIView *)subtitleView
              largeSubtitleView:(nullable UIView *)largeSubtitleView
                  forController:(RNSStackScreenController *)controller
{
  UINavigationItem *navItem = controller.navigationItem;

#if !TARGET_OS_TV
  [self applyToolbarItemsForController:controller];
  navItem.leftItemsSupplementBackButton = YES;
#endif // !TARGET_OS_TV

  [navItem setLeftBarButtonItems:[_leadingBarButtonItems copy] animated:YES];
  [navItem setRightBarButtonItems:[_trailingBarButtonItems copy] animated:YES];

  navItem.titleView = titleView;

#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  if (@available(iOS 26.0, *)) {
    navItem.subtitleView = subtitleView;
    navItem.largeSubtitleView = largeSubtitleView;
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
}

- (void)applyTitleMenuForController:(RNSStackScreenController *)controller
{
#if !TARGET_OS_TV
  if (@available(iOS 16.0, *)) {
    RNSStackHeaderMenuData *titleMenuData = _configDataProvider.titleMenu;
    UINavigationItem *navItem = controller.navigationItem;

    if (titleMenuData == nil) {
      navItem.titleMenuProvider = nil;
      return;
    }

    RNSStackHeaderMenuToggleStateTracker *tracker = [_trackerRegistry trackerForItemId:RNSTitleMenuTrackerItemId];
    __weak auto weakSelf = self;
    __weak auto weakEventsDelegate = _eventsDelegate;
    __weak auto weakImageLoader = _imageLoader;

    navItem.titleMenuProvider = ^UIMenu *(NSArray<UIMenuElement *> *suggestedActions) {
      if (weakEventsDelegate == nil || weakImageLoader == nil) {
        return nil;
      }
      return [RNSStackHeaderMenuCoordinator buildUIMenuFromData:titleMenuData
                                       withHeaderEventsDelegate:weakEventsDelegate
                                                   stateTracker:tracker
                                                withImageLoader:weakImageLoader
                                        menuInvalidatedCallback:^{
                                          [weakSelf reapplyTitleMenu];
                                        }];
    };
  }
#endif // !TARGET_OS_TV
}

- (UIBarButtonItem *)buildBarButtonItemForItem:(id<RNSStackHeaderItemDataProviding>)item
{
  UIBarButtonItem *barButtonItem = [RNSStackHeaderContentFactory barButtonItemForHeaderItem:item
                                                                    withFrameChangeDelegate:_frameChangeDelegate
                                                                   withHeaderEventsDelegate:_eventsDelegate
                                                                            withImageLoader:_imageLoader];

#if RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)
  if (@available(iOS 26.0, *)) {
    if (item.identifier != nil) {
      barButtonItem.identifier = item.identifier;
    }
    barButtonItem.hidesSharedBackground = item.hidesSharedBackground;
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(26_0)

// tvOS and visionOS are excluded on purpose: `visibilityPriority` exists there, but the only
// supported value is `standard`, which is already the default.
#if RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_TV && !TARGET_OS_VISION
  if (@available(iOS 27.0, *)) {
    barButtonItem.visibilityPriority =
        RNSBarButtonItemVisibilityPriorityFromVisibilityPriority(item.visibilityPriority);
  }
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_TV && !TARGET_OS_VISION

  if (item.menu != nil && item.itemId != nil) {
    RNSStackHeaderMenuToggleStateTracker *tracker = [_trackerRegistry trackerForItemId:item.itemId];
    __weak auto weakSelf = self;
    NSString *capturedItemId = item.itemId;
    [RNSStackHeaderMenuCoordinator applyMenu:item.menu
                             toBarButtonItem:barButtonItem
                    withHeaderEventsDelegate:_eventsDelegate
                                stateTracker:tracker
                             withImageLoader:_imageLoader
                     menuInvalidatedCallback:^{
                       [weakSelf reapplyMenuForItemWithId:capturedItemId];
                     }];
  }

  if (item.menuRepresentation != nil && item.itemId != nil) {
    RNSStackHeaderMenuToggleStateTracker *tracker = [_trackerRegistry trackerForItemId:item.itemId];
    __weak auto weakSelf = self;
    NSString *capturedItemId = item.itemId;
    [RNSStackHeaderMenuCoordinator applyMenuRepresentation:item.menuRepresentation
                                           toBarButtonItem:barButtonItem
                                  withHeaderEventsDelegate:_eventsDelegate
                                              stateTracker:tracker
                                           withImageLoader:_imageLoader
                                   menuInvalidatedCallback:^{
                                     [weakSelf reapplyMenuRepresentationForItemWithId:capturedItemId];
                                   }];
  }

  if (item.itemId != nil) {
    _barButtonItemsByItemId[item.itemId] = barButtonItem;
  }

  return barButtonItem;
}

@end

#if RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_TV && !TARGET_OS_VISION
API_AVAILABLE(ios(27.0))
static UIBarButtonItemVisibilityPriority RNSBarButtonItemVisibilityPriorityFromVisibilityPriority(
    RNSHeaderItemVisibilityPriority visibilityPriority)
{
  switch (visibilityPriority) {
    case RNSHeaderItemVisibilityPriorityLow:
      return UIBarButtonItemVisibilityPriorityLow;
    case RNSHeaderItemVisibilityPriorityStandard:
      return UIBarButtonItemVisibilityPriorityStandard;
    case RNSHeaderItemVisibilityPriorityHigh:
      return UIBarButtonItemVisibilityPriorityHigh;
    default:
      RNSLogE(@"[RNScreens] Unsupported visibility priority");
      return UIBarButtonItemVisibilityPriorityStandard;
  }
}
#endif // RNS_IPHONE_OS_VERSION_AVAILABLE(27_0) && !TARGET_OS_TV && !TARGET_OS_VISION
