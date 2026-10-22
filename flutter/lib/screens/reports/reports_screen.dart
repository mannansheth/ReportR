import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../../config/app_config.dart';

import '../../core/network/api_client.dart';
import '../../models/report_record.dart';
import '../../models/user_session.dart';
import '../../services/report_service.dart';
import '../../services/report_storage_service.dart';
import '../../services/report_upload_service.dart';
import '../../core/storage/preferences_service.dart';
import '../../models/report.dart';
import '../../l10n/ui_strings.dart';
import '../../widgets/report_pdf_actions.dart';
import '../../services/community_service.dart';
import 'community_reports_screen.dart';
import 'dart:io';
import 'dart:async';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({
    super.key,
    required this.session,
    this.authToken,
    this.isActive = true,
    this.reportService,
    this.communityService,
    this.initialMine = false,
  });
  final UserSession? session;
  final String? authToken;
  final bool isActive;
  final ReportService? reportService;
  final CommunityService? communityService;
  final bool initialMine;

  @override
  State<ReportsScreen> createState() => _ReportsHubState();
}

class _ReportsHubState extends State<ReportsScreen> {
  late bool _mine;
  @override
  void initState() {
    super.initState();
    _mine = widget.initialMine;
  }

  @override
  Widget build(BuildContext context) {
    final strings = UiStrings.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  icon: const Icon(Icons.people_outline),
                  label: Text(strings.text('All reports')),
                ),
                ButtonSegment(
                  value: true,
                  icon: const Icon(Icons.person_outline),
                  label: Text(strings.text('My reports')),
                ),
              ],
              selected: {_mine},
              onSelectionChanged: (value) =>
                  setState(() => _mine = value.single),
            ),
          ),
        ),
        Expanded(
          child: _mine
              ? MyReportsScreen(
                  session: widget.session,
                  authToken: widget.authToken,
                  isActive: widget.isActive,
                  reportService: widget.reportService,
                )
              : CommunityReportsScreen(
                  session: widget.session,
                  authToken: widget.authToken,
                  isActive: widget.isActive,
                  service: widget.communityService,
                ),
        ),
      ],
    );
  }
}

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({
    super.key,
    required this.session,
    this.authToken,
    this.isActive = true,
    this.reportService,
  });
  final UserSession? session;
  final String? authToken;
  final bool isActive;
  final ReportService? reportService;
  @override
  State<MyReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<MyReportsScreen> {
  late final ReportService _service;
  List<ReportRecord> _reports = const [];
  bool _loading = true;
  String? _error;
  String _filter = 'All';
  String _query = '';
  List<ReportDraft> _drafts = const [];
  String? _sendingDraft;

  @override
  void initState() {
    super.initState();
    _service =
        widget.reportService ??
        ReportService(ApiClient(authToken: widget.authToken));
    _load();
  }

  @override
  void didUpdateWidget(covariant MyReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load() async {
    final session = widget.session;
    if (session == null) {
      setState(() {
        _loading = false;
        _error = 'A signed-in user is required.';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    await _loadDrafts();
    try {
      final reports = await _service.getUserReports(session.id);
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadDrafts() async {
    final preferences = await PreferencesService.create();
    final storage = ReportStorageService(preferences);
    final drafts = await Future.wait(
      preferences.pendingReports.map(storage.loadDraft),
    );
    if (mounted) {
      setState(
        () => _drafts = drafts
            .whereType<ReportDraft>()
            .where((draft) => draft.userID == widget.session?.id)
            .toList(),
      );
    }
  }

  Future<void> _retryDraft(ReportDraft draft) async {
    if (_sendingDraft != null || draft.imagePath == null) return;
    setState(() => _sendingDraft = draft.reportID);
    final result =
        await ReportUploadService(
          ApiClient(authToken: widget.authToken),
        ).upload(
          report: draft,
          imagePath: draft.imagePath!,
          audioPath: draft.audioPath,
          pdfPath: ReportPaths.pdf(File(draft.imagePath!).parent.path),
        );
    if (result.isSuccess) {
      final preferences = await PreferencesService.create();
      await preferences.removePendingReport(draft.reportID);
    }
    if (!mounted) return;
    setState(() => _sendingDraft = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.isSuccess
              ? _tr(context, 'Report submitted successfully.')
              : _tr(
                  context,
                  result.message ?? 'Unable to submit. Your draft is saved.',
                ),
        ),
      ),
    );
    await _load();
  }

  Widget _draftCard(ReportDraft draft) => Card(
    color: Theme.of(context).colorScheme.tertiaryContainer,
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_upload_outlined),
          title: Text(UiStrings.of(context).category(draft.category)),
          subtitle: Text(
            _tr(context, 'Saved on this phone · awaiting submission'),
          ),
          trailing: TextButton(
            onPressed: _sendingDraft == null ? () => _retryDraft(draft) : null,
            child: Text(
              _tr(
                context,
                _sendingDraft == draft.reportID ? 'Sending...' : 'Retry',
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => showReportPdfActions(
              context,
              reportId: draft.reportID,
              localPath: draft.imagePath == null
                  ? null
                  : ReportPaths.pdf(File(draft.imagePath!).parent.path),
              authToken: widget.authToken,
            ),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_tr(context, 'Report PDF')),
          ),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            const Center(child: Icon(Icons.cloud_off_outlined, size: 48)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_tr(context, _error!), textAlign: TextAlign.center),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton(
                onPressed: _load,
                child: Text(_tr(context, 'Retry')),
              ),
            ),
            ..._drafts.map(_draftCard),
          ],
        ),
      );
    }
    if (_reports.isEmpty && _drafts.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 180),
            const Center(child: Icon(Icons.description_outlined, size: 48)),
            const SizedBox(height: 12),
            Center(
              child: Text(
                _tr(context, 'Your reports start here'),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                _tr(
                  context,
                  'Capture or choose a photo from Home to report a civic issue. Track every update here after submitting.',
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    final filtered = _reports.where((report) {
      final statusMatch =
          _filter == 'All' ||
          (_filter == 'Resolved'
              ? report.status.toLowerCase() == 'resolved'
              : report.status.toLowerCase() != 'resolved' &&
                    report.status != 'Invalid Report');
      return statusMatch &&
          '${report.issue} ${UiStrings.of(context).category(report.issue)} ${UiStrings.of(context).status(report.status)} ${report.description} ${report.id} ${report.readableLocation}'
              .toLowerCase()
              .contains(_query);
    }).toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(context, 'My reports'),
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      UiStrings.of(
                        context,
                      ).format('{submitted} submitted · {resolved} resolved', {
                        'submitted': _reports.length,
                        'resolved': _reports
                            .where((r) => r.status == 'Resolved')
                            .length,
                      }),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: _tr(context, 'Refresh reports'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: _tr(context, 'Search category, location or report ID'),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: ['All', 'Active', 'Resolved']
                .map(
                  (value) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(UiStrings.of(context).status(value)),
                      selected: _filter == value,
                      onSelected: (_) => setState(() => _filter = value),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount:
                  _drafts.length + (filtered.isEmpty ? 1 : filtered.length),
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index < _drafts.length) return _draftCard(_drafts[index]);
                index -= _drafts.length;
                if (filtered.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      _tr(context, 'No reports match your search.'),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                final report = filtered[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        leading: _ReportThumbnail(url: report.imageUrl),
                        title: Text(
                          UiStrings.of(context).category(report.issue),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            '${report.readableLocation.isEmpty ? report.description : report.readableLocation}\n${_formatDate(context, report.createdAt)}',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        trailing: _StatusChip(status: report.status),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReportDetailScreen(
                              report: report,
                              service: _service,
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12, bottom: 4),
                          child: TextButton.icon(
                            onPressed: () => showReportPdfActions(
                              context,
                              reportId: report.id,
                              remoteUrl: report.pdfUrl,
                              authToken: widget.authToken,
                            ),
                            icon: const Icon(Icons.picture_as_pdf_outlined),
                            label: Text(_tr(context, 'Report PDF')),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class ReportDetailScreen extends StatefulWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.service,
  });
  final ReportRecord report;
  final ReportService service;

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late ReportRecord _report;
  bool _loading = true;
  String? _error;
  List<ReportStatusEvent> _history = const [];
  bool _historyLoading = true;
  String? _historyError;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _loadDetails();
    _loadHistory();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final details = await widget.service.getReportDetails(
        reportId: _report.id,
        userId: _report.userId,
      );
      if (!mounted) return;
      setState(() {
        _report = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadHistory() async {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    try {
      final history = await widget.service.getStatusHistory(
        reportId: _report.id,
      );
      if (!mounted) return;
      setState(() {
        _history = history;
        _historyLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _historyLoading = false;
          _historyError = error.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(UiStrings.of(context).category(_report.issue)),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadDetails(), _loadHistory()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_report.imageUrl != null)
              Image.network(
                _report.imageUrl!,
                height: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 80,
                  child: Icon(Icons.broken_image_outlined),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _report.id,
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _StatusChip(status: _report.status),
              ],
            ),
            const SizedBox(height: 12),
            _DetailRow(
              label: 'Category',
              value: UiStrings.of(context).category(_report.issue),
            ),
            _DetailRow(label: 'Description', value: _report.description),
            _DetailRow(
              label: 'Created',
              value: _formatDate(context, _report.createdAt),
            ),
            _DetailRow(
              label: 'Location',
              value: _report.readableLocation.isEmpty
                  ? _tr(context, 'Coordinates unavailable')
                  : _report.readableLocation,
            ),
            if (_report.latitude != null && _report.longitude != null)
              _DetailRow(
                label: 'Coordinates',
                value: '${_report.latitude}, ${_report.longitude}',
              ),
            if (_report.priority != null)
              _DetailRow(label: 'Priority', value: _report.priority!),
            if (_report.resolutionNote != null)
              Card(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _tr(context, 'Resolution update'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(_report.resolutionNote!),
                      if (_report.resolvedAt != null)
                        Text(_formatDate(context, _report.resolvedAt!)),
                      if (_report.resolvedBy != null)
                        Text(
                          UiStrings.of(context).format('Updated by {name}', {
                            'name': _report.resolvedBy!,
                          }),
                        ),
                    ],
                  ),
                ),
              ),
            if (_report.audioUrl != null) ...[
              _DetailRow(label: 'Audio', value: _tr(context, 'Available')),
              AudioEvidencePlayer(
                reportId: _report.id,
                authToken: widget.service.authToken,
              ),
            ],
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(context, 'Report PDF'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _tr(
                        context,
                        'View, download or share your report document.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => showReportPdfActions(
                        context,
                        reportId: _report.id,
                        remoteUrl: _report.pdfUrl,
                        authToken: widget.service.authToken,
                      ),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(_tr(context, 'Open report PDF')),
                    ),
                  ],
                ),
              ),
            ),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: LinearProgressIndicator(),
              ),
            if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_tr(context, _error!)),
                trailing: TextButton(
                  onPressed: _loadDetails,
                  child: Text(_tr(context, 'Retry')),
                ),
              ),
            if (_historyLoading)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (_historyError != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_tr(context, 'Status history is unavailable')),
                subtitle: Text(_tr(context, _historyError!)),
                trailing: TextButton(
                  onPressed: _loadHistory,
                  child: Text(_tr(context, 'Retry')),
                ),
              ),
            if (!_historyLoading && _historyError == null && _history.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _tr(
                    context,
                    'No status changes yet. Updates will appear here.',
                  ),
                ),
              ),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                _tr(context, 'Status history'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              ..._history.map(
                (event) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.circle, size: 12),
                  title: Text(UiStrings.of(context).status(event.newStatus)),
                  subtitle: Text(
                    '${_formatDate(context, event.changedAt)} · ${_tr(context, event.source)}',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(context, label),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        SelectableText(value.isEmpty ? _tr(context, 'Not provided') : value),
      ],
    ),
  );
}

