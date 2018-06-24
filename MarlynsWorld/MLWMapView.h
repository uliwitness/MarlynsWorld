//
//  MLWMapView.h
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#include "marlyn_map.hpp"


NS_ASSUME_NONNULL_BEGIN

@interface MLWMapView : NSView

@property (nonatomic, assign) marlyn::map *map;

@end

NS_ASSUME_NONNULL_END
