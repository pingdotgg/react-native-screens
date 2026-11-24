import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

// Compile the production update method against a recording navigation controller.
// This verifies that one React replacement never starts competing UIKit transitions.
const source = readFileSync(
  new URL(
    '../../ios/core/containers/stack/container/RNSStackNavigationController.mm',
    import.meta.url,
  ),
  'utf8',
);
const method = source.slice(
  source.indexOf('- (void)commitTransaction'),
  source.indexOf('#pragma mark - Debug'),
);
const directory = mkdtempSync(join(tmpdir(), 'rns-stack-replacement-'));
try {
  writeFileSync(
    join(directory, 'test.mm'),
    `
#import <Foundation/Foundation.h>
@compatibility_alias UIViewController NSObject;
#define RNSAssert(condition, message, ...) NSCAssert(condition, message)
@interface RNSPopOperation : NSObject
@property NSObject *screenController;
@end
@implementation RNSPopOperation
@end
@interface RNSPushOperation : RNSPopOperation
@end
@implementation RNSPushOperation
@end
@interface Navigation : NSObject {
@public
  NSMutableArray<RNSPushOperation *> *_pendingPushOperations;
  NSMutableArray<RNSPopOperation *> *_pendingPopOperations;
  BOOL _performingReactUpdate;
}
@property NSMutableArray *viewControllers;
@property NSMutableArray *transitions;
- (void)commitTransaction;
@end
@implementation Navigation
- (BOOL)hasPendingOperations { return _pendingPushOperations.count || _pendingPopOperations.count; }
- (NSObject *)topViewController { return self.viewControllers.lastObject; }
- (void)prepareToolbarForController:(NSObject *)controller {}
- (void)dumpStackModel {}
- (void)setViewControllers:(NSArray *)controllers animated:(BOOL)animated {
  self.viewControllers = [controllers mutableCopy];
  if (animated) [self.transitions addObject:@"set"];
}
- (void)popViewControllerAnimated:(BOOL)animated {
  [self.viewControllers removeLastObject];
  if (animated) [self.transitions addObject:@"pop"];
}
- (void)pushViewController:(NSObject *)controller animated:(BOOL)animated {
  [self.viewControllers addObject:controller];
  if (animated) [self.transitions addObject:@"push"];
}
${method}
@end
static Navigation *navigation(NSArray *controllers) {
  Navigation *n = [Navigation new]; n.viewControllers = [controllers mutableCopy];
  n.transitions = [NSMutableArray new];
  n->_pendingPushOperations = [NSMutableArray new]; n->_pendingPopOperations = [NSMutableArray new];
  return n;
}
static void pop(Navigation *n, NSString *name) {
  RNSPopOperation *op = [RNSPopOperation new]; op.screenController = name; [n->_pendingPopOperations addObject:op];
}
static void push(Navigation *n, NSString *name) {
  RNSPushOperation *op = [RNSPushOperation new]; op.screenController = name; [n->_pendingPushOperations addObject:op];
}
int main() { @autoreleasepool {
  Navigation *n = navigation(@[@"home", @"pr", @"chooser", @"local"]);
  pop(n, @"local"); pop(n, @"chooser"); pop(n, @"pr"); push(n, @"draft");
  [n commitTransaction];
  NSCAssert(([n.viewControllers isEqual:@[@"home", @"draft"]]), @"replacement destination");
  NSCAssert([n.transitions isEqual:@[@"set"]], @"replacement must have one atomic transition, got %@", n.transitions);
  NSCAssert(!n.hasPendingOperations, @"replacement must drain operations");
  NSCAssert(!n->_performingReactUpdate, @"replacement must finish the React update");
  n = navigation(@[@"home"]); pop(n, @"home"); push(n, @"draft"); [n commitTransaction];
  NSCAssert(([n.viewControllers isEqual:@[@"draft"]] && [n.transitions isEqual:@[@"set"]]), @"root replacement");
  n = navigation(@[@"home", @"draft", @"chooser"]); pop(n, @"chooser"); [n commitTransaction];
  NSCAssert(([n.viewControllers isEqual:@[@"home", @"draft"]] && [n.transitions isEqual:@[@"pop"]]), @"ordinary back unchanged");
  n = navigation(@[@"home"]); push(n, @"draft"); [n commitTransaction];
  NSCAssert(([n.viewControllers isEqual:@[@"home", @"draft"]] && [n.transitions isEqual:@[@"push"]]), @"ordinary push unchanged");
  puts("4 stack update scenarios passed");
} }
`,
  );
  execFileSync(
    'xcrun',
    [
      'clang++',
      '-std=c++20',
      '-fobjc-arc',
      '-framework',
      'Foundation',
      join(directory, 'test.mm'),
      '-o',
      join(directory, 'test'),
    ],
    { stdio: 'inherit' },
  );
  execFileSync(join(directory, 'test'), { stdio: 'inherit' });
} finally {
  rmSync(directory, { recursive: true, force: true });
}
