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
	size_t playerX;
	size_t playerY;
}

@end


@implementation MLWMapView

-(void) setMap:(marlyn::map *)map
{
	_map = map;
	
	NSRect	box = { NSZeroPoint, { 48.0, 48.0 } };
	
	self.layer.backgroundColor = NSColor.lightGrayColor.CGColor;

	for( size_t y = 0; y < _map->height(); ++y )
	{
		for( size_t x = 0; x < _map->width(); ++x )
		{
			CALayer *theLayer = [CALayer layer];
			theLayer.opaque = NO;
			theLayer.frame = box;
			[self.layer addSublayer:theLayer];
			
			box.origin.x += box.size.width;
		}
		
		box.origin.x = 0;
		box.origin.y += box.size.height;
	}
	
	box.origin.x = 48.0 * playerX;
	box.origin.y = 48.0 * playerY;

	_playerLayer = [CALayer layer];
	_playerLayer.contents = [NSImage imageNamed: @"marlyn_south"];
	_playerLayer.frame = box;
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
			if( inTile->is_seen() )
			{
				tileLayer.contents = [NSImage imageNamed: [NSString stringWithUTF8String: inTile->image_name().c_str()]];
				NSImage * clipImage = [self fogOfWarImageAtX: x y: y];
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
			else
			{
				tileLayer.mask = nil;
			}
		}
	});
	
	[self.widthAnchor constraintEqualToConstant:_map->width() * 48.0].active = YES;
	[self.heightAnchor constraintEqualToConstant:_map->height() * 48.0].active = YES;
	
	_map->tile_at( playerX, playerY )->set_seen( true );
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
		if( playerY < (_map->height() - 1) )
		{
			playerY += 1;
			_playerLayer.frame = (NSRect){ { 48.0 * playerX,  48.0 * playerY }, { 48.0, 48.0 } };
			_map->tile_at( playerX, playerY )->set_seen( true );
		}
	}
	else if( selector == @selector(moveDown:) )
	{
		if( playerY > 0 )
		{
			playerY -= 1;
			_playerLayer.frame = (NSRect){ { 48.0 * playerX,  48.0 * playerY }, { 48.0, 48.0 } };
			_map->tile_at( playerX, playerY )->set_seen( true );
		}
	}
	else if( selector == @selector(moveRight:) )
	{
		if( playerX < (_map->width() - 1) )
		{
			playerX += 1;
			_playerLayer.frame = (NSRect){ { 48.0 * playerX,  48.0 * playerY }, { 48.0, 48.0 } };
			_map->tile_at( playerX, playerY )->set_seen( true );
		}
	}
	else if( selector == @selector(moveLeft:) )
	{
		if( playerX > 0 )
		{
			playerX -= 1;
			_playerLayer.frame = (NSRect){ { 48.0 * playerX,  48.0 * playerY }, { 48.0, 48.0 } };
			_map->tile_at( playerX, playerY )->set_seen( true );
		}
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


-(NSImage *) fogOfWarImageAtX: (size_t)x y: (size_t)y
{
	marlyn::neighboring_tile flags = _map->seen_neighbor_flags_at(x, y);
	
	if( (flags & marlyn::all) == marlyn::all )
	{
		return nil;
	}
	
	__weak typeof(self) weakSelf = self;

	NSImage * img = [NSImage imageWithSize: NSMakeSize( 48.0, 48.0 ) flipped: NO drawingHandler: ^BOOL(NSRect dstRect) {
		typeof(self) strongSelf = weakSelf;
		if( strongSelf )
		{
			NSRect gradientCenterRect = NSMakeRect( 0, 0, 48.0, 48.0 );
			NSGradient * falloffGradient = [[NSGradient alloc] initWithColors: @[NSColor.blackColor, NSColor.clearColor]];
			[falloffGradient drawFromCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(gradientCenterRect), NSMidY(gradientCenterRect)) radius: (48.0 / 2.0) options: NSGradientDrawsBeforeStartingLocation];
			
			strongSelf->_map->neighbors_at( x, y, ^( marlyn::tile* inTile, marlyn::neighboring_tile pos )
										   {
											   if (pos & marlyn::north && inTile->is_seen())
											   {
												   NSRect northRect = NSOffsetRect(gradientCenterRect, 0, -(48.0 / 2.0));
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(northRect), NSMidY(northRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northRect), NSMidY(northRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::north_east && inTile->is_seen())
											   {
												   NSRect northEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), -(48.0 / 2.0));
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northEastRect), NSMidY(northEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::east && inTile->is_seen())
											   {
												   NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), 0);
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::south_east && inTile->is_seen())
											   {
												   NSRect southEastRect = NSOffsetRect(gradientCenterRect, +(48.0 / 2.0), +(48.0 / 2.0));
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southEastRect), NSMidY(southEastRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::south && inTile->is_seen())
											   {
												   NSRect southRect = NSOffsetRect(gradientCenterRect, 0, +(48.0 / 2.0));
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(southRect), NSMidY(southRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southRect), NSMidY(southRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::south_west && inTile->is_seen())
											   {
												   NSRect southWestRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), +(48.0 / 2.0));
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(southWestRect), NSMidY(southWestRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::west && inTile->is_seen())
											   {
												   NSRect westRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), 0);
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(westRect), NSMidY(westRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(westRect), NSMidY(westRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
											   else if (pos & marlyn::north_west && inTile->is_seen())
											   {
												   NSRect northWestRect = NSOffsetRect(gradientCenterRect, -(48.0 / 2.0), -(48.0 / 2.0));
												   [falloffGradient drawFromCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: 10.0 toCenter: NSMakePoint(NSMidX(northWestRect), NSMidY(northWestRect)) radius: (48.0 / 1.9) options: NSGradientDrawsBeforeStartingLocation];
											   }
										   });
		}
		return YES;
	}];
	return img;
}

@end
