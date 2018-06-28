//
//  MLWMapView.m
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#import "MLWMapView.h"
#include <iostream>


@interface MLWMapView ()
{
	CGFloat _tileSize;
}

@end


@implementation MLWMapView

-(void) setMap:(marlyn::map *)map
{
	_map = map;
	_tileSize = 48.0;
	
	NSRect	box = { { 0, _map->height() * _tileSize }, { _tileSize + 1.0, _tileSize + 1.0 } };
	
	self.layer.backgroundColor = NSColor.lightGrayColor.CGColor;

	for( size_t y = 0; y < _map->height(); ++y )
	{
		box.origin.y -= _tileSize;
		box.origin.x = 0;

		for( size_t x = 0; x < _map->width(); ++x )
		{
			CALayer *theLayer = [CALayer layer];
			theLayer.opaque = NO;
			theLayer.frame = box;
			theLayer.allowsEdgeAntialiasing = NO;
			[self.layer addSublayer:theLayer];
			
			box.origin.x += _tileSize;
		}
	}
	
	for( size_t x = 0; x < _map->actor_count(); ++x )
	{
		CALayer *actorLayer = [CALayer layer];
		actorLayer.frame = NSZeroRect;
		[self.layer addSublayer: actorLayer];
	}
	
	__weak typeof(self) weakSelf = self;
	
	_map->set_tile_changed_handler( ^(marlyn::tile * inTile)
	{
		typeof(self) strongSelf = weakSelf;
		if( strongSelf )
		{
			size_t x = 0, y = 0;
			strongSelf->_map->index_of_tile( inTile, &x, &y );
			
			CALayer * tileLayer = strongSelf.layer.sublayers[x + (y * strongSelf->_map->width())];
			NSImage * clipImage = [self fogOfWarImageAtX: x y: y seen: inTile->is_seen()];
			if( clipImage || inTile->is_seen() )
			{
				tileLayer.contents = [NSImage imageNamed: [NSString stringWithUTF8String: inTile->image_name().c_str()]];
			}
			else
			{
				if( tileLayer.contents != nil )
				{
					NSLog(@"tile was reset to empty ?!");
				}
				tileLayer.contents = nil;
			}
			if( clipImage )
			{
				CALayer *clipLayer = [CALayer layer];
				clipLayer.contents = clipImage;
				clipLayer.frame = (NSRect){ NSZeroPoint, box.size };
				tileLayer.mask = clipLayer;
			}
			else
			{
				tileLayer.mask = nil;
			}
		}
	});
	_map->set_actor_changed_handler( ^( marlyn::actor * inActor )
	{
		typeof(self) strongSelf = weakSelf;
		if( strongSelf )
		{
			marlyn::map * theMap = strongSelf->_map;
			size_t actorIndex = theMap->index_of_actor( inActor );
			size_t actorLayerIndex = theMap->width() * theMap->height() + actorIndex;
			CALayer * actorLayer = strongSelf.layer.sublayers[actorLayerIndex];
			
			actorLayer.frame = (NSRect){ { strongSelf->_tileSize * inActor->x_pos(), strongSelf->_tileSize * (theMap->height() -1 -inActor->y_pos()) }, { strongSelf->_tileSize, strongSelf->_tileSize } };
			actorLayer.contents = [NSImage imageNamed: [NSString stringWithUTF8String: inActor->image_name().c_str()]];

			if( actorIndex == 0 )	// Player?
			{
				theMap->neighbors_at_in_radius( inActor->x_pos(), inActor->y_pos(), inActor->sight_radius(), []( marlyn::tile * inTile )
											   {
												   inTile->set_seen( true );
											   });
				theMap->neighbors_at_in_radius( inActor->x_pos(), inActor->y_pos(), inActor->sight_radius() + 1, [theMap]( marlyn::tile * inTile )
											   {
												   theMap->tile_changed( inTile );
											   });
				theMap->tile_at( inActor->x_pos(), inActor->y_pos() )->set_seen( true );
				
				marlyn::tile * playerTile = theMap->tile_at( inActor->x_pos(), inActor->y_pos() );
				
				marlyn::actor * enemy = theMap->actor_at_index(1);
				marlyn::tile * enemyTile = theMap->tile_at( enemy->x_pos(), enemy->y_pos() );
				marlyn::tile * blockade = theMap->tile_obscuring_view_between_tiles(playerTile, enemyTile, 3);
				
				if( blockade )
				{
					size_t blockadeX = 0, blockadeY = 0;
					theMap->index_of_tile( blockade, &blockadeX, &blockadeY );
					std::cout << "blocking tile: " << blockade->image_name() << blockadeX << "," << blockadeY << std::endl;
				}
				else
				{
					std::cout << "nothing blocked." << std::endl;
				}
			}
		}
	});
	
	[self.widthAnchor constraintEqualToConstant:_map->width() * _tileSize].active = YES;
	[self.heightAnchor constraintEqualToConstant:_map->height() * _tileSize].active = YES;
	
	_map->notify_actors();
}


-(BOOL) acceptsFirstResponder
{
	return YES;
}


-(BOOL) becomeFirstResponder
{
	return YES;
}


-(void) doCommandBySelector:(SEL)selector
{
	if( selector == @selector(moveUp:) )
	{
		_map->move_actor_in_direction(_map->player(), marlyn::north);
	}
	else if( selector == @selector(moveDown:) )
	{
		_map->move_actor_in_direction(_map->player(), marlyn::south);
	}
	else if( selector == @selector(moveRight:) )
	{
		_map->move_actor_in_direction(_map->player(), marlyn::east);
	}
	else if( selector == @selector(moveLeft:) )
	{
		_map->move_actor_in_direction(_map->player(), marlyn::west);
	}
}


