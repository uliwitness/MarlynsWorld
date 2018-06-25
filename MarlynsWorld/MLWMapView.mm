//
//  MLWMapView.m
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#import "MLWMapView.h"


@interface MLWMapView ()
{
	CALayer * _playerLayer;
}

@end


@implementation MLWMapView

-(void) setMap:(marlyn::map *)map
{
	_map = map;
	
	NSRect	box = { { 0, _map->height() * 48.0 }, { 49.0, 49.0 } };
	
	self.layer.backgroundColor = NSColor.lightGrayColor.CGColor;

	for( size_t y = 0; y < _map->height(); ++y )
	{
		box.origin.y -= 48.0;
		box.origin.x = 0;

		for( size_t x = 0; x < _map->width(); ++x )
		{
			CALayer *theLayer = [CALayer layer];
			theLayer.opaque = NO;
			theLayer.frame = box;
			theLayer.allowsEdgeAntialiasing = NO;
			[self.layer addSublayer:theLayer];
			
			box.origin.x += 48.0;
		}
	}
	
	_playerLayer = [CALayer layer];
	_playerLayer.contents = [NSImage imageNamed: [NSString stringWithUTF8String:_map->player()->image_name().c_str()]];
	_playerLayer.frame = NSZeroRect;
	[self.layer addSublayer:_playerLayer];

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
			strongSelf->_playerLayer.frame = (NSRect){ { 48.0 * inActor->x_pos(), 48.0 * (theMap->height() -1 -inActor->y_pos()) }, { 48.0, 48.0 } };
			theMap->neighbors_at_in_radius( inActor->x_pos(), inActor->y_pos(), 1, []( marlyn::tile * inTile )
			{
				inTile->set_seen( true );
			});
			theMap->neighbors_at_in_radius( inActor->x_pos(), inActor->y_pos(), 1 + 1, [theMap]( marlyn::tile * inTile )
													 {
														 theMap->tile_changed(inTile);
													 });
			theMap->tile_at( inActor->x_pos(), inActor->y_pos() )->set_seen( true );
		}
	});
	
	[self.widthAnchor constraintEqualToConstant:_map->width() * 48.0].active = YES;
	[self.heightAnchor constraintEqualToConstant:_map->height() * 48.0].active = YES;
	
	_map->actor_changed( _map->player() );
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
	
	if( (flags & marlyn::all) == marlyn::all )
	{
		return nil;
	}
	
	__weak typeof(self) weakSelf = self;

	NSImage * img;
	if( isSeen )
	{
		img = [NSImage imageWithSize: NSMakeSize( 48.0, 48.0 ) flipped: NO drawingHandler: ^BOOL(NSRect dstRect) {
			typeof(self) strongSelf = weakSelf;
			if( strongSelf )
			{
				NSRect gradientCenterRect = NSMakeRect( 0, 0, 48.0, 48.0 );
				NSGradient * falloffGradient = [[NSGradient alloc] initWithColors: @[NSColor.blackColor, NSColor.clearColor]];
				[falloffGradient drawFromCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: (48.0 / 2.0) options: NSGradientDrawsBeforeStartingLocation];

				if( flags & marlyn::south )
				{
					NSRect southRect = NSOffsetRect(gradientCenterRect, 0, -(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southRect), NSMidY(southRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southRect), NSMidY(southRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::south_east) || ((flags & marlyn::south) && (flags & marlyn::east)) )
				{
					NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), -(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( flags & marlyn::east )
				{
					NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), 0);
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::north_east) || ((flags & marlyn::north) && (flags & marlyn::east)) )
				{
					NSRect northEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), +(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( flags & marlyn::north )
				{
					NSRect northRect = NSOffsetRect(gradientCenterRect, 0, +(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northRect), NSMidY(northRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northRect), NSMidY(northRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::north_west) || ((flags & marlyn::north) && (flags & marlyn::west)) )
				{
					NSRect northWestRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), +(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( flags & marlyn::west )
				{
					NSRect westRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), 0);
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(westRect), NSMidY(westRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(westRect), NSMidY(westRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( (flags & marlyn::south_west) || ((flags & marlyn::south) && (flags & marlyn::west)) )
				{
					NSRect southWestRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), -(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
			}
			return YES;
		}];
	}
	else if( ((flags & marlyn::north) && (flags & marlyn::east) && (flags & marlyn::south) == 0 && (flags & marlyn::west) == 0)
			|| ((flags & marlyn::north) && (flags & marlyn::east) == 0 && (flags & marlyn::south) == 0 && (flags & marlyn::west))
			|| ((flags & marlyn::north) == 0 && (flags & marlyn::east) && (flags & marlyn::south) && (flags & marlyn::west) == 0)
			|| ((flags & marlyn::north) == 0 && (flags & marlyn::east) == 0 && (flags & marlyn::south) && (flags & marlyn::west)) )
	{
		img = [NSImage imageWithSize: NSMakeSize( 48.0, 48.0 ) flipped: NO drawingHandler: ^BOOL(NSRect dstRect) {
			typeof(self) strongSelf = weakSelf;
			if( strongSelf )
			{
				NSRect gradientCenterRect = NSMakeRect( 0, 0, 48.0, 48.0 );
				NSGradient * falloffGradient = [[NSGradient alloc] initWithColors: @[NSColor.blackColor, NSColor.clearColor]];

				if( ((flags & marlyn::south) && (flags & marlyn::east)) )
				{
					NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), -(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( ((flags & marlyn::north) && (flags & marlyn::east)) )
				{
					NSRect northEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), +(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( ((flags & marlyn::north) && (flags & marlyn::west)) )
				{
					NSRect northWestRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), +(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
				if( ((flags & marlyn::south) && (flags & marlyn::west)) )
				{
					NSRect southWestRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), -(48.0 / 2.0));
					[falloffGradient drawFromCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
				}
			}
			return YES;
		}];
	}
	return img;
}

@end
