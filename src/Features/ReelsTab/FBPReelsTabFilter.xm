// Experimental, isolated filter for the bottom tab bar.
// Assumption to verify on device: the Reels tab has bookmarkID "2392950137".
// Do not modify Facebook's global tabs or Facebook Plus's long-press hooks.

#import "FBPlus.h"
#import <objc/runtime.h>

// Set to NO to disable this experiment without altering any other feature.
static const BOOL kFBPReelsTabFilterEnabled = YES;
static NSString *const kFBPReelsTabBookmarkID = @"2392950137";

static NSArray *FBPMenuItemsWithoutReels(NSArray *items) {
    if (!kFBPReelsTabFilterEnabled || ![items isKindOfClass:[NSArray class]]) return items;

    NSMutableArray *kept = nil;
    NSUInteger index = 0;
    for (id item in items) {
        BOOL isReels = NO;
        SEL getter = @selector(bookmarkID);
        if (item && [item respondsToSelector:getter]) {
            // The private model isn't available at compile time. Use its IMP,
            // avoiding KVC exceptions and assumptions about its concrete class.
            IMP imp = [item methodForSelector:getter];
            if (imp) {
                id (*invoke)(id, SEL) = (id (*)(id, SEL))imp;
                id identifier = invoke(item, getter);
                isReels = [identifier isKindOfClass:[NSString class]] &&
                    [identifier isEqualToString:kFBPReelsTabBookmarkID];
            }
        }
        if (isReels) {
            if (!kept) {
                kept = [NSMutableArray arrayWithCapacity:items.count - 1];
                if (index) [kept addObjectsFromArray:[items subarrayWithRange:NSMakeRange(0, index)]];
            }
        } else if (kept) {
            [kept addObject:item];
        }
        index++;
    }
    // Preserve the exact original array when nothing was filtered.
    return kept ? [kept copy] : items;
}

%group FBPReelsTabFilter
%hook FBTabBarViewController
- (void)setMenuItems:(NSArray *)items {
    %orig(FBPMenuItemsWithoutReels(items));
}
%end
%end

void FBPInitReelsTabFilter(void) {
    Class controller = objc_getClass("FBTabBarViewController");
    if (controller && class_getInstanceMethod(controller, @selector(setMenuItems:))) {
        FBP_ONCE(gReelsTabFilterInstalled) { %init(FBPReelsTabFilter); }
    }
}
