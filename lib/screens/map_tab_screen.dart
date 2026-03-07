import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../models/climbing_gym.dart';
import '../providers/gym_provider.dart';

class MapTabScreen extends ConsumerStatefulWidget {
  const MapTabScreen({super.key});

  @override
  ConsumerState<MapTabScreen> createState() => _MapTabScreenState();
}

class _MapTabScreenState extends ConsumerState<MapTabScreen> {
  GoogleMapController? _controller;
  ClimbingGym? _selectedGym;
  bool _listExpanded = true;
  final _searchController = TextEditingController();
  List<ClimbingGym> _currentGyms = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _moveToCurrentLocation();
  }

  Future<void> _moveToCurrentLocation() async {
    try {
      final position = await ref.read(userPositionProvider.future);
      if (position == null || _controller == null) return;
      _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(position.latitude, position.longitude),
            zoom: 14,
          ),
        ),
      );
    } catch (_) {}
  }

  Set<Marker> _buildMarkers() {
    return _currentGyms
        .where((gym) => gym.latitude != null && gym.longitude != null)
        .map((gym) {
          final isSelected = _selectedGym?.name == gym.name;
          return Marker(
            markerId: MarkerId(gym.name),
            position: LatLng(gym.latitude!, gym.longitude!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              isSelected
                  ? BitmapDescriptor.hueAzure
                  : BitmapDescriptor.hueRed,
            ),
            onTap: () => setState(() => _selectedGym = gym),
          );
        })
        .toSet();
  }

  void _onSearch(String query) {
    ref.read(searchQueryProvider.notifier).state = query.trim();
  }

  void _clearSearch() {
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  Future<void> _selectGym(ClimbingGym gym) async {
    setState(() => _selectedGym = gym);
    if (gym.latitude != null && gym.longitude != null) {
      _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(gym.latitude!, gym.longitude!), 15,
        ),
      );
    }
  }

  String _formatDistance(ClimbingGym gym, Position? position) {
    if (position == null || gym.latitude == null || gym.longitude == null) {
      return '';
    }
    final dist = Geolocator.distanceBetween(
        position.latitude, position.longitude, gym.latitude!, gym.longitude!);
    if (dist < 1000) return '${dist.round()}m';
    return '${(dist / 1000).toStringAsFixed(1)}km';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gymsProvider, (_, next) {
      next.whenData((gyms) {
        setState(() => _currentGyms = gyms);
      });
    });

    final gymsAsync = ref.watch(gymsProvider);

    gymsAsync.whenData((gyms) {
      if (_currentGyms.isEmpty) {
        _currentGyms = gyms;
      }
    });

    final positionAsync = ref.watch(userPositionProvider);
    final searchQuery = ref.watch(searchQueryProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: TextField(
          controller: _searchController,
          textInputAction: TextInputAction.search,
          onSubmitted: _onSearch,
          decoration: InputDecoration(
            hintText: '클라이밍장 검색...',
            prefixIcon: const Icon(Icons.search_rounded, size: 20),
            suffixIcon: searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: _clearSearch,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
            filled: true,
            fillColor: colorScheme.surfaceContainerHighest,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: _listExpanded ? 55 : 90,
            child: Stack(
              children: [
                Positioned.fill(
                  child: GoogleMap(
                    initialCameraPosition: const CameraPosition(
                      target: LatLng(37.5665, 126.9780),
                      zoom: 12,
                    ),
                    markers: _buildMarkers(),
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    onMapCreated: _onMapCreated,
                    onTap: (_) => setState(() => _selectedGym = null),
                  ),
                ),
                if (gymsAsync.isLoading)
                  const Positioned(
                    top: 12,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              ),
                              SizedBox(width: 8),
                              Text('검색 중…',
                                  style: TextStyle(fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            height: _listExpanded ? 260 + bottomPadding : 44,
            decoration: BoxDecoration(
              color: colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () =>
                      setState(() => _listExpanded = !_listExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Text(
                          searchQuery.isEmpty
                              ? '주변 클라이밍장'
                              : '"$searchQuery" 검색 결과',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 6),
                        gymsAsync.when(
                          data: (gyms) => Text(
                            '${gyms.length}곳',
                            style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                        const Spacer(),
                        Icon(
                          _listExpanded
                              ? Icons.keyboard_arrow_down_rounded
                              : Icons.keyboard_arrow_up_rounded,
                          color: colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ],
                    ),
                  ),
                ),

                if (_listExpanded)
                  Expanded(
                    child: gymsAsync.when(
                      data: (gyms) {
                        if (gyms.isEmpty) {
                          return Center(
                            child: Text(
                              '검색 결과가 없습니다',
                              style: TextStyle(
                                  color: colorScheme.onSurface
                                      .withOpacity(0.5)),
                            ),
                          );
                        }
                        final position = positionAsync.value;
                        return ListView.separated(
                          padding:
                              EdgeInsets.only(bottom: bottomPadding + 8),
                          itemCount: gyms.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) {
                            final gym = gyms[index];
                            final isSelected =
                                _selectedGym?.name == gym.name;
                            final dist = _formatDistance(gym, position);
                            return ListTile(
                              dense: true,
                              selected: isSelected,
                              selectedTileColor:
                                  colorScheme.primary.withOpacity(0.08),
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundColor: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.terrain_rounded,
                                  size: 17,
                                  color: isSelected
                                      ? colorScheme.onPrimary
                                      : colorScheme.onSurfaceVariant,
                                ),
                              ),
                              title: Text(
                                gym.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                              subtitle: gym.address != null
                                  ? Text(
                                      gym.address!,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: colorScheme.onSurface
                                            .withOpacity(0.6),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    )
                                  : null,
                              trailing: dist.isNotEmpty
                                  ? Text(
                                      dist,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    )
                                  : null,
                              onTap: () => _selectGym(gym),
                            );
                          },
                        );
                      },
                      loading: () => const Center(
                          child: CircularProgressIndicator()),
                      error: (e, _) => Center(
                        child: Text(
                          '오류가 발생했습니다',
                          style: TextStyle(color: colorScheme.error),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
