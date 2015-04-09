#pragma once

#include "dataSource.h"
#include "mapTile.h"
#include "tileData.h"


class ProtobufSource : public NetworkDataSource {

public:

    virtual std::shared_ptr<TileData> parse(const MapTile& _tile, std::stringstream& _in) override;

    ProtobufSource();

};
