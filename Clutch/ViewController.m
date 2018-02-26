//
//  ViewController.m
//  Clutch
//
//  Created by Harrison White on 2/25/18.
//  Copyright © 2018 RCX LLC. All rights reserved.
//

#import "ViewController.h"
#import "clutch.h"

@interface ViewController ()

@property (nonatomic, strong) IBOutlet NSPopUpButton* interfaceDropdown;

@end

@implementation ViewController

- (IBAction)bindToInterfaceClicked:(id)sender {
    NSInteger index = _interfaceDropdown.indexOfSelectedItem - 1; /* - 1 because of initial placeholder "Select interface..." */
    
    kClutchInterface* ifs = NULL;
    getInterfaces(&ifs);
    
    kClutchInterface* interface = ifs;
    
    for (int i = 0; i < index; i++) {
        interface = interface->next;
    }
    
    [Clutch bindToInterface:interface];
    
    freeInterfaces(ifs);
}

- (void)populateInterfaceDropdown {
    kClutchInterface* ifs = NULL;
    getInterfaces(&ifs);
    
    NSMutableArray* interfaceNames = [[NSMutableArray alloc]init];
    for (kClutchInterface* i = ifs; i != NULL; i = i->next) {
        NSString* name = [NSString stringWithFormat:@"%s: %s (%s)", i->name, i->address, i->ipv4 ? "IPv4" : "IPv6"];
        NSLog(@"adding %@...", name);
        [interfaceNames addObject:name];
    }
    
    freeInterfaces(ifs);
    
    [_interfaceDropdown addItemsWithTitles:interfaceNames];
}

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    
    [self populateInterfaceDropdown];
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
