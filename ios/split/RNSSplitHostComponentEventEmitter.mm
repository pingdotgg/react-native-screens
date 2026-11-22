#import "RNSSplitHostComponentEventEmitter.h"
#import <React/RCTConversions.h>
#import <React/RCTLog.h>
#import "RNSConversions-SplitView.h"

@implementation RNSSplitHostComponentEventEmitter {
  std::shared_ptr<const react::RNSSplitHostEventEmitter> _reactEventEmitter;
}

- (BOOL)emitOnCollapse
{
  if (_reactEventEmitter != nullptr) {
    _reactEventEmitter->onCollapse({});
    return YES;
  } else {
    RCTLogWarn(@"[RNScreens] Skipped OnCollapse event emission due to nullish emitter");
    return NO;
  }
}

- (BOOL)emitOnDisplayModeWillChangeFrom:(UISplitViewControllerDisplayMode)currentDisplayMode
                                     to:(UISplitViewControllerDisplayMode)nextDisplayMode
                    horizontalSizeClass:(UIUserInterfaceSizeClass)horizontalSizeClass
{
  if (_reactEventEmitter != nullptr) {
    using EventSizeClass = react::RNSSplitHostEventEmitter::OnDisplayModeWillChangeHorizontalSizeClass;
    EventSizeClass eventSizeClass;
    switch (horizontalSizeClass) {
      case UIUserInterfaceSizeClassCompact:
        eventSizeClass = EventSizeClass::Compact;
        break;
      case UIUserInterfaceSizeClassRegular:
        eventSizeClass = EventSizeClass::Regular;
        break;
      case UIUserInterfaceSizeClassUnspecified:
      default:
        eventSizeClass = EventSizeClass::Unspecified;
        break;
    }
    _reactEventEmitter->onDisplayModeWillChange(
        {.currentDisplayMode = rnscreens::conversion::UISplitViewControllerDisplayModeToString(currentDisplayMode),
         .nextDisplayMode = rnscreens::conversion::UISplitViewControllerDisplayModeToString(nextDisplayMode),
         .horizontalSizeClass = eventSizeClass});
    return YES;
  } else {
    RCTLogWarn(@"[RNScreens] Skipped OnDisplayModeWillChange event emission due to nullish emitter");
    return NO;
  }
}

- (BOOL)emitOnExpand
{
  if (_reactEventEmitter != nullptr) {
    _reactEventEmitter->onExpand({});
    return YES;
  } else {
    RCTLogWarn(@"[RNScreens] Skipped OnExpand event emission due to nullish emitter");
    return NO;
  }
}

- (BOOL)emitOnHideInspector
{
  if (_reactEventEmitter != nullptr) {
    _reactEventEmitter->onInspectorHide({});
    return YES;
  } else {
    RCTLogWarn(@"[RNScreens] Skipped OnHideInspector event emission due to nullish emitter");
    return NO;
  }
}

- (void)updateEventEmitter:(const std::shared_ptr<const react::RNSSplitHostEventEmitter> &)emitter
{
  _reactEventEmitter = emitter;
}

@end
