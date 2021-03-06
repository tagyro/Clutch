//
//  Clutch.m
//  Clutch
//
//  Created by Harrison White on 2/25/18.
//  Copyright © 2018 Harrison White. All rights reserved.
//

/*
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "Clutch.h"
#import <SystemConfiguration/SystemConfiguration.h>

#define _GNU_SOURCE /* To get defns of NI_MAXSERV and NI_MAXHOST */
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netdb.h>
#include <ifaddrs.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

// You need to DISABLE the App Sandbox in "capabilities" in the Xcode project before things
// like editing other apps' preferences, killing other processes, etc. will function properly

NSString* kGroupPreferencesID       = @"8TSRGQJRTM.group.com.rcx.clutch";
NSString* kTransmissionBundleID     = @"org.m0k.transmission";

NSString* kBindInterfaceKey         = @"BindInterface";

// NSRunningApplication -isTerminated
NSString* kAppTerminatedKeyPath     = @"isTerminated";

NSString* kBindAddressIPv4Key       = @"BindAddressIPv4";
NSString* kBindAddressIPv6Key       = @"BindAddressIPv6";

static void *kAppTerminatedContext  = &kAppTerminatedContext;

@implementation ClutchInterface

// make serializable for storing in NSUserDefaults
- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:_name forKey:@"name"];
    [coder encodeObject:_address forKey:@"address"];
    [coder encodeBool:_ipv4 forKey:@"ipv4"];
}

- (id)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _name       = [coder decodeObjectForKey:@"name"];
        _address    = [coder decodeObjectForKey:@"address"];
        _ipv4       = [coder decodeBoolForKey:@"ipv4"];
    }
    return self;
}

@end

@interface Clutch ()

@property (nonatomic, strong) NSUserDefaults* transmissionDefaults;

// this must be retained here so we can observe when it is terminated
// otherwise, ARC will release it while a key-value observer is registered and crash the app
@property (nonatomic, strong) NSMutableArray<NSRunningApplication *>* transmissionInstances;

@end

@implementation Clutch

- (id)init {
    self = [super init];
    if (self) {
        _clutchGroupDefaults = [[NSUserDefaults alloc]initWithSuiteName:kGroupPreferencesID];
        _transmissionDefaults = [[NSUserDefaults alloc]initWithSuiteName:kTransmissionBundleID];
        
        _transmissionInstances = [[NSMutableArray alloc]init];
    }
    return self;
}

- (ClutchInterface *)getBindInterface {
    NSData *data = [_clutchGroupDefaults objectForKey:kBindInterfaceKey];
    return data ? [NSKeyedUnarchiver unarchiveObjectWithData:data] : nil;
}

- (BOOL)unbindFromInterface {
    NSUserDefaults* transmissionDefaults = [self transmissionDefaults];
    [transmissionDefaults removeObjectForKey:kBindAddressIPv4Key];
    [transmissionDefaults removeObjectForKey:kBindAddressIPv6Key];
    [transmissionDefaults synchronize];
    
    [_clutchGroupDefaults removeObjectForKey:kBindInterfaceKey];
    [_clutchGroupDefaults synchronize];
    
    return [self restartTransmission];
}

- (BOOL)bindToInterface:(ClutchInterface *)interface {
    NSUserDefaults* transmissionDefaults = [self transmissionDefaults];
    if (interface.ipv4) {
        [transmissionDefaults removeObjectForKey:kBindAddressIPv6Key];
        [transmissionDefaults setObject:interface.address forKey:kBindAddressIPv4Key];
    }
    else {
        [transmissionDefaults removeObjectForKey:kBindAddressIPv4Key];
        [transmissionDefaults setObject:interface.address forKey:kBindAddressIPv6Key];
    }
    [transmissionDefaults synchronize];
    
    [_clutchGroupDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:interface] forKey:kBindInterfaceKey];
    [_clutchGroupDefaults synchronize];
    
    return [self restartTransmission];
}

- (BOOL)bindToInterfaceWithName:(NSString *)name {
    // update bind address
    
    // Apple docs say specifying another app's identifier will return its preferences (assuming there is NO sandbox in place)
    // https://developer.apple.com/documentation/foundation/nsuserdefaults/1409957-initwithsuitename
    
    // Alternative solution
    /*
    NSString *writeCmd = [@"/usr/bin/defaults write org.m0k.transmission BindAddressIPv4 " stringByAppendingString:interface.address];
    NSLog(@"writeCmd %@", writeCmd);
    if (system([writeCmd cStringUsingEncoding:NSASCIIStringEncoding]) != 0) {
        return NO;
    }
    */
    
    // bind to the first interface with the given name
    
    ClutchInterface* bindInterface = nil;
    
    for (ClutchInterface* interface in [self getInterfaces]) {
        if ([interface.name isEqualToString:name]) {
            bindInterface = interface;
            break;
        }
    }
    
    if (!bindInterface) {
        // important!
        // if an interface with the given name does NOT exist, bind to localhost to block traffic until it comes back up
        
        // create localhost placeholder interface
        bindInterface = [[ClutchInterface alloc]init];
        bindInterface.name = name;
        bindInterface.address = @"127.0.0.1";
        bindInterface.ipv4 = YES;
    }
    
    return [self bindToInterface:bindInterface];
}

