//
//  YeetbarLoader.m
//  Yeetbar
//
//  Simple Objective-C loader that calls Swift initialization
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

// Forward declare the Swift function
extern void yeetbar_swift_init(void);

@interface YeetbarLoader : NSObject
@end

@implementation YeetbarLoader

+ (void)load {
    NSLog(@"[Yeetbar] Objective-C +load method called");
    yeetbar_swift_init();
}

@end