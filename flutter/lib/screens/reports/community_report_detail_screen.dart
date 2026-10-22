import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/network/api_client.dart';
import '../../l10n/ui_strings.dart';
import '../../models/community_report.dart';
import '../../models/report_record.dart';
import '../../models/user_session.dart';
import '../../services/community_service.dart';
import '../../services/map_distance_service.dart';
import '../../services/report_service.dart';
import 'reports_screen.dart';

class CommunityReportDetailScreen extends StatefulWidget {
  const CommunityReportDetailScreen({
    super.key,
    required this.report,
    this.authToken,
    this.session,
    this.service,
    this.locationService,
    this.onConfirmed,
  });
  final CommunityReport report;
  final String? authToken;
  final UserSession? session;
  final CommunityService? service;
  final CommunityLocationService? locationService;
  final VoidCallback? onConfirmed;
  @override
  State<CommunityReportDetailScreen> createState() =>
      _CommunityReportDetailScreenState();
}

class _CommunityReportDetailScreenState
    extends State<CommunityReportDetailScreen> {
  late CommunityReport _report;
  late final CommunityService _service;
  late final CommunityLocationService _locationService;
  CommunityPosition? _position;
  bool _loading = false, _acting = false, _confirmedDuringVisit = false;
  String? _error;
  UiStrings get strings => UiStrings.of(context);
  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _service =
        widget.service ??
        CommunityService(ApiClient(authToken: widget.authToken));
    _locationService = widget.locationService ?? CommunityLocationService();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final report = await _service.getReport(_report.id);
      if (mounted) {
        setState(() {
          _report = report;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  double _distance(CommunityPosition position) => MapDistance.meters(
    position.latitude,
    position.longitude,
    _report.latitude,
    _report.longitude,
  );
  Future<CommunityPosition> _freshLocation({required bool resolution}) async {
    final position = await _locationService.currentPosition();
    if (mounted) setState(() => _position = position);
    final distance = _distance(position);
    if (!(resolution
        ? CommunityRange.canResolve(distance)
        : CommunityRange.canConfirm(distance))) {
      throw ApiClientException(
        resolution
            ? 'Move within 200 metres of the issue to report it resolved.'
            : 'Move within 500 metres of the issue to confirm it.',
      );
    }
    return position;
  }

  Future<void> _confirm() async {
    if (_acting || _report.confirmedByMe || !_report.isOpen) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      final position = await _freshLocation(resolution: false);
      final updated = await _service.confirm(_report.id, position);
      if (!mounted) return;
      setState(() {
        _report = updated;
        _confirmedDuringVisit = true;
      });
      widget.onConfirmed?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              'Your confirmation was added. Thank you for helping your community.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _resolve() async {
    if (_acting || !_report.isOpen) return;
    setState(() {
      _acting = true;
      _error = null;
    });
    try {
      await _freshLocation(resolution: true);
      if (!mounted) return;
      setState(() => _acting = false);
      final evidence = await showModalBottomSheet<_ResolutionEvidence>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (_) => const _ResolutionEvidenceSheet(),
      );
      if (evidence == null) return;
      if (mounted) setState(() => _acting = true);
      final position = await _freshLocation(resolution: true);
      final updated = await _service.resolve(
        _report.id,
        position,
        note: evidence.note,
        imagePath: evidence.imagePath,
      );
      if (!mounted) return;
      setState(() => _report = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            strings.text(
              updated.isResolved
                  ? 'The community has verified this issue as resolved.'
                  : 'Resolution update received. Community verification is in progress.',
            ),
          ),
        ),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _openPrivateReport() {
    if (!_report.isOwner || widget.session == null) return;
    final report = ReportRecord(
      id: _report.id,
      userId: widget.session!.id,
      issue: _report.issue,
      description: _report.description,
      location: {
        'lat': _report.latitude,
        'lng': _report.longitude,
        'loc': _report.locationName,
      },
      createdAt: _report.createdAt,
      status: _report.status,
      imageUrl: _report.imageUrl,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportDetailScreen(
          report: report,
          service: ReportService(ApiClient(authToken: widget.authToken)),
        ),
      ),
    );
  }

  void _close() => Navigator.of(context).pop(_confirmedDuringVisit);
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_acting) _close();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _acting ? null : _close),
          title: Text(strings.text('Community report')),
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_report.imageUrl?.isNotEmpty == true)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    _report.imageUrl!,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox(
                      height: 100,
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: Icon(
                      _report.isResolved
                          ? Icons.check_circle_outline
                          : Icons.pending_outlined,
                      size: 18,
                    ),
                    label: Text(strings.status(_report.status)),
                  ),
                  if (_report.isOwner)
                    Chip(label: Text(strings.text('Your report'))),
                ],
              ),
              Text(
                strings.category(_report.issue),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _report.description.isEmpty
                    ? strings.text('No description provided.')
                    : _report.description,
              ),
              const SizedBox(height: 12),
              Text(strings.dateString(_report.createdAt)),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _report.locationName.isEmpty
                            ? '${_report.latitude.toStringAsFixed(5)}, ${_report.longitude.toStringAsFixed(5)}'
                            : _report.locationName,
                      ),
                      if (_position != null)
                        Text(
                          strings.format(
                            '{distance} metres from your location',
                            {'distance': _distance(_position!).round()},
                          ),
                        ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        children: [
                          Text(
                            strings.format('{count} community confirmations', {
                              'count': _report.confirmationCount,
                            }),
                          ),
                          Text(
                            strings.format('Priority {priority}', {
                              'priority': _report.priority.toStringAsFixed(0),
                            }),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_report.isOpen) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _acting || _report.confirmedByMe ? null : _confirm,
                  icon: Icon(
                    _report.confirmedByMe
                        ? Icons.check
                        : Icons.visibility_outlined,
                  ),
                  label: Text(
                    strings.text(
                      _report.confirmedByMe
                          ? 'You confirmed this issue'
                          : 'I see this too',
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    strings.text(
                      'Confirm within 500 metres. Each person counts once; nearby confirmations help prioritise the issue.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed:
                      _acting ||
                          (_report.resolutionVotedByMe &&
                              _report.myEvidenceState == 'verified')
                      ? null
                      : _resolve,
                  icon: const Icon(Icons.task_alt),
                  label: Text(
                    strings.text(
                      _report.resolutionVotedByMe
                          ? (_report.myEvidenceState == 'verified'
                                ? 'Your repair photo is verified'
                                : 'Add or update repair photo')
                          : 'Report as resolved',
                    ),
                  ),
                ),
                Text(
                  strings.text(
                    'Within 200 metres, tell the community the work is complete. Add a photo if you can.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 16),
              if (_report.myEvidenceState == 'pending')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    strings.text(
                      'Your photo is awaiting verification. It has not added photo points yet.',
                    ),
                  ),
                ),
              if (_report.myEvidenceState == 'not_verified')
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    strings.text(
                      'Your photo did not verify the repair. You can submit a clearer photo.',
                    ),
                  ),
                ),
              Card(
                color: colors.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.text(
                          _report.isResolved
                              ? 'Issue resolved'
                              : 'Resolution verification',
                        ),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      if (!_report.isResolved)
                        LinearProgressIndicator(
                          value: _report.resolutionProgress,
                        ),
                      const SizedBox(height: 8),
                      if (_report.isResolved && _report.resolutionVoters == 0)
                        Text(
                          strings.text(
                            'No community resolution contributions are recorded for this issue.',
                          ),
                        )
                      else
                        Text(
                          strings.format(
                            _report.isResolved
                                ? '{weight} verification points · {voters} people'
                                : '{weight} / 5 verification points · {voters} people',
                            {
                              'weight': _report.resolutionWeight
                                  .toStringAsFixed(1),
                              'voters': _report.resolutionVoters,
                            },
                          ),
                        ),
                      const SizedBox(height: 8),
                      Text(
                        strings.text(
                          'A nearby resolution vote adds 1 point, or 3 for the original reporter. A photo verified by AI adds 3 more. An unverified photo adds no points.',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.text(
                          'An issue closes when its original reporter has voted and a verified repair photo is present, or when at least 2 people contribute 5 points in total.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(strings.text('How community priority works')),
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.format(
                            'Baseline {baseline} · community priority {priority} / 100',
                            {
                              'baseline': _report.baselinePriority
                                  .toStringAsFixed(0),
                              'priority': _report.priority.toStringAsFixed(0),
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          strings.text(
                            'The issue category and visual severity set its baseline. Confirmations, including the reporter, add up to 40 points using 12 × log₂(confirmations). Total priority is capped at 100.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_report.isOwner && widget.session != null)
                OutlinedButton.icon(
                  onPressed: _openPrivateReport,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(strings.text('Open my private report and PDF')),
                ),
              if (_loading || _acting)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: LinearProgressIndicator(),
                ),
              if (_error != null)
                Card(
                  color: colors.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(strings.text(_error!)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResolutionEvidence {
  const _ResolutionEvidence(this.note, this.imagePath);
  final String note;
  final String? imagePath;
}

class _ResolutionEvidenceSheet extends StatefulWidget {
  const _ResolutionEvidenceSheet();
  @override
  State<_ResolutionEvidenceSheet> createState() =>
      _ResolutionEvidenceSheetState();
}

class _ResolutionEvidenceSheetState extends State<_ResolutionEvidenceSheet> {
  final _note = TextEditingController();
  String? _image, _error;
  bool _picking = false;
  Future<void> _pick(ImageSource source) async {
    setState(() => _picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (mounted && image != null) {
        setState(() {
          _image = image.path;
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Unable to attach a photo. You can still submit without one.',
        );
      }
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = UiStrings.of(context);
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 24,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              strings.text('What has been fixed?'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLength: 500,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: strings.text('Resolution note (optional)'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_image != null) ...[
              Image.file(File(_image!), height: 160, fit: BoxFit.cover),
              TextButton.icon(
                onPressed: _picking
                    ? null
                    : () => setState(() => _image = null),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.text('Remove photo')),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _picking ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(strings.text('Take photo')),
                ),
                OutlinedButton.icon(
                  onPressed: _picking ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_outlined),
                  label: Text(strings.text('Choose photo')),
                ),
              ],
            ),
            if (_error != null) Text(strings.text(_error!)),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _picking
                  ? null
                  : () => Navigator.pop(
                      context,
                      _ResolutionEvidence(_note.text.trim(), _image),
                    ),
              child: Text(strings.text('Submit resolution update')),
            ),
          ],
        ),
      ),
    );
  }
}
