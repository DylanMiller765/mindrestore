#import <Foundation/Foundation.h>

#if __has_attribute(swift_private)
#define AC_SWIFT_PRIVATE __attribute__((swift_private))
#else
#define AC_SWIFT_PRIVATE
#endif

/// The resource bundle ID.
static NSString * const ACBundleID AC_SWIFT_PRIVATE = @"com.dylanmiller.mindrestore";

/// The "AccentColor" asset catalog color resource.
static NSString * const ACColorNameAccentColor AC_SWIFT_PRIVATE = @"AccentColor";

/// The "CardBorder" asset catalog color resource.
static NSString * const ACColorNameCardBorder AC_SWIFT_PRIVATE = @"CardBorder";

/// The "CardBorderDark" asset catalog color resource.
static NSString * const ACColorNameCardBorderDark AC_SWIFT_PRIVATE = @"CardBorderDark";

/// The "CardElevated" asset catalog color resource.
static NSString * const ACColorNameCardElevated AC_SWIFT_PRIVATE = @"CardElevated";

/// The "CardSurface" asset catalog color resource.
static NSString * const ACColorNameCardSurface AC_SWIFT_PRIVATE = @"CardSurface";

/// The "PageBg" asset catalog color resource.
static NSString * const ACColorNamePageBg AC_SWIFT_PRIVATE = @"PageBg";

#undef AC_SWIFT_PRIVATE
