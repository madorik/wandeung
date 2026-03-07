import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../models/climbing_gym.dart';

final userPositionProvider = FutureProvider<Position?>((ref) async {
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }
  if (permission == LocationPermission.deniedForever) return null;
  try {
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  } catch (_) {
    return null;
  }
});

final searchQueryProvider = StateProvider<String>((ref) => '');

Future<List<ClimbingGym>> _searchGooglePlaces({
  required String searchQuery,
  required String apiKey,
  Position? position,
  bool filterByDistance = false,
}) async {
  final queryParams = <String, String>{
    'query': searchQuery,
    'key': apiKey,
    'language': 'ko',
  };

  if (position != null) {
    queryParams['location'] = '${position.latitude},${position.longitude}';
    queryParams['radius'] = '20000';
  }

  final uri = Uri.https(
    'maps.googleapis.com',
    '/maps/api/place/textsearch/json',
    queryParams,
  );

  final response = await http.get(uri);
  if (response.statusCode != 200) return [];

  final body = jsonDecode(response.body);
  if (body['status'] != 'OK' && body['status'] != 'ZERO_RESULTS') return [];

  final results = (body['results'] as List?) ?? [];

  final gyms = results
      .map((item) {
        final location = item['geometry']?['location'];
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        return ClimbingGym(
          id: null,
          name: item['name'] ?? '',
          address: item['formatted_address'],
          latitude: lat,
          longitude: lng,
        );
      })
      .where((gym) =>
          gym.name.isNotEmpty && gym.latitude != null && gym.longitude != null)
      .toList();

  if (position != null) {
    gyms.sort((a, b) {
      final distA = Geolocator.distanceBetween(
          position.latitude, position.longitude, a.latitude!, a.longitude!);
      final distB = Geolocator.distanceBetween(
          position.latitude, position.longitude, b.latitude!, b.longitude!);
      return distA.compareTo(distB);
    });
    if (filterByDistance) {
      return gyms.where((gym) {
        final dist = Geolocator.distanceBetween(position.latitude,
            position.longitude, gym.latitude!, gym.longitude!);
        return dist <= 20000;
      }).toList();
    }
  }

  return gyms;
}

// 주변 클라이밍장 (GymSelector용 — 위치 기반)
final nearbyGymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final positionFuture = ref.watch(userPositionProvider.future);
  final position = await positionFuture;

  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (apiKey.isEmpty) return [];

  return _searchGooglePlaces(
    searchQuery: '클라이밍짐',
    apiKey: apiKey,
    position: position,
    filterByDistance: position != null,
  );
});

// 지도 화면용: 검색어 없으면 주변, 있으면 텍스트 검색
final gymsProvider = FutureProvider<List<ClimbingGym>>((ref) async {
  final query = ref.watch(searchQueryProvider);

  if (query.isEmpty) {
    return await ref.watch(nearbyGymsProvider.future);
  }

  final positionFuture = ref.watch(userPositionProvider.future);
  final position = await positionFuture;

  final apiKey = dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';
  if (apiKey.isEmpty) return [];

  final searchQuery = query.contains('클라이밍') ? query : '$query 클라이밍짐';

  return _searchGooglePlaces(
    searchQuery: searchQuery,
    apiKey: apiKey,
    position: position,
    filterByDistance: false,
  );
});
