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
#include <cmath>
#include <climits>


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
	size_t x = 0, y = 0;
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


struct tile_info
{
	neighboring_tile mExits;
	bool mBlocks;
};


map::map( const char* inFilePath )
{
	std::fstream theFile( inFilePath, std::ios_base::in );
	
	std::map<std::string, tile_info> tileExits;

	size_t numTileInfos;
	theFile >> numTileInfos;
	for( size_t x = 0; x < numTileInfos; ++x )
	{
		std::string tilename;
		std::string tileInfos;
		std::string tileBlockInfos;

		theFile >> tilename;
		theFile >> tileInfos;
		
		tile_info tileInfo = { none, false };
		if( tileInfos.find("N") != std::string::npos )
		{
			tileInfo.mExits |= north;
		}
		if( tileInfos.find("E") != std::string::npos )
		{
			tileInfo.mExits |= east;
		}
		if( tileInfos.find("S") != std::string::npos )
		{
			tileInfo.mExits |= south;
		}
		if( tileInfos.find("W") != std::string::npos )
		{
			tileInfo.mExits |= west;
		}

		theFile >> tileBlockInfos;
		tileInfo.mBlocks = tileBlockInfos.compare("X") == 0;

		tileExits[tilename] = tileInfo;
	}
	
	size_t numActors;
	theFile >> numActors;
	
	for( size_t x = 0; x < numActors; ++x )
	{
		std::string actorName;
		theFile >> actorName;
		
		size_t actorX, actorY;
		theFile >> actorX;
		theFile >> actorY;
		
		actor * newActor = new actor( actorName, this );
		newActor->set_x_pos(actorX);
		newActor->set_y_pos(actorY);
		mActors.push_back( newActor );
	}
	
	mPlayer = mActors.front();
	
	theFile >> mWidth;
	theFile >> mHeight;
	
	for( size_t y = 0; y < mHeight; ++y)
	{
		std::vector<tile *> row;
		
		for( size_t x = 0; x < mWidth; ++x)
		{
			std::string imageName;
			theFile >> imageName;
			
			tile * newTile = new tile(imageName, tileExits[imageName].mExits, tileExits[imageName].mBlocks, this);
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

	for( actor * currActor : mActors )
	{
		delete currActor;
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


void	map::neighbors_at_in_radius( size_t centerX, size_t centerY, size_t radius, std::function<void(tile *)> visitor)
{
	size_t startX = (centerX > radius) ? centerX - radius : 0;
	size_t startY = (centerY > radius) ? centerY - radius : 0;
	size_t maxX = std::min(centerX + radius + 1, mWidth);
	size_t maxY = std::min(centerY + radius + 1, mHeight);
	
	for( size_t y = startY; y < maxY; ++y )
	{
		for( size_t x = startX; x < maxX; ++x )
		{
			double xDistance = std::fabs( double(centerX) - double(x) );
			double yDistance = std::fabs( double(centerY) - double(y) );
			double crowFlightDistance = sqrt( xDistance * xDistance + yDistance * yDistance );
			
			if( crowFlightDistance <= radius )
			{
				visitor(mTiles[y][x]);
			}
		}
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


tile *	map::tile_obscuring_view_between_tiles( tile * inCloserTile, tile * inObscuredTile, size_t inMaxDistance )
{
	size_t x1 = 0, y1 = 0, x2 = 0, y2 = 0;
	index_of_tile( inCloserTile, &x1, &y1 );
	index_of_tile( inObscuredTile, &x2, &y2 );
	
	size_t	minX = std::min(x1,x2), minY = std::min(y1,y2),
			maxX = std::max(x1,x2), maxY = std::max(y1,y2);
	
	double xDistance = std::fabs( double(x1) - double(x2) );
	double yDistance = std::fabs( double(y1) - double(y2) );
	double maxDistance = std::min( double(inMaxDistance), sqrt( xDistance * xDistance + yDistance * yDistance ) );

	tile * foundTile = NULL;
	double foundTileDistance = std::numeric_limits<double>::max();
	

	if( xDistance == 0.0 ) // vertical line.
	{
		for( size_t y = minY; y < maxY; ++y )
		{
			tile * candidateTile = mTiles[y][x1];
			if( candidateTile->blocks() )
			{
				yDistance = std::fabs( double(y1) - double(y) );
				
				if( yDistance < foundTileDistance && yDistance < maxDistance )
				{
					foundTile = candidateTile;
					foundTileDistance = yDistance;
				}
			}
		}
	}
	else if( yDistance == 0 ) // horizontal line
	{
		for( size_t x = minX; x < maxX; ++x )
		{
			tile * candidateTile = mTiles[y1][x];
			if( candidateTile->blocks() )
			{
				xDistance = std::fabs( double(x1) - double(x) );
				
				if( xDistance < foundTileDistance && xDistance < maxDistance )
				{
					foundTile = candidateTile;
					foundTileDistance = xDistance;
				}
			}
		}
	}
	else
	{
		double m = yDistance / xDistance;
		
		for( size_t y = minY; y <= maxY; ++y )
		{
			for( size_t x = minX; x <= maxX; ++x )
			{
				tile * candidateTile = mTiles[y][x];
				if( candidateTile->blocks() )
				{
					double calculatedY = (m * x) - (m * x2) + y1;
					if( std::abs(calculatedY - y) < 0.001 )
					{
						xDistance = std::fabs( double(x1) - double(x) );
						yDistance = std::fabs( double(y1) - double(y) );
						double crowFlightDistance = sqrt( xDistance * xDistance + yDistance * yDistance );
						
						if( crowFlightDistance < foundTileDistance && crowFlightDistance < maxDistance )
						{
							foundTile = candidateTile;
							foundTileDistance = crowFlightDistance;
						}
					}
				}
			}
		}
	}

	return foundTile;
}
