import 'package:customer/utils/json_parsers.dart';

class PlaceSuggestionsModel {
  bool? error;
  String? message;
  PlaceSuggestionsData? data;

  PlaceSuggestionsModel({this.error, this.message, this.data});

  PlaceSuggestionsModel.fromJson(Map<String, dynamic> json) {
    error = parseBool(json['error']);
    message = parseString(json['message']);
    data = json['data'] is Map<String, dynamic>
        ? PlaceSuggestionsData.fromJson(json['data'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['error'] = error;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    return data;
  }
}

class PlaceSuggestionsData {
  List<Suggestions>? suggestions;

  PlaceSuggestionsData({this.suggestions});

  PlaceSuggestionsData.fromJson(Map<String, dynamic> json) {
    final rawSuggestions = json['suggestions'];
    if (rawSuggestions is List) {
      suggestions = rawSuggestions
          .map((v) => Suggestions.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (suggestions != null) {
      data['suggestions'] = suggestions!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Suggestions {
  PlacePrediction? placePrediction;

  Suggestions({this.placePrediction});

  Suggestions.fromJson(Map<String, dynamic> json) {
    placePrediction = json['placePrediction'] is Map<String, dynamic>
        ? PlacePrediction.fromJson(
            json['placePrediction'] as Map<String, dynamic>,
          )
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (placePrediction != null) {
      data['placePrediction'] = placePrediction!.toJson();
    }
    return data;
  }
}

class PlacePrediction {
  String? place;
  String? placeId;
  Text? text;
  StructuredFormat? structuredFormat;
  List<String>? types;

  PlacePrediction({
    this.place,
    this.placeId,
    this.text,
    this.structuredFormat,
    this.types,
  });

  PlacePrediction.fromJson(Map<String, dynamic> json) {
    place = parseString(json['place']);
    placeId = parseString(json['placeId']);
    text = json['text'] is Map<String, dynamic>
        ? Text.fromJson(json['text'] as Map<String, dynamic>)
        : null;
    structuredFormat = json['structuredFormat'] is Map<String, dynamic>
        ? StructuredFormat.fromJson(
            json['structuredFormat'] as Map<String, dynamic>,
          )
        : null;
    types = json['types'] is List
        ? (json['types'] as List).map((e) => e.toString()).toList()
        : <String>[];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['place'] = place;
    data['placeId'] = placeId;
    if (text != null) {
      data['text'] = text!.toJson();
    }
    if (structuredFormat != null) {
      data['structuredFormat'] = structuredFormat!.toJson();
    }
    data['types'] = types;
    return data;
  }
}

class Text {
  String? text;
  List<Matches>? matches;

  Text({this.text, this.matches});

  Text.fromJson(Map<String, dynamic> json) {
    text = parseString(json['text']);
    final rawMatches = json['matches'];
    if (rawMatches is List) {
      matches = rawMatches
          .map((v) => Matches.fromJson(v as Map<String, dynamic>))
          .toList();
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['text'] = text;
    if (matches != null) {
      data['matches'] = matches!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class Matches {
  int? endOffset;

  Matches({this.endOffset});

  Matches.fromJson(Map<String, dynamic> json) {
    endOffset = parseInt(json['endOffset']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['endOffset'] = endOffset;
    return data;
  }
}

class StructuredFormat {
  Text? mainText;
  SecondaryText? secondaryText;

  StructuredFormat({this.mainText, this.secondaryText});

  StructuredFormat.fromJson(Map<String, dynamic> json) {
    mainText = json['mainText'] is Map<String, dynamic>
        ? Text.fromJson(json['mainText'] as Map<String, dynamic>)
        : null;
    secondaryText = json['secondaryText'] is Map<String, dynamic>
        ? SecondaryText.fromJson(json['secondaryText'] as Map<String, dynamic>)
        : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (mainText != null) {
      data['mainText'] = mainText!.toJson();
    }
    if (secondaryText != null) {
      data['secondaryText'] = secondaryText!.toJson();
    }
    return data;
  }
}

class SecondaryText {
  String? text;

  SecondaryText({this.text});

  SecondaryText.fromJson(Map<String, dynamic> json) {
    text = parseString(json['text']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['text'] = text;
    return data;
  }
}

class PlaceDetails {
  final String placeId;
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String area;
  final String road;

  const PlaceDetails({
    required this.placeId,
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    this.area = '',
    this.road = '',
  });

  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    // Backend proxies new Google Places API v1 — response wrapped in 'data'
    final data =
        json['data'] as Map<String, dynamic>? ??
        json['result'] as Map<String, dynamic>? ??
        json;

    // New Places API: location.latitude/longitude (not geometry.location.lat/lng)
    final loc =
        data['location'] as Map<String, dynamic>? ??
        (data['geometry'] as Map<String, dynamic>?)?['location']
            as Map<String, dynamic>? ??
        {};

    // New API: addressComponents with longText/shortText; old: address_components with long_name
    final components =
        (data['addressComponents'] as List<dynamic>?) ??
        (data['address_components'] as List<dynamic>?) ??
        [];

    String city = '',
        state = '',
        country = '',
        postalCode = '',
        area = '',
        road = '';
    for (final c in components) {
      final comp = c as Map<String, dynamic>;
      final types =
          (comp['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final longName =
          (comp['longText'] ?? comp['long_name'])?.toString() ?? '';
      if (types.contains('locality')) city = longName;
      if (types.contains('administrative_area_level_1')) state = longName;
      if (types.contains('country')) country = longName;
      if (types.contains('postal_code')) postalCode = longName;
      if (area.isEmpty &&
          (types.contains('sublocality') ||
              types.contains('sublocality_level_1') ||
              types.contains('sublocality_level_2'))) {
        area = longName;
      }
      if (types.contains('route')) road = longName;
    }

    return PlaceDetails(
      placeId:
          (data['id'] ?? data['place_id'] ?? json['place_id'])?.toString() ??
          '',
      formattedAddress:
          (data['formattedAddress'] ?? data['formatted_address'])?.toString() ??
          '',
      latitude:
          double.tryParse((loc['latitude'] ?? loc['lat'])?.toString() ?? '0') ??
          0.0,
      longitude:
          double.tryParse(
            (loc['longitude'] ?? loc['lng'])?.toString() ?? '0',
          ) ??
          0.0,
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
      area: area,
      road: road,
    );
  }
}

class GeocodingResult {
  final String formattedAddress;
  final double latitude;
  final double longitude;
  final String city;
  final String state;
  final String country;
  final String postalCode;
  final String area;
  final String road;

  const GeocodingResult({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
    required this.city,
    required this.state,
    required this.country,
    required this.postalCode,
    this.area = '',
    this.road = '',
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    final wrapper = json['data'] as Map<String, dynamic>? ?? json;
    final results = wrapper['results'] as List<dynamic>?;
    final first = results != null && results.isNotEmpty
        ? results.first as Map<String, dynamic>
        : wrapper;

    final geometry = first['geometry'] as Map<String, dynamic>? ?? {};
    final location = geometry['location'] as Map<String, dynamic>? ?? {};
    final components = (first['address_components'] as List<dynamic>?) ?? [];

    String city = '',
        state = '',
        country = '',
        postalCode = '',
        area = '',
        road = '';
    for (final c in components) {
      final comp = c as Map<String, dynamic>;
      final types =
          (comp['types'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      final longName = comp['long_name']?.toString() ?? '';
      if (types.contains('locality')) city = longName;
      if (types.contains('administrative_area_level_1')) state = longName;
      if (types.contains('country')) country = longName;
      if (types.contains('postal_code')) postalCode = longName;
      if (types.contains('sublocality') ||
          types.contains('sublocality_level_1')) {
        area = longName;
      }
      if (types.contains('route')) road = longName;
    }

    // Top result is often a POI/plus_code entry missing a component (eg.
    // postal_code, locality) even when sibling results for the same point
    // have it — fall back to scanning the rest of the results list.
    String findInOtherResults(String type) {
      if (results == null) return '';
      for (final res in results) {
        final comps =
            (res as Map<String, dynamic>)['address_components']
                as List<dynamic>? ??
            [];
        for (final c in comps) {
          final comp = c as Map<String, dynamic>;
          final types =
              (comp['types'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              [];
          if (types.contains(type)) {
            return comp['long_name']?.toString() ?? '';
          }
        }
      }
      return '';
    }

    if (postalCode.isEmpty) {
      postalCode = findInOtherResults('postal_code');
    }
    if (city.isEmpty) {
      city = findInOtherResults('locality');
    }

    return GeocodingResult(
      formattedAddress: first['formatted_address']?.toString() ?? '',
      latitude: double.tryParse(location['lat']?.toString() ?? '0') ?? 0.0,
      longitude: double.tryParse(location['lng']?.toString() ?? '0') ?? 0.0,
      city: city,
      state: state,
      country: country,
      postalCode: postalCode,
      area: area,
      road: road,
    );
  }
}
