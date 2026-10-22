import 'dart:async';
// ignore_for_file: prefer_interpolation_to_compose_strings
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/storage/preferences_service.dart';
import '../../models/media_asset.dart';
import '../../models/prediction.dart';
import '../../models/report.dart';
import '../../models/report_location.dart';
import '../../models/user_session.dart';
import '../../services/audio_recording_service.dart';
import '../../services/pdf_service.dart';
import '../../services/report_storage_service.dart';
import '../../services/report_upload_service.dart';
import '../../models/community_report.dart';
import '../reports/community_report_detail_screen.dart';
import '../../services/transcription_service.dart';
import '../../services/report_submission_service.dart';
import '../../widgets/report_pdf_actions.dart';
import '../../l10n/ui_strings.dart';
import '../../services/location_service.dart';
import '../../widgets/prediction_image_overlay.dart';
import '../../widgets/prediction_options.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({
    super.key,
    required this.session,
    required this.preferences,
    required this.image,
    required this.location,
    required this.predictions,
    this.authToken,
    this.selectedIssues,
    this.initiallyExpanded = true,
    this.submissionService,
  });

  final UserSession? session;
  final PreferencesService preferences;
  final MediaAsset image;
  final ReportLocation? location;
  final List<Prediction> predictions;
  final String? authToken;
  final Set<String>? selectedIssues;
  final bool initiallyExpanded;
  final ReportSubmissionService? submissionService;

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  late final TextEditingController _categoryController;
  late final TextEditingController _descriptionController;
  final _audio = AudioRecordingService();
  late final String _reportId;
  String? _recordingPath;
  ReportDraft? _storedReport;
  bool _isRecording = false;
  bool _transcribing = false;
  bool _uploading = false;
  SubmissionStage? _stage;
  late final ReportSubmissionService _submission;
  String? _error;
  late Set<String> _selectedIssues;
  late bool _expanded;
  ReportLocation? _location;
  bool _locating = false;
  bool _descriptionEdited = false;

  @override
  void initState() {
    super.initState();
    _reportId = ReportIdGenerator.generate();
    _submission =
        widget.submissionService ??
        ReportSubmissionService(
          preferences: widget.preferences,
          storage: ReportStorageService(widget.preferences),
          pdf: PdfService(),
          upload: ReportUploadService(ApiClient(authToken: widget.authToken)),
          nearbyMatches: (draft) async {
            final response = await ApiClient(authToken: widget.authToken)
                .postJson('api/reports/nearbyMatches', {
                  'category': draft.category,
                  'location': draft.location.toJson(),
                });
            final reports = response['reports'];
            if (reports is! List) {
              throw const FormatException('Invalid nearby report response');
            }
            return reports
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .toList();
          },
        );
    _expanded = widget.initiallyExpanded;
    _location = widget.location;
    _selectedIssues = Set.of(
      widget.selectedIssues ?? widget.predictions.map((p) => p.issueKey),
    );
    _categoryController = TextEditingController(
      text: _selectedPredictions.map((p) => p.displayTitle).join(', '),
    );
    _descriptionController = TextEditingController(
      text: _selectedPredictions
          .map((p) => p.description)
          .where((text) => text.trim().isNotEmpty)
          .join('\n'),
    );
  }

  List<Prediction> get _selectedPredictions => Prediction.uniqueIssues(
    widget.predictions,
  ).where((p) => _selectedIssues.contains(p.issueKey)).toList();
  void _toggleIssue(String key) {
    if (_storedReport != null || _uploading) return;
    setState(() {
      if (!_selectedIssues.add(key)) _selectedIssues.remove(key);
      _categoryController.text = _selectedPredictions
          .map((p) => p.displayTitle)
          .join(', ');
      if (!_descriptionEdited) {
        _descriptionController.text = _selectedPredictions
            .map((p) => p.description)
            .where((text) => text.trim().isNotEmpty)
            .join('\n');
      }
    });
  }

  void _continueDetails() {
    setState(() => _expanded = false);
  }

  Future<void> _retryLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final location = await LocationService().currentLocation();
      if (mounted) setState(() => _location = location);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      try {
        final path = await _audio.stop();
        if (path == null) {
          throw const FormatException('Recording did not produce a file.');
        }
        setState(() {
          _recordingPath = path;
          _isRecording = false;
          _error = null;
        });
        unawaited(_transcribe(path));
      } catch (_) {
        setState(() {
          _isRecording = false;
          _error = 'Unable to stop recording.';
        });
      }
      return;
    }

    try {
      final path = await _audio.start();
      if (path == null) {
        setState(() => _error = 'Microphone permission was denied.');
        return;
      }
      setState(() {
        _recordingPath = path;
        _isRecording = true;
        _error = null;
      });
    } catch (_) {
      setState(() => _error = 'Unable to start recording.');
    }
  }

  Future<void> _transcribe(String path) async {
    if (!mounted) return;
    setState(() {
      _transcribing = true;
      _error = null;
    });
    final result = await TranscriptionService(
      ApiClient(authToken: widget.authToken),
    ).transcribe(path);
    if (!mounted) return;
    setState(() {
      _transcribing = false;
      if (result.isSuccess && result.text != null) {
        _descriptionController.text = result.text!;
        _descriptionEdited = true;
      } else {
        _error = result.message ?? 'Transcription failed.';
      }
    });
  }

  Future<void> _showExistingIssue(Map<String, dynamic> data) async {
    final strings = UiStrings.of(context);
    final view = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.people_outline, size: 40),
        title: Text(strings.text('This issue already has a report')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              strings.text(
                'Add your confirmation to the existing issue instead of creating a duplicate.',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.category(data['issue']?.toString() ?? ''),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              strings.format('Reported by {count} people', {
                'count': data['confirmationCount'] ?? 1,
              }),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(strings.text('Close')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(strings.text('View existing issue')),
          ),
        ],
      ),
    );
    if (!mounted || view != true) return;
    var confirmed = false;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityReportDetailScreen(
          report: CommunityReport.fromJson(data),
          authToken: widget.authToken,
          session: widget.session,
          onConfirmed: () => confirmed = true,
        ),
      ),
    );
    if (confirmed) {
      await widget.preferences.removePendingReport(_reportId);
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  Future<void> _discardRecording() async {
    if (_storedReport != null) {
      setState(
        () => _error = 'Edit report details before changing the recording.',
      );
      return;
    }
    await _audio.discard(_recordingPath);
    if (mounted) setState(() => _recordingPath = null);
  }

  Future<void> _submit() async {
    if (_uploading || _transcribing || _isRecording) return;
    final session = widget.session;
    final location = _location;
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    String? validation;
    if (session == null) {
      validation = 'A signed-in user is required.';
    } else if (location == null) {
      validation = 'A report location is required.';
    } else if (category.isEmpty) {
      validation = 'Select or enter a report category.';
    } else if (category.length > 255) {
      validation =
          'Select fewer issues: combined categories must fit within 255 characters.';
    } else if (description.isEmpty) {
      validation = 'Describe the issue before submitting.';
    } else if (description.length > 500) {
      validation = 'Description must be within 500 characters.';
    }
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _uploading = true;
      _error = null;
    });
    final draft =
        _storedReport ??
        ReportDraft(
          reportID: _reportId,
          userID: session!.id,
          name: session.name,
          number: session.number,
          category: category,
          description: description,
          location: location!,
          createdDate: DateTime.now().toUtc().toIso8601String(),
        );
    final result = await _submission.submit(
      draft: draft,
      image: widget.image,
      audioPath: _recordingPath,
      languageCode: Localizations.localeOf(context).languageCode,
      onStage: (stage) {
        if (mounted) setState(() => _stage = stage);
      },
    );
    if (!mounted) return;
    _storedReport = result.report;
    if (result.duplicateReport != null) {
      setState(() {
        _uploading = false;
        _stage = null;
        _error = null;
      });
      await _showExistingIssue(result.duplicateReport!);
    } else if (result.success) {
      await showReportPdfActions(
        context,
        reportId: draft.reportID,
        localPath: result.pdfPath,
        submitted: true,
        authToken: widget.authToken,
      );
      if (!mounted) return;
      setState(() => _uploading = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(true);
    } else {
      setState(() {
        _uploading = false;
        _stage = null;
        _error = result.message;
      });
    }
  }

  Widget _imageReview(bool busy) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton.filledTonal(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.arrow_back),
                      tooltip: UiStrings.of(context).text('Retake photo'),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        UiStrings.of(context).text('Review detected issues'),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PredictionImageOverlay(
                  file: File(widget.image.path),
                  predictions: widget.predictions,
                  selectedIssues: _selectedIssues,
                  fit: BoxFit.contain,
                  interactive: true,
                  onToggleIssue: _storedReport == null && !busy
                      ? _toggleIssue
                      : null,
                ),
              ),
              Padding(
                padding: EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: constraints.maxHeight * .4,
                  ),
                  child: Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Color(0xED17212B),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  widget.predictions.isEmpty
                                      ? UiStrings.of(context).text(
                                          'No issues detected. Describe the problem in your report.',
                                        )
                                      : UiStrings.of(context).text(
                                          'Select one or more issues - Pinch to inspect',
                                        ),
                                  style: TextStyle(color: Colors.white70),
                                ),
                                SizedBox(height: 12),
                                if (widget.predictions.isNotEmpty)
                                  PredictionOptions(
                                    predictions: widget.predictions,
                                    selectedIssues: _selectedIssues,
                                    onToggle: _toggleIssue,
                                    enabled: !busy && _storedReport == null,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed:
                              widget.predictions.isNotEmpty &&
                                  _selectedIssues.isEmpty
                              ? null
                              : _continueDetails,
                          icon: Icon(Icons.edit_note),
                          label: Text(
                            _selectedIssues.isEmpty
                                ? UiStrings.of(
                                    context,
                                  ).text('Add report details')
                                : UiStrings.of(context).format(
                                    _selectedIssues.length == 1
                                        ? 'Continue with {count} issue'
                                        : 'Continue with {count} issues',
                                    {'count': _selectedIssues.length},
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _categoryController.dispose();
    _descriptionController.dispose();
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = UiStrings.of(context);
    final location = _location;
    final busy = _uploading || _transcribing;
    if (_expanded) return _imageReview(busy);
    final scheme = Theme.of(context).colorScheme;
    final editable = !busy && _storedReport == null;
    final progress = switch (_stage) {
      SubmissionStage.checking => 'Checking nearby reports...',
      SubmissionStage.saving => 'Saving your report...',
      SubmissionStage.pdf => 'Creating your PDF...',
      SubmissionStage.uploading => 'Submitting your report...',
      null => 'Submit report',
    };
    Widget section({
      required IconData icon,
      required String title,
      required Widget child,
    }) => Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: scheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    strings.text(title),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.text('Create report')),
          automaticallyImplyLeading: !_uploading,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(top: BorderSide(color: scheme.outlineVariant)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_uploading) ...[
                  LinearProgressIndicator(
                    value: switch (_stage) {
                      SubmissionStage.checking => .1,
                      SubmissionStage.saving => .2,
                      SubmissionStage.pdf => .5,
                      SubmissionStage.uploading => null,
                      null => 0,
                    },
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton.icon(
                    key: const Key('submit-report'),
                    onPressed: busy || _isRecording ? null : _submit,
                    icon: _uploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                    label: Text(
                      strings.text(
                        _uploading
                            ? progress
                            : _storedReport != null
                            ? 'Retry submission'
                            : 'Submit report',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  strings.text('Your report PDF is created automatically.'),
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              strings.text('Make your neighbourhood better'),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              strings.text(
                'Check the evidence and details, then send your report.',
              ),
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: SizedBox(
                height: 220,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: PredictionImageOverlay(
                        file: File(widget.image.path),
                        predictions: widget.predictions,
                        selectedIssues: _selectedIssues,
                        fit: BoxFit.contain,
                      ),
                    ),
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: FilledButton.tonalIcon(
                        onPressed: busy
                            ? null
                            : () => setState(() => _expanded = true),
                        icon: const Icon(Icons.fullscreen),
                        label: Text(strings.text('Review photo')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            section(
              icon: Icons.edit_note,
              title: 'Report details',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.predictions.isNotEmpty) ...[
                    Text(strings.text('Select all issues you want to report')),
                    const SizedBox(height: 10),
                    PredictionOptions(
                      predictions: widget.predictions,
                      selectedIssues: _selectedIssues,
                      onToggle: _toggleIssue,
                      enabled: editable,
                      dark: false,
                    ),
                  ] else
                    TextField(
                      controller: _categoryController,
                      enabled: editable,
                      decoration: InputDecoration(
                        labelText: strings.text('Category'),
                        hintText: strings.text('Enter a category'),
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                    ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    onChanged: (_) => _descriptionEdited = true,
                    enabled: editable,
                    minLines: 3,
                    maxLines: 6,
                    maxLength: 500,
                    decoration: InputDecoration(
                      labelText: strings.text('Description'),
                      hintText: strings.text(
                        'Explain what needs attention and how it affects people.',
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ],
              ),
            ),
            section(
              icon: Icons.location_on_outlined,
              title: 'Report location',
              child: location != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          location.readableLocation.isEmpty
                              ? strings.text('Location acquired')
                              : location.readableLocation,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${location.latitude.toStringAsFixed(5)}, ${location.longitude.toStringAsFixed(5)}',
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    )
                  : OutlinedButton.icon(
                      onPressed: busy || _locating ? null : _retryLocation,
                      icon: const Icon(Icons.my_location),
                      label: Text(
                        strings.text(
                          _locating
                              ? 'Finding location...'
                              : 'Set report location',
                        ),
                      ),
                    ),
            ),
            section(
              icon: Icons.mic_none_rounded,
              title: 'Voice note (optional)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    strings.text(
                      'Record a voice note to help describe the issue.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: !editable ? null : _toggleRecording,
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    label: Text(
                      strings.text(
                        _isRecording ? 'Stop recording' : 'Record description',
                      ),
                    ),
                  ),
                  if (_transcribing)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        strings.text('Preparing description from audio...'),
                      ),
                    ),
                  if (_recordingPath != null && !_isRecording)
                    Row(
                      children: [
                        Expanded(
                          child: Text(strings.text('Voice note attached')),
                        ),
                        IconButton(
                          onPressed: busy ? null : _discardRecording,
                          icon: const Icon(Icons.delete_outline),
                          tooltip: strings.text('Discard recording'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            if (_error != null)
              Container(
                key: const Key('submission-error'),
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        strings.text(_error!),
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            if (_storedReport != null && !_uploading)
              TextButton.icon(
                onPressed: () => setState(() {
                  _storedReport = null;
                }),
                icon: const Icon(Icons.edit_outlined),
                label: Text(strings.text('Edit report details')),
              ),
          ],
        ),
      ),
    );
  }
}
