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
		tile( std::string inImageName, map * inParent ) : mImageName(inImageName), mParent(inParent) {}
		
		std::string image_name() 		{ return mImageName; }
		
		bool is_seen() 					{ return mIsSeen; }
		void set_seen( bool isSeen );
		
	protected:
		std::string mImageName;
		bool mIsSeen = false;
		map * mParent;
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
		void	neighbors_at( size_t x, size_t y, std::function<void(tile*,neighboring_tile)> visitor);
		neighboring_tile	seen_neighbor_flags_at( size_t x, size_t y );

		void set_tile_changed_handler( std::function<void(tile *)> inHandler ) { mTileChangedHandler = inHandler; }
		void tile_changed( tile * inTile ) 		{ if( mTileChangedHandler ) mTileChangedHandler(inTile); };
		
	protected:
		size_t mWidth;
		size_t mHeight;
		
		std::vector<std::vector<tile *>> mTiles;
		
		std::function<void(tile *)> mTileChangedHandler;
	};
	
	
}
