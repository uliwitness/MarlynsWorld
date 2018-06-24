//
//  AppDelegate.m
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#import "AppDelegate.h"
#import "MLWMapView.h"


@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@property (weak) IBOutlet MLWMapView *mapView;

@end

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	NSString *mapPath = [NSBundle.mainBundle pathForResource:@"map" ofType:@"txt"];
	marlyn::map * theMap = new marlyn::map( mapPath.fileSystemRepresentation );
	self.mapView.map = theMap;
}


- (void)applicationWillTerminate:(NSNotification *)aNotification
{
	// Insert code here to tear down your application
}


@end