- (BOOL)restartTransmission {
    // alternative solution
    // system("/usr/bin/killall Transmission 2>/dev/null");
    
    // close Transmission if it's running
    
    // retain these NSRunningApplication instances
    // otherwise they will be released by ARC while we're still observing them to see when they terminate and crash the app
    [_transmissionInstances addObjectsFromArray:[NSRunningApplication runningApplicationsWithBundleIdentifier:kTransmissionBundleID]];
    
    for (NSRunningApplication* app in _transmissionInstances) {
        [app addObserver:self forKeyPath:kAppTerminatedKeyPath options:NSKeyValueObservingOptionNew context:kAppTerminatedContext];
        
        // if plain -terminate was used, Transmission would present an "are you sure" dialog that would prevent the app from quitting
        [app forceTerminate];
    }
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
    
    if (context == kAppTerminatedContext) {
        // we no longer need to observe the "isTerminated" property
        // must remove observers before releasing the object
        [object removeObserver:self forKeyPath:kAppTerminatedKeyPath context:kAppTerminatedContext];
        
        // we no longer need to retain this NSRunningApplication instance
        [_transmissionInstances removeObject:object];
        
        // relaunch Transmission since it was running
        [[NSWorkspace sharedWorkspace]launchApplication:@"Transmission"];
        
    } else {
        // Any unrecognized context must belong to super
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

// I was looking for a way to get a callback when a utun interface changed.
// I looked here but didn't find anything that worked for this purpose:
// https://developer.apple.com/library/content/technotes/tn1145/_index.html
// So I'm using a polling timer instead

// getifaddrs code from:
// http://man7.org/linux/man-pages/man3/getifaddrs.3.html

- (NSArray *)getInterfaces {
    // SCNetworkInterfaceCopyAll doesn't list utun interfaces!
    /*
    NSArray *ifs = (__bridge NSArray *)SCNetworkInterfaceCopyAll();
    
    for (int i = 0; i < [ifs count]; i++) {
        SCNetworkInterfaceRef interface = (__bridge SCNetworkInterfaceRef)[ifs objectAtIndex:i];
        NSString *name = (__bridge NSString *)SCNetworkInterfaceGetBSDName(interface);
        NSLog(@"got name %@", name);
    }
    */
    
    NSMutableArray* interfaces = [[NSMutableArray alloc]init];
    
    struct ifaddrs *ifaddr, *ifa;
    int family, s, n;
    char host[NI_MAXHOST];
    
    if (getifaddrs(&ifaddr) == -1) {
        fprintf(stderr, "getifaddrs");
        
        // error getting interfaces; return empty array
        return interfaces;
    }
    
    /* Walk through linked list, maintaining head pointer so we
     can free list later */
    
    for (ifa = ifaddr, n = 0; ifa != NULL; ifa = ifa->ifa_next, n++) {
        if (ifa->ifa_addr == NULL)
            continue;
        
        family = ifa->ifa_addr->sa_family;
        
        /* For an AF_INET* interface address, display the address */
        
        if (family == AF_INET || family == AF_INET6) {
            s = getnameinfo(ifa->ifa_addr,
                            (family == AF_INET) ? sizeof(struct sockaddr_in) :
                            sizeof(struct sockaddr_in6),
                            host, NI_MAXHOST,
                            NULL, 0, NI_NUMERICHOST);
            if (s != 0) {
                printf("getnameinfo() failed: %s\n", gai_strerror(s));
                continue;
            }
            
            /* Display interface name and family (including symbolic
             form of the latter for the common families) */
            
            // printf("%-8s %s (%d)\n", ifa->ifa_name, (family == AF_INET) ? "AF_INET" : "AF_INET6", family);
            // printf("\t\taddress: <%s>\n", host);
            
            /* create new Clutch interface object */
            
            ClutchInterface* interface = [[ClutchInterface alloc]init];
            interface.name      = [NSString stringWithCString:ifa->ifa_name encoding:NSASCIIStringEncoding];
            interface.address   = [NSString stringWithCString:host encoding:NSASCIIStringEncoding];
            interface.ipv4      = (family == AF_INET);
            
            [interfaces addObject:interface];
        }
    }
    
    freeifaddrs(ifaddr);
    
    return interfaces;
}

@end
