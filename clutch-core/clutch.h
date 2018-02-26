//
//  clutch.h
//  Clutch
//
//  Created by Harrison White on 2/25/18.
//  Copyright © 2018 RCX LLC. All rights reserved.
//

#ifndef clutch_h
#define clutch_h

#include <stdbool.h>

typedef struct kClutchInterfaceStruct {
    struct kClutchInterfaceStruct* next;
    char* name;
    char* address;
    bool ipv4;
} kClutchInterface;

void getInterfaces(kClutchInterface** interfaces);
void freeInterfaces(kClutchInterface* interfaces);

// objc

#include <Cocoa/Cocoa.h>

@interface Clutch : NSObject

+ (BOOL)bindToInterface:(kClutchInterface *)interface;

@end

#endif /* clutch_h */
