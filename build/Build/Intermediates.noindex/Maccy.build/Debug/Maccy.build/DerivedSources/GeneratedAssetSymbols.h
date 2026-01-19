#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The "StatusBarMenuImage" asset catalog image resource.
static NSString * const ACImageNameStatusBarMenuImage AC_SWIFT_PRIVATE = @"StatusBarMenuImage";

/// The "clipboard.fill" asset catalog image resource.
static NSString * const ACImageNameClipboardFill AC_SWIFT_PRIVATE = @"clipboard.fill";

/// The "paperclip" asset catalog image resource.
static NSString * const ACImageNamePaperclip AC_SWIFT_PRIVATE = @"paperclip";

/// The "scissors" asset catalog image resource.
static NSString * const ACImageNameScissors AC_SWIFT_PRIVATE = @"scissors";

#undef AC_SWIFT_PRIVATE
