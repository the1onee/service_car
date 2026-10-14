import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

/// بلاطات OSM مع كاش قرص عبر [CachedNetworkImageProvider].
class CachedOsmTileProvider extends TileProvider {
  CachedOsmTileProvider({Map<String, String>? headers})
      : super(
          headers: headers != null
              ? Map<String, String>.from(headers)
              : <String, String>{},
        );

  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    final url = getTileUrl(coordinates, options);
    return CachedNetworkImageProvider(
      url,
      headers: headers.isEmpty ? null : Map<String, String>.from(headers),
    );
  }
}