-(void) mouseDown:(NSEvent *)event
{
	[self.window makeFirstResponder:self];
}


-(void)keyDown:(NSEvent *)event
{
	[self interpretKeyEvents: @[event]];
}


-(NSImage *) fogOfWarImageAtX: (size_t)x y: (size_t)y seen: (bool)isSeen
{
	marlyn::neighboring_tile flags = _map->seen_neighbor_flags_at(x, y);
	
	__weak typeof(self) weakSelf = self;

	NSImage * img;
	if( isSeen )
	{
		if( (flags & marlyn::all) == marlyn::all )
		{
			return nil;
		}
		
		img = [NSImage imageWithSize: NSMakeSize( _tileSize, _tileSize ) flipped: NO drawingHandler: ^BOOL(NSRect dstRect) {
			typeof(self) strongSelf = weakSelf;
			if( strongSelf )
			{
				NSRect gradientCenterRect = NSMakeRect( 0, 0, strongSelf->_tileSize, strongSelf->_tileSize );
				NSGradient * falloffGradient = [[NSGradient alloc] initWithColors: @[NSColor.blackColor, NSColor.clearColor]];
				[falloffGradient drawFromCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: (strongSelf->_tileSize / 2.0) options: NSGradientDrawsBeforeStartingLocation];

				if( flags & marlyn::south )
				{
					NSRect southRect = NSOffsetRect(gradientCenterRect, 0, -(strongSelf->_tileSize / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southRect), NSMidY(southRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southRect), NSMidY(southRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::south_east) || ((flags & marlyn::south) && (flags & marlyn::east)) )
				{
					NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(strongSelf->_tileSize / 2.0), -(strongSelf->_tileSize / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( flags & marlyn::east )
				{
					NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(strongSelf->_tileSize / 2.0), 0);
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::north_east) || ((flags & marlyn::north) && (flags & marlyn::east)) )
				{
					NSRect northEastRect = NSOffsetRect(gradientCenterRect, +(strongSelf->_tileSize / 2.0), +(strongSelf->_tileSize / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( flags & marlyn::north )
				{
					NSRect northRect = NSOffsetRect(gradientCenterRect, 0, +(strongSelf->_tileSize / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northRect), NSMidY(northRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northRect), NSMidY(northRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::north_west) || ((flags & marlyn::north) && (flags & marlyn::west)) )
				{
					NSRect northWestRect = NSOffsetRect(gradientCenterRect, -(strongSelf->_tileSize / 2.0), +(strongSelf->_tileSize / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( flags & marlyn::west )
				{
					NSRect westRect = NSOffsetRect(gradientCenterRect, -(strongSelf->_tileSize / 2.0), 0);
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(westRect), NSMidY(westRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(westRect), NSMidY(westRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::south_west) || ((flags & marlyn::south) && (flags & marlyn::west)) )
				{
					NSRect southWestRect = NSOffsetRect(gradientCenterRect, -(strongSelf->_tileSize / 2.0), -(strongSelf->_tileSize / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: (strongSelf->_tileSize / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
			}
			return YES;
		}];
	}
	else if( ((flags & marlyn::north) && (flags & marlyn::east))
			|| ((flags & marlyn::north) && (flags & marlyn::west))
			|| ((flags & marlyn::south) && (flags & marlyn::east))
			|| ((flags & marlyn::south) && (flags & marlyn::west)) )
	{
		img = [NSImage imageWithSize: NSMakeSize( _tileSize, _tileSize ) flipped: NO drawingHandler: ^BOOL(NSRect dstRect) {
			typeof(self) strongSelf = weakSelf;
			if( strongSelf )
			{
				[NSGraphicsContext saveGraphicsState];
				NSBezierPath *clipPath = [NSBezierPath bezierPath];
				NSRect gradientCenterRect = NSMakeRect( 0, 0, strongSelf->_tileSize, strongSelf->_tileSize );

				if( ((flags & marlyn::south) && (flags & marlyn::east)) )
				{
					NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(strongSelf->_tileSize / 2.0), -(strongSelf->_tileSize / 2.0));
					[clipPath appendBezierPathWithRect:southEastRect];
				}
				if( ((flags & marlyn::north) && (flags & marlyn::east)) )
				{
					NSRect northEastRect = NSOffsetRect(gradientCenterRect, +(strongSelf->_tileSize / 2.0), +(strongSelf->_tileSize / 2.0));
					[clipPath appendBezierPathWithRect:northEastRect];
				}
				if( ((flags & marlyn::north) && (flags & marlyn::west)) )
				{
					NSRect northWestRect = NSOffsetRect(gradientCenterRect, -(strongSelf->_tileSize / 2.0), +(strongSelf->_tileSize / 2.0));
					[clipPath appendBezierPathWithRect:northWestRect];
				}
				if( ((flags & marlyn::south) && (flags & marlyn::west)) )
				{
					NSRect southWestRect = NSOffsetRect(gradientCenterRect, -(strongSelf->_tileSize / 2.0), -(strongSelf->_tileSize / 2.0));
					[clipPath appendBezierPathWithRect:southWestRect];
				}
				
				[clipPath addClip];

				NSGradient * falloffGradient = [[NSGradient alloc] initWithColors: @[NSColor.clearColor, NSColor.blackColor]];
				[falloffGradient drawFromCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: (strongSelf->_tileSize / 2.3) toCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: (strongSelf->_tileSize / 1.7) options: NSGradientDrawsAfterEndingLocation];

				[NSGraphicsContext restoreGraphicsState];
			}
			return YES;
		}];
	}
	return img;
}

@end
