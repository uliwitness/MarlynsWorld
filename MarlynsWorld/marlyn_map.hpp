//
//  marlyn_map.hpp
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#pragma once

#include <cstdlib>
#include <string>
#include <vector>
#include <functional>


namespace marlyn
{
	
	class map;
	
	
	enum
	{
		none = 0,
		north = (1 << 0),
		north_east = (1 << 1),
		east = (1 << 2),
		south_east = (1 << 3),
		south = (1 << 4),
		south_west = (1 << 5),
		west = (1 << 6),
		north_west = (1 << 7),
		all = (north | north_east | east | south_east | south | south_west | west | north_west)

	};
	typedef uint8_t neighboring_tile;
	
	
	class tile
	{
	public:
		tile( std::string inImageName, neighboring_tile exits, map * inParent ) : mImageName(inImageName), mExits(exits), mParent(inParent) {}
		
		std::string image_name() 		{ return mImageName; }
		neighboring_tile exits() 		{ return mExits; }

		bool is_seen() 					{ return mIsSeen; }
		void set_seen( bool isSeen );
		
	protected:
		std::string			mImageName;
		bool				mIsSeen = false;
		neighboring_tile	mExits;
		map				*	mParent;
	};
	
	
	class actor
	{
	public:
		actor( std::string inImageName, map * inParent ) : mImageName(inImageName), mParent(inParent) {}
		
		std::string image_name() 		{ return mImageName; }

		size_t		x_pos()	{ return mXPos; }
		void		set_x_pos( size_t n );
		size_t		y_pos()	{ return mYPos; }
		void		set_y_pos( size_t n );

	protected:
		std::string			mImageName;
		size_t  			mXPos = 0;
		size_t				mYPos = 0;
		map				*	mParent;
	};
	
	
	class map
	{
	public:
		map( const char* inFilePath );
		~map();
		
		size_t width() 							{ return mWidth; }
		size_t height() 						{ return mHeight; }
		
		tile * 	tile_at( size_t x, size_t y )	{ return mTiles[y][x]; }
		void	index_of_tile( tile * inTile, size_t * outX, size_t * outY );
		void	neighbors_at( size_t x, size_t y, std::function<void(tile *, neighboring_tile)> visitor);
		neighboring_tile	seen_neighbor_flags_at( size_t x, size_t y );
		
		actor * player()	{ return mPlayer; }

		void set_tile_changed_handler( std::function<void(tile *)> inHandler ) { mTileChangedHandler = inHandler; }
		void tile_changed( tile * inTile ) 		{ if( mTileChangedHandler ) mTileChangedHandler(inTile); };

		void set_actor_changed_handler( std::function<void(actor *)> inHandler ) { mActorChangedHandler = inHandler; }
		void actor_changed( actor * inActor ) 		{ if( mActorChangedHandler ) mActorChangedHandler(inActor); };

	protected:
		size_t mWidth;
		size_t mHeight;
		
		std::vector<std::vector<tile *>> mTiles;
		
		actor * mPlayer;
		
		std::function<void(tile *)> mTileChangedHandler;
		std::function<void(actor *)> mActorChangedHandler;
	};
	
	
}