class _ReportThumbnail extends StatelessWidget {
  const _ReportThumbnail({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null) return const Icon(Icons.description_outlined);
    return Image.network(
      url!,
      width: 52,
      height: 52,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const Icon(Icons.broken_image_outlined),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = status == 'Resolved'
        ? Colors.green
        : status == 'Invalid Report'
        ? Colors.red
        : status == 'In Progress'
        ? Colors.blue
        : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        UiStrings.of(context).status(status.isEmpty ? 'Unknown' : status),
        style: TextStyle(
          fontSize: 11,
          color: color.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _formatDate(BuildContext context, String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  return UiStrings.of(context).date(date, pattern: 'd MMM yyyy, HH:mm');
}

Future<void> openRemoteFile(BuildContext context, String value) async {
  try {
    final uri = Uri.tryParse(value);
    if (uri != null &&
        await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      return;
    }
  } catch (_) {
    // Some phones have no application capable of opening this file.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(_tr(context, 'Unable to open this file.'))),
    );
  }
}

class AudioEvidencePlayer extends StatefulWidget {
  const AudioEvidencePlayer({
    super.key,
    this.url,
    this.reportId,
    this.authToken,
  });
  final String? url, reportId, authToken;

  @override
  State<AudioEvidencePlayer> createState() => _AudioEvidencePlayerState();
}

class _AudioEvidencePlayerState extends State<AudioEvidencePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _loading = false;
  String? _localPath;
  String? _error;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _subscriptions.add(
      _player.onDurationChanged.listen((value) {
        if (mounted) setState(() => _duration = value);
      }),
    );
    _subscriptions.add(
      _player.onPositionChanged.listen((value) {
        if (mounted) setState(() => _position = value);
      }),
    );
    _subscriptions.add(
      _player.onPlayerStateChanged.listen((state) {
        if (mounted) setState(() => _playing = state == PlayerState.playing);
      }),
    );
  }

  Future<void> _toggle() async {
    if (_loading) return;
    try {
      if (_playing) {
        await _player.pause();
      } else {
        if (widget.reportId != null) {
          setState(() => _loading = true);
          final path = _localPath ?? await _downloadPrivateAudio();
          if (!mounted) return;
          _localPath = path;
          await _player.play(DeviceFileSource(path));
        } else if (widget.url != null) {
          await _player.play(UrlSource(widget.url!));
        } else {
          throw const ApiClientException('Audio is unavailable.');
        }
      }
      if (mounted) setState(() => _error = null);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load audio. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String> _downloadPrivateAudio() async {
    final token = widget.authToken;
    if (token == null ||
        token.isEmpty ||
        AppConfig.normalizedBackendBaseUrl.isEmpty) {
      throw const ApiClientException('Authentication required');
    }
    final client = Dio(
      BaseOptions(
        baseUrl: AppConfig.normalizedBackendBaseUrl,
        connectTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 60),
        responseType: ResponseType.bytes,
        followRedirects: false,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    try {
      final response = await client.get<List<int>>(
        'api/reports/${Uri.encodeComponent(widget.reportId!)}/audio',
      );
      final bytes = response.data;
      final type = response.headers.value('content-type') ?? '';
      if (!type.startsWith('audio/') ||
          bytes == null ||
          bytes.isEmpty ||
          bytes.length > 25 * 1024 * 1024) {
        throw const ApiClientException('Audio is unavailable.');
      }
      final root = await getApplicationSupportDirectory();
      final directory = await Directory(
        '${root.path}${Platform.pathSeparator}private_audio',
      ).create(recursive: true);
      final id = widget.reportId!.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final file = File('${directory.path}${Platform.pathSeparator}$id.m4a');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } finally {
      client.close();
    }
  }

  @override
  void dispose() {
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final max = _duration.inMilliseconds.toDouble();
    final value = max == 0
        ? 0.0
        : _position.inMilliseconds
              .clamp(0, _duration.inMilliseconds)
              .toDouble();
    return Column(
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _loading ? null : _toggle,
              tooltip: _tr(context, _playing ? 'Pause audio' : 'Play audio'),
              icon: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_playing ? Icons.pause : Icons.play_arrow),
            ),
            Expanded(
              child: Slider(
                value: value,
                max: max == 0 ? 1 : max,
                onChanged: max == 0
                    ? null
                    : (next) =>
                          _player.seek(Duration(milliseconds: next.toInt())),
              ),
            ),
          ],
        ),
        if (_error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_tr(context, _error!)),
          ),
      ],
    );
  }
}

String _tr(BuildContext context, String value) =>
    UiStrings.of(context).text(value);
