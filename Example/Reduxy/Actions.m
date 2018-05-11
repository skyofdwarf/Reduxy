//
//  Actions.m
//  Reduxy_Example
//
//  Created by yjkim on 10/05/2018.
//  Copyright © 2018 skyofdwarf. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "Actions.h"


UIKIT_STATIC_INLINE id action_selector(id self, SEL _cmd) {
    NSMutableArray *names = @[].mutableCopy;
    
    const char *className = class_getName(self);
    const char *selectorName = sel_getName(_cmd);
    
    [names addObject:[NSString stringWithCString:selectorName encoding:NSString.defaultCStringEncoding]];
    [names addObject:[NSString stringWithCString:className encoding:NSString.defaultCStringEncoding]];
    
    Class cls = self;
    
    while ((cls = class_getSuperclass(cls))) {
        const char *className = class_getName(cls);
        
        // ignore NSObject class
        if (class_getSuperclass(cls)) {
            [names addObject:[NSString stringWithCString:className encoding:NSString.defaultCStringEncoding]];
        }
        else {
        }
    }
    
    return [names.reverseObjectEnumerator.allObjects componentsJoinedByString:@"."];
}

static id action_obj_selector(id self, SEL _cmd) {
    return objc_getClass(sel_getName(_cmd));
}

static Class create_action_class(const char *name, Class superClass) {
    Class actionClass = objc_getClass(name);
    
    if (!actionClass) {
        actionClass = objc_allocateClassPair(superClass, name, 0);
        objc_registerClassPair(actionClass);
    }
    else {
    }
    return actionClass;
}


@implementation raction
+ (void)register:(NSString *)keypath {
    NSArray<NSString *> *tokens = [keypath componentsSeparatedByString:@"."];
    if (tokens.count == 1) {
        const char *selectorName = [tokens.firstObject cStringUsingEncoding:NSString.defaultCStringEncoding];
        SEL selector = sel_getUid(selectorName);
        class_addMethod(object_getClass(self), selector, (IMP)action_selector, "@:@");
    }
    else if (tokens.count > 1) {
        const char *selectorName = [tokens.firstObject cStringUsingEncoding:NSString.defaultCStringEncoding];
        
        Class actionClass = create_action_class(selectorName, self);
        
        SEL selector = sel_getUid(selectorName);
        class_addMethod(object_getClass(self), selector, (IMP)action_obj_selector, "@:@");
        
        NSArray<NSString *> *rest = [tokens subarrayWithRange:NSMakeRange(1, tokens.count - 1)];
        
        [actionClass register:[rest componentsJoinedByString:@"."]];
    }
}

+ (ReduxyActionType)expand:(NSString *)keypath {
    NSArray<NSString *> *tokens = [keypath componentsSeparatedByString:@"."];
    
    if (tokens.count == 1) {
        const char *selectorName = [tokens.firstObject cStringUsingEncoding:NSString.defaultCStringEncoding];
        
        SEL sel = sel_getUid(selectorName);
        
        if (class_respondsToSelector(object_getClass(self), sel)) {
            return objc_msgSend(self, sel);
        }
        else {
            [NSException raise:NSInvalidArgumentException
                        format:@"unregistered action sent: %@(%@)", tokens.firstObject, keypath];
            return nil;
        }
    }
    else if (tokens.count > 1) {
        const char *selectorName = [tokens.firstObject cStringUsingEncoding:NSString.defaultCStringEncoding];
        NSArray<NSString *> *restComponents = [tokens subarrayWithRange:NSMakeRange(1, tokens.count - 1)];
        
        NSString *rest = [restComponents componentsJoinedByString:@"."];
        
        SEL sel = sel_getUid(selectorName);
        
        if (class_respondsToSelector(object_getClass(self), sel)) {
            Class cls = objc_msgSend(self, sel);
            return [cls expand:rest];
        }
        else {
            [NSException raise:NSInvalidArgumentException
                        format:@"unregistered action object sent: %@(%@)", tokens.firstObject, keypath];
            return nil;
        }
    }
    
    [NSException raise:NSInvalidArgumentException
                format:@"invalid keypath sent: %@", keypath];
    
    return nil;
}

@end
