//
//  marlyn_map.cpp
//  MarlynsWorld
//
//  Created by Uli Kusterer on 24.06.18.
//  Copyright © 2018 Uli Kusterer. All rights reserved.
//

#include "marlyn_map.hpp"
#include <fstream>
#include <map>


using namespace marlyn;


void	actor::set_x_pos( size_t n )
{
	mXPos = n;
	mParent->actor_changed(this);
}


void	actor::set_y_pos( size_t n )
{
	mYPos = n;
	mParent->actor_changed(this);
}


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
	
	std::map<std::string, neighboring_tile> tileExits;
	
	size_t numTileInfos;
	theFile >> numTileInfos;
	for( size_t x = 0; x < numTileInfos; ++x )
	{
		std::string tilename;
		std::string tileInfos;
		
		theFile >> tilename;
		theFile >> tileInfos;
		
		neighboring_tile flags = none;
		if( tileInfos.find("N") != std::string::npos )
		{
			flags |= north;
		}
		if( tileInfos.find("E") != std::string::npos )
		{
			flags |= east;
		}
		if( tileInfos.find("S") != std::string::npos )
		{
			flags |= south;
		}
		if( tileInfos.find("W") != std::string::npos )
		{
			flags |= west;
		}
		tileExits[tilename] = flags;
	}
	
	size_t numActors;
	theFile >> numActors;
	assert(numActors == 1);
	
	std::string actorName;
	theFile >> actorName;
	
	size_t actorX, actorY;
	theFile >> actorX;
	theFile >> actorY;

	mPlayer = new actor( actorName, this );
	mPlayer->set_x_pos(actorX);
	mPlayer->set_y_pos(actorY);
	
	theFile >> mWidth;
	theFile >> mHeight;
	
	for( size_t y = 0; y < mHeight; ++y)
	{
		std::vector<tile *> row;
		
		for( size_t x = 0; x < mWidth; ++x)
		{
			std::string imageName;
			theFile >> imageName;
			
			tile * newTile = new tile(imageName, tileExits[imageName], this);
			row.push_back( newTile );
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


void	map::move_actor_in_direction( actor * inActor, neighboring_tile inDirection )
{
	tile * actorTile = tile_at( inActor->x_pos(), inActor->y_pos() );
	if( (actorTile->exits() & inDirection) == 0 )
	{
		return;	// Can't walk that way.
	}
	
	size_t newX = inActor->x_pos(), newY = inActor->y_pos();
	
	if( inDirection & south )
	{
		if( newY < (mHeight - 1) )
		{
			newY += 1;
		}
	}
	else if( inDirection & north )
	{
		if( newY > 0 )
		{
			newY -= 1;
		}
	}
	if( inDirection & east )
	{
		if( newX < (mWidth - 1) )
		{
			newX += 1;
		}
	}
	else if( inDirection & west )
	{
		if( newX > 0 )
		{
			newX -= 1;
		}
	}

	tile * newActorTile = tile_at( newX, newY );
	if( actorTile != newActorTile )
	{
		// Check if destination tile has a matching exit:
		//	Handy for implementing doors, no matter what side you're coming from,
		//	only the door has to block things, not the tile next to it.
		
		if( (inDirection & north) && (newActorTile->exits() & south) == 0 )
		{
			return;
		}
		if( (inDirection & south) && (newActorTile->exits() & north) == 0 )
		{
			return;
		}
		if( (inDirection & east) && (newActorTile->exits() & west) == 0 )
		{
			return;
		}
		if( (inDirection & west) && (newActorTile->exits() & east) == 0 )
		{
			return;
		}

		inActor->set_x_pos( newX );
		inActor->set_y_pos( newY );
	}
}
