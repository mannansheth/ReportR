import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import '../../l10n/ui_strings.dart';

import '../../models/media_asset.dart';
import '../../models/prediction.dart';
import '../../models/report_location.dart';
import '../../models/user_session.dart';
import '../../core/storage/preferences_service.dart';
import 'report_form_screen.dart';
import '../../widgets/prediction_image_overlay.dart';
import '../../services/exif_service.dart';
import '../../services/location_service.dart';
import '../../services/media_service.dart';
import '../../services/prediction_service.dart';

class CameraHomeScreen extends StatefulWidget {
  const CameraHomeScreen({
    super.key,
    required this.predictionService,
    this.sessionName,
    this.session,
    this.authToken,
    required this.preferences,
    this.isActive = true,
  });
  final PredictionService predictionService;
  final String? sessionName;
  final UserSession? session;
  final String? authToken;
  final PreferencesService preferences;
  final bool isActive;

  @override
  State<CameraHomeScreen> createState() => _CameraHomeScreenState();
}

class _CameraHomeScreenState extends State<CameraHomeScreen>
    with WidgetsBindingObserver {
  final _mediaService = MediaService();
  final _exifService = ExifService();
  final _locationService = LocationService();

  CameraController? _camera;
  List<CameraDescription> _cameras = const [];
  int _cameraIndex = 0;
  double _zoom = 1;
  double _minZoom = 1;
  double _maxZoom = 1;
  FlashMode _flash = FlashMode.off;
  MediaAsset? _asset;
  ReportLocation? _location;
  List<Prediction>? _predictions;
  String? _error;
  bool _loading = true;
  bool _processing = false;
  bool _appResumed = true;
  int _cameraGeneration = 0;
  Future<void>? _cameraOperation;
  Future<void>? _cameraDisposal;
  bool get _canUseCamera =>
      mounted && widget.isActive && _appResumed && _asset == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (const bool.fromEnvironment('FLUTTER_TEST')) {
      _loading = false;
      return;
    }
    if (widget.isActive) _initializeCamera();
  }

  @override
  void didUpdateWidget(covariant CameraHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isActive && oldWidget.isActive) {
      unawaited(_releaseCamera());
    } else if (widget.isActive && !oldWidget.isActive && _asset == null) {
      _initializeCamera();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appResumed = state == AppLifecycleState.resumed;
    if (!_appResumed) {
      unawaited(_releaseCamera());
    } else if (_canUseCamera) {
      _initializeCamera();
    }
  }

  Future<void> _releaseCamera() async {
    _cameraGeneration++;
    final camera = _camera;
    _camera = null;
    if (camera != null) {
      final disposal = camera.dispose();
      _cameraDisposal = disposal;
      try {
        await disposal;
      } catch (_) {
      } finally {
        if (identical(_cameraDisposal, disposal)) _cameraDisposal = null;
      }
    }
  }

  Future<void> _initializeCamera({bool switchLens = false}) async {
    if (!_canUseCamera || const bool.fromEnvironment('FLUTTER_TEST')) return;
    final pending = _cameraOperation;
    if (pending != null) {
      await pending;
      if (_canUseCamera && _camera == null) await _initializeCamera();
      return;
    }
    final task = _configureCamera(switchLens: switchLens);
    _cameraOperation = task;
    try {
      await task;
    } finally {
      if (identical(_cameraOperation, task)) _cameraOperation = null;
    }
  }

  Future<void> _configureCamera({required bool switchLens}) async {
    final generation = ++_cameraGeneration;
    bool current() => _canUseCamera && generation == _cameraGeneration;
    CameraController? controller;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _cameraDisposal;
      if (!current()) return;
      final previous = _camera;
      _camera = null;
      await previous?.dispose();
      if (!current()) return;
      final cameras = await availableCameras().timeout(Duration(seconds: 15));
      if (!current()) return;
      if (cameras.isEmpty) {
        throw CameraException('No camera', 'No camera available');
      }
      _cameras = cameras;
      var index = switchLens
          ? (_cameraIndex + 1) % cameras.length
          : cameras.indexWhere(
              (camera) => camera.lensDirection == CameraLensDirection.back,
            );
      if (index < 0) index = 0;
      controller = CameraController(
        cameras[index],
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      if (!current()) return;
      try {
        await controller.setFlashMode(_flash);
      } catch (_) {
        _flash = FlashMode.off;
      }
      final minZoom = await controller.getMinZoomLevel();
      final maxZoom = await controller.getMaxZoomLevel();
      await controller.setZoomLevel(minZoom);
      if (!current()) return;
      _cameraIndex = index;
      _minZoom = minZoom;
      _maxZoom = maxZoom;
      _zoom = minZoom;
      _camera = controller;
      controller = null;
    } on CameraException catch (error) {
      if (current()) {
        _error = error.code == 'CameraAccessDenied'
            ? 'Camera permission was denied.'
            : 'Camera is unavailable.';
      }
    } catch (_) {
      if (current()) _error = 'Camera is unavailable.';
    } finally {
      try {
        await controller?.dispose();
      } catch (_) {}
      if (current()) setState(() => _loading = false);
    }
  }

  Future<void> _capture() async {
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized || _processing) return;
    setState(() => _processing = true);
    try {
      final asset = await _mediaService.readCameraFile(
        await camera.takePicture(),
      );
      await _processAsset(asset);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to capture this image.');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _pick() async {
    if (_processing) return;
    try {
      final asset = await _mediaService.pickImage();
      if (asset == null) return;
      setState(() => _processing = true);
      await _processAsset(asset);
    } on FormatException {
      if (mounted) setState(() => _error = 'The selected image is invalid.');
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to read the selected image.');
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  Future<void> _processAsset(MediaAsset asset) async {
    if (!mounted) return;
    setState(() {
      _asset = asset;
      _location = null;
      _predictions = null;
      _error = null;
    });
    await _releaseCamera();
    if (!mounted) return;

    final exif = await _exifService.readCoordinates(asset.path);
    try {
      _location = exif != null
          ? await _locationService.fromCoordinates(
              exif.latitude,
              exif.longitude,
            )
          : await _locationService.currentLocation();
    } catch (error) {
      _error = error is LocationException
          ? error.message
          : 'Unable to determine your location.';
    }
    if (mounted) setState(() {});

    try {
      final predictions = await widget.predictionService.detectIssues(
        base64Image: asset.base64,
        mimeType: asset.mimeType,
      );
      if (!mounted) return;
      setState(() => _predictions = predictions);
      await _openReportForm();
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PredictionException
              ? error.message
              : 'Prediction request failed.',
        );
        setState(() => _predictions = const []);
      }
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2 ||
        _processing ||
        _cameraOperation != null ||
        !_canUseCamera) {
      return;
    }
    await _initializeCamera(switchLens: true);
  }

  Future<void> _toggleFlash() async {
    final camera = _camera;
    if (camera == null) return;
    final next = _flash == FlashMode.off ? FlashMode.torch : FlashMode.off;
    try {
      await camera.setFlashMode(next);
      if (mounted) setState(() => _flash = next);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Flash is unavailable for this camera.');
      }
    }
  }

  Future<void> _openReportForm() async {
    final asset = _asset;
    if (asset == null || !mounted || !widget.isActive) return;
    await _releaseCamera();
    if (!mounted || !widget.isActive) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ReportFormScreen(
          session: widget.session,
          preferences: widget.preferences,
          image: asset,
          location: _location,
          predictions: _predictions ?? const [],
          authToken: widget.authToken,
          selectedIssues: (_predictions ?? const <Prediction>[])
              .map((p) => p.issueKey)
              .toSet(),
        ),
      ),
    );
    if (mounted) _reset();
  }

  void _reset() {
    setState(() {
      _asset = null;
      _location = null;
      _predictions = null;
      _error = null;
    });
    _initializeCamera();
  }

  Future<void> _retryLocation() async {
    setState(() => _processing = true);
    try {
      final location = await _locationService.currentLocation();
      if (mounted) {
        setState(() {
          _location = location;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseCamera());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_asset != null) return _buildPreview(context);
    if (_loading) return Center(child: CircularProgressIndicator());
    if (_camera == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(UiStrings.of(context).text('Home / Camera')),
            Text(UiStrings.of(context).text(_error ?? 'Camera unavailable')),
            if (widget.sessionName != null)
              Text(
                UiStrings.of(
                  context,
                ).format('Signed in as {name}', {'name': widget.sessionName}),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: OutlinedButton.icon(
                onPressed: _pick,
                icon: Icon(Icons.photo_library_outlined),
                label: Text(UiStrings.of(context).text('Choose a photo')),
              ),
            ),
            TextButton.icon(
              onPressed: _initializeCamera,
              icon: Icon(Icons.refresh),
              label: Text(UiStrings.of(context).text('Retry camera')),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        CameraPreview(_camera!),
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black38,
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black87,
                ],
                stops: [0, .25, .65, 1],
              ),
            ),
          ),
        ),
        Positioned(
          top: 24,
          left: 20,
          right: 80,
          child: Text(
            UiStrings.of(context).text('Point at a civic issue'),
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
        ),
        Positioned(
          top: 16,
          right: 12,
          child: IconButton(
            onPressed: _processing ? null : _toggleFlash,
            tooltip: UiStrings.of(context).text('Toggle flash'),
            color: Colors.white,
            icon: Icon(
              _flash == FlashMode.off ? Icons.flash_off : Icons.flash_on,
            ),
          ),
        ),
        Positioned(
          left: 24,
          right: 24,
          bottom: 100,
          child: Slider(
            value: _zoom.clamp(_minZoom, _maxZoom),
            min: _minZoom,
            max: _maxZoom,
            label: '${_zoom.toStringAsFixed(1)}×',
            activeColor: Colors.white,
            inactiveColor: Colors.white38,
            onChanged: _processing || _maxZoom <= _minZoom
                ? null
                : (value) async {
                    setState(() => _zoom = value);
                    try {
                      await _camera?.setZoomLevel(value);
                    } catch (_) {}
                  },
          ),
        ),
        Positioned(
          left: 32,
          bottom: 24,
          child: IconButton(
            onPressed: _processing ? null : _switchCamera,
            tooltip: UiStrings.of(context).text('Switch camera'),
            color: Colors.white,
            iconSize: 32,
            icon: Icon(Icons.cameraswitch),
          ),
        ),
        Positioned(
          right: 32,
          bottom: 24,
          child: IconButton(
            onPressed: _processing ? null : _pick,
            tooltip: UiStrings.of(context).text('Choose photo'),
            color: Colors.white,
            iconSize: 32,
            icon: Icon(Icons.photo_library_outlined),
          ),
        ),
        Positioned(
          bottom: 18,
          left: 0,
          right: 0,
          child: Center(
            child: Semantics(
              label: 'Capture photo',
              button: true,
              child: GestureDetector(
                onTap: _processing ? null : _capture,
                child: Container(
                  width: 72,
                  height: 72,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.camera_alt_outlined,
                      color: Colors.black,
                      size: 30,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_processing)
          Center(child: CircularProgressIndicator(color: Colors.white)),
        if (_error != null)
          Positioned(
            left: 16,
            right: 16,
            top: 16,
            child: _ErrorBanner(message: _error!),
          ),
      ],
    );
  }

  Widget _buildPreview(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          PredictionImageOverlay(
            file: File(_asset!.path),
            predictions: _predictions ?? const [],
            fit: BoxFit.contain,
            onClose: _processing ? null : _reset,
          ),
          if (_processing)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      UiStrings.of(context).text('Finding civic issues...'),
                      style: TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          if (!_processing)
            Positioned(
              left: 20,
              right: 20,
              bottom: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        UiStrings.of(context).text(_error!),
                        style: TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (_location == null)
                    TextButton.icon(
                      onPressed: _retryLocation,
                      icon: Icon(Icons.my_location),
                      label: Text(UiStrings.of(context).text('Retry location')),
                    ),
                  FilledButton.icon(
                    onPressed: _openReportForm,
                    icon: Icon(Icons.edit_note),
                    label: Text(
                      UiStrings.of(context).text('Review photo and report'),
                    ),
                  ),
                  TextButton(
                    onPressed: _reset,
                    child: Text(UiStrings.of(context).text('Retake photo')),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Text(UiStrings.of(context).text(message)),
      ),
    );
  }
}
