//
//  marlyn_map.cpp
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#include "marlyn_map.hpp"
#include <fstream>


using namespace marlyn;


void	tile::set_seen( bool isSeen )
{
	mIsSeen = isSeen;
	mParent->tile_changed( this );
	size_t x, y;
	mParent->index_of_tile( this, &x, &y );
	
	map * parent = mParent;
	
	mParent->neighbors_at(x, y, [parent](tile * inTile, neighboring_tile flag)
						  {
							  if( inTile->is_seen() )
							  {
								  parent->tile_changed( inTile ); // Let parent update fog of war for this tile.
							  }
						  });
}


map::map( const char* inFilePath )
{
	std::fstream theFile( inFilePath, std::ios_base::in );
	
	theFile >> mWidth;
	theFile >> mHeight;
	
	for( size_t y = 0; y < mHeight; ++y)
	{
		std::vector<tile *> row;
		
		for( size_t x = 0; x < mWidth; ++x)
		{
			std::string imageName;
			theFile >> imageName;
			
			row.push_back( new tile(imageName, this) );
		}
		mTiles.push_back(row);
	}
	
	theFile.close();
}


map::~map()
{
	for( size_t y = 0; y < mHeight; ++y)
	{
		for( size_t x = 0; x < mWidth; ++x)
		{
			delete mTiles[y][x];
		}
	}
}


void	map::index_of_tile( tile * inTile, size_t * outX, size_t * outY )
{
	for( size_t y = 0; y < mHeight; ++y)
	{
		for( size_t x = 0; x < mWidth; ++x)
		{
			if( mTiles[y][x] == inTile )
			{
				*outX = x;
				*outY = y;
				return;
			}
		}
	}
}


neighboring_tile	map::seen_neighbor_flags_at( size_t x, size_t y )
{
	neighboring_tile flags = none;
	neighbors_at( x, y, [&flags]( tile * inTile, neighboring_tile inFlags )
	{
		if( inTile->is_seen() )
		{
			flags |= inFlags;
		}
	});
	
	return flags;
}


void	map::neighbors_at( size_t x, size_t y, std::function<void(tile*,neighboring_tile)> visitor)
{
	if( x > 0 )
	{
		visitor(mTiles[y][x - 1], west);
	}
	if( y > 0 )
	{
		visitor(mTiles[y - 1][x], north);
	}
	if( x > 0 && y > 0 )
	{
		visitor(mTiles[y - 1][x - 1], north_west);
	}
	if( x < (mWidth - 1) && y > 0 )
	{
		visitor(mTiles[y - 1][x + 1], north_east);
	}

	if( y < (mHeight - 1) )
	{
		visitor(mTiles[y + 1][x], south);
	}
	if( x < (mWidth - 1) )
	{
		visitor(mTiles[y][x + 1], east);
	}

	if( x < (mWidth - 1) && y < (mHeight - 1) )
	{
		visitor(mTiles[y + 1][x + 1], south_east);
	}
	if( x > 0 && y < (mHeight - 1) )
	{
		visitor(mTiles[y + 1][x - 1], south_west);
	}
}
