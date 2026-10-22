import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/ui_strings.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/network/api_client.dart';
import '../../models/map_report.dart';
import '../../models/user_session.dart';
import '../../services/google_maps_config_service.dart';
import '../../services/location_service.dart';
import '../../services/map_distance_service.dart';
import '../../services/map_service.dart';
import '../../services/community_service.dart';
import '../reports/community_report_detail_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.isActive,
    this.session,
    this.authToken,
    this.mapService,
  });
  final bool isActive;
  final UserSession? session;
  final String? authToken;
  final MapService? mapService;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapService _service;
  final _locationService = LocationService();
  final _searchController = TextEditingController();
  GoogleMapController? _controller;
  Timer? _pollTimer;
  List<MapReportMarker> _reports = const [];
  LatLng? _userLocation;
  LatLng? _searchLocation;
  String? _filter, _error, _locationError, _searchedAddress;
  bool _configured = false;
  bool _checkingConfiguration = true;
  bool _loading = false;
  bool _refreshing = false;
  bool _searching = false;
  bool _locating = false;
  bool _openingReport = false;
  MapType _mapType = MapType.normal;
  static const _filters = [
    'My reports',
    'Resolved',
    'In Progress',
    'Issue Raised',
    'Verification pending',
    'Invalid Report',
  ];
  static const _defaultPosition = LatLng(19.0760, 72.8777);

  @override
  void initState() {
    super.initState();
    _service =
        widget.mapService ?? MapService(ApiClient(authToken: widget.authToken));
    _checkConfiguration();
    if (widget.isActive) _activate();
  }

  Future<void> _checkConfiguration() async {
    final configured = await GoogleMapsConfigService().isConfigured();
    if (mounted) {
      setState(() {
        _configured = configured;
        _checkingConfiguration = false;
      });
    }
  }

  void _activate() {
    if (const bool.fromEnvironment('FLUTTER_TEST') &&
        widget.mapService == null) {
      return;
    }
    _refresh();
    if (_userLocation == null && !const bool.fromEnvironment('FLUTTER_TEST')) {
      _locate();
    }
    _pollTimer ??= Timer.periodic(Duration(seconds: 15), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _activate();
    } else if (!widget.isActive) {
      _pollTimer?.cancel();
      _pollTimer = null;
    }
  }

  Future<void> _refresh() async {
    if (_refreshing || !mounted || !widget.isActive) return;
    _refreshing = true;
    if (_reports.isEmpty) setState(() => _loading = true);
    try {
      final reports = await _service.getAllReports();
      if (mounted) {
        setState(() {
          _reports = reports;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _refreshing = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _locate() async {
    if (_locating) return;
    setState(() {
      _locating = true;
      _locationError = null;
    });
    try {
      final location = await _locationService.currentLocation();
      if (!mounted) return;
      final coordinates = LatLng(location.latitude, location.longitude);
      setState(() => _userLocation = coordinates);
      await _moveCamera(coordinates);
    } catch (error) {
      if (mounted) {
        setState(
          () => _locationError = error is LocationException
              ? error.message
              : 'Unable to get your location. Enable location services and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final locations = await Geocoding().locationFromAddress(query.trim());
      if (locations.isEmpty) throw FormatException('Location not found');
      final coordinates = LatLng(
        locations.first.latitude,
        locations.first.longitude,
      );
      if (!mounted) return;
      setState(() {
        _searchLocation = coordinates;
        _searchedAddress = query.trim();
        _error = null;
      });
      await _moveCamera(coordinates);
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Location not found. Try a street, city or postal code.',
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _moveCamera(LatLng target) async {
    try {
      await _controller?.animateCamera(CameraUpdate.newLatLngZoom(target, 15));
    } catch (_) {
      // A tab can close while the map camera is moving.
    }
  }

  List<MapReportMarker> get _visibleReports {
    final reports = MapReportMarker.visibleFor(
      _reports,
      filter: _filter,
      userId: widget.session?.id,
    );
    final center = _searchLocation ?? _userLocation;
    if (center != null) {
      reports.sort(
        (a, b) => _distance(center, a).compareTo(_distance(center, b)),
      );
    }
    return reports;
  }

  double _distance(LatLng center, MapReportMarker report) => MapDistance.meters(
    center.latitude,
    center.longitude,
    report.latitude,
    report.longitude,
  );

  Set<Marker> get _markers => {
    ..._visibleReports.map(
      (report) => Marker(
        markerId: MarkerId(report.id),
        position: LatLng(report.latitude, report.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(report.markerHue),
        infoWindow: InfoWindow(
          title: report.issue.isEmpty
              ? UiStrings.of(context).status(report.status)
              : UiStrings.of(context).category(report.issue),
          snippet: UiStrings.of(context).status(report.status),
        ),
        onTap: () => _openReport(report),
      ),
    ),
    if (_userLocation != null)
      Marker(
        markerId: MarkerId('user-location'),
        position: _userLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: InfoWindow(
          title: UiStrings.of(context).text('Your location'),
        ),
      ),
    if (_searchLocation != null)
      Marker(
        markerId: MarkerId('searched-location'),
        position: _searchLocation!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueViolet),
        infoWindow: InfoWindow(title: _searchedAddress),
      ),
  };

  Future<void> _openReport(MapReportMarker marker) async {
    if (_openingReport) return;
    setState(() => _openingReport = true);
    try {
      final service = CommunityService(ApiClient(authToken: widget.authToken));
      final report = await service.getReport(marker.id);
      if (!mounted) return;
      setState(() => _openingReport = false);
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CommunityReportDetailScreen(
            report: report,
            session: widget.session,
            authToken: widget.authToken,
            service: service,
          ),
        ),
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UiStrings.of(context).text(error.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _openingReport = false);
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Widget _controls() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.all(12),
        child: Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(16),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: _search,
            decoration: InputDecoration(
              hintText: UiStrings.of(context).text('Search a location'),
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              suffixIcon: _searching
                  ? Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      onPressed: () => _search(_searchController.text),
                      icon: Icon(Icons.arrow_forward),
                    ),
            ),
          ),
        ),
      ),
      SizedBox(
        height: 42,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [null, ..._filters]
              .map(
                (filter) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      UiStrings.of(context).text(filter ?? 'All reports'),
                    ),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    ],
  );

  Widget _fallback() => Column(
    children: [
      _controls(),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.map_outlined, size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        UiStrings.of(context).text('Map preview unavailable'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      SizedBox(height: 4),
                      Text(
                        UiStrings.of(context).text(
                          'Google Maps is not configured yet. Browse reports and their locations below.',
                        ),
                      ),
                      if (_searchedAddress != null)
                        Text(
                          UiStrings.of(context).format('Nearest to {address}', {
                            'address': _searchedAddress,
                          }),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: _loading
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 84),
                  itemCount: _visibleReports.isEmpty
                      ? 1
                      : _visibleReports.length,
                  separatorBuilder: (_, _) => SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    if (_visibleReports.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          UiStrings.of(
                            context,
                          ).text('No reports match this filter.'),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final report = _visibleReports[index];
                    final center = _searchLocation ?? _userLocation;
                    return Card(
                      child: ListTile(
                        leading: Icon(
                          Icons.location_on,
                          color: report.status == 'Resolved'
                              ? Colors.green
                              : Colors.orange,
                        ),
                        title: Text(
                          report.issue.isEmpty
                              ? report.id
                              : UiStrings.of(context).category(report.issue),
                        ),
                        subtitle: Text(
                          '${UiStrings.of(context).status(report.status)}\n${center == null ? '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}' : UiStrings.of(context).format('{distance} km away', {'distance': (_distance(center, report) / 1000).toStringAsFixed(1)})}',
                        ),
                        isThreeLine: true,
                        trailing: Icon(Icons.chevron_right),
                        onTap: () => _openReport(report),
                      ),
                    );
                  },
                ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    if (_checkingConfiguration) {
      return Center(child: CircularProgressIndicator());
    }
    final nativeMap =
        _configured && !const bool.fromEnvironment('FLUTTER_TEST');
    return Stack(
      children: [
        if (nativeMap) ...[
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _searchLocation ?? _userLocation ?? _defaultPosition,
              zoom: 12,
            ),
            mapType: _mapType,
            markers: _markers,
            circles: {
              if (_userLocation != null)
                Circle(
                  circleId: CircleId('nearby-radius'),
                  center: _userLocation!,
                  radius: 200,
                  strokeWidth: 1,
                  strokeColor: Colors.blue.withValues(alpha: .5),
                  fillColor: Colors.blue.withValues(alpha: .08),
                ),
            },
            onMapCreated: (controller) {
              _controller = controller;
              if (_userLocation != null) _moveCamera(_userLocation!);
            },
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            padding: const EdgeInsets.only(top: 120, bottom: 80),
          ),
          Positioned(top: 0, left: 0, right: 0, child: _controls()),
          Positioned(
            top: 128,
            right: 12,
            child: FloatingActionButton.small(
              heroTag: 'map-layers',
              onPressed: () => setState(
                () => _mapType = _mapType == MapType.normal
                    ? MapType.hybrid
                    : MapType.normal,
              ),
              tooltip: UiStrings.of(context).text('Change map layer'),
              child: Icon(Icons.layers_outlined),
            ),
          ),
        ] else
          _fallback(),
        Positioned(
          bottom: 16,
          right: 12,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'map-refresh',
                onPressed: _refresh,
                tooltip: UiStrings.of(context).text('Refresh reports'),
                child: Icon(Icons.refresh),
              ),
              SizedBox(width: 8),
              FloatingActionButton.small(
                heroTag: 'map-location',
                onPressed: _locate,
                tooltip: UiStrings.of(context).text('Your location'),
                child: _locating
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.my_location),
              ),
            ],
          ),
        ),
        if (_error != null || _locationError != null)
          Positioned(
            bottom: 78,
            left: 12,
            right: 12,
            child: Material(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  UiStrings.of(context).text(_error ?? _locationError!),
                ),
              ),
            ),
          ),
        if ((nativeMap && _loading) || _openingReport)
          Center(child: CircularProgressIndicator()),
      ],
    );
  }
}
