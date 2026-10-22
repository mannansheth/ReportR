import 'package:flutter/material.dart';
import '../../l10n/ui_strings.dart';

import '../../core/network/api_client.dart';
import '../../models/report_record.dart';
import '../../models/user_session.dart';
import '../../services/authority_service.dart';
import '../../app.dart';
import '../profile/profile_screen.dart';
import '../reports/reports_screen.dart' show AudioEvidencePlayer;
import '../../widgets/report_pdf_actions.dart';

class AuthorityShell extends StatefulWidget {
  const AuthorityShell({
    super.key,
    required this.session,
    required this.authToken,
    this.controller,
    this.service,
  });

  final UserSession session;
  final String authToken;
  final AppController? controller;
  final AuthorityService? service;

  @override
  State<AuthorityShell> createState() => _AuthorityShellState();
}

class _AuthorityShellState extends State<AuthorityShell> {
  late final AuthorityService _service;
  String? _filter;
  List<ReportRecord> _reports = const [];
  bool _loading = true;
  String? _error;

  static const _filters = [
    'Issue Raised',
    'Verification pending',
    'In Progress',
    'Resolved',
    'Invalid Report',
  ];

  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        AuthorityService(ApiClient(authToken: widget.authToken));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reports = await _service.getReports(status: _filter);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(UiStrings.of(context).text('Authority reports')),
        actions: [
          IconButton(
            onPressed: _load,
            icon: Icon(Icons.refresh),
            tooltip: UiStrings.of(context).text('Refresh queue'),
          ),
          if (widget.controller != null)
            IconButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: Text(UiStrings.of(context).text('Profile')),
                    ),
                    body: ProfileScreen(controller: widget.controller!),
                  ),
                ),
              ),
              icon: Icon(Icons.account_circle_outlined),
              tooltip: UiStrings.of(context).text('Profile and sign out'),
            ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    UiStrings.of(
                      context,
                    ).format('Welcome, {name}', {'name': widget.session.name}),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 12),
                Flexible(
                  child: DropdownButton<String?>(
                    isExpanded: true,
                    value: _filter,
                    hint: Text(UiStrings.of(context).text('Queue')),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(UiStrings.of(context).text('Active queue')),
                      ),
                      ..._filters.map(
                        (status) => DropdownMenuItem<String?>(
                          value: status,
                          child: Text(UiStrings.of(context).status(status)),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _filter = value);
                      _load();
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_loading)
            Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Expanded(
              child: _ErrorState(message: _error!, onRetry: _load),
            )
          else if (_reports.isEmpty)
            Expanded(
              child: Center(
                child: Text(
                  UiStrings.of(context).text('No reports require attention.'),
                ),
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: _reports.length,
                  separatorBuilder: (_, _) => SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    return Card(
                      child: ListTile(
                        leading: report.imageUrl == null
                            ? Icon(Icons.description_outlined)
                            : Image.network(
                                report.imageUrl!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Icon(Icons.broken_image_outlined),
                              ),
                        title: Text(
                          UiStrings.of(context).category(report.issue),
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${report.id}\n${UiStrings.of(context).dateString(report.createdAt)}',
                        ),
                        isThreeLine: true,
                        trailing: _StatusChip(status: report.status),
                        onTap: () => _openDetails(report),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _openDetails(ReportRecord report) async {
    await Navigator.of(context).push<ReportRecord>(
      MaterialPageRoute(
        builder: (_) =>
            AuthorityReportDetailScreen(report: report, service: _service),
      ),
    );
    if (mounted) _load();
  }
}

class AuthorityReportDetailScreen extends StatefulWidget {
  const AuthorityReportDetailScreen({
    super.key,
    required this.report,
    required this.service,
  });

  final ReportRecord report;
  final AuthorityService service;

  @override
  State<AuthorityReportDetailScreen> createState() =>
      _AuthorityReportDetailScreenState();
}

class _AuthorityReportDetailScreenState
    extends State<AuthorityReportDetailScreen> {
  late ReportRecord _report;
  bool _loading = true;
  bool _updating = false;
  bool _changed = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await widget.service.getReport(reportId: _report.id);
      if (!mounted) return;
      setState(() {
        _report = report;
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<void> _update(String status) async {
    String? note;
    if (status == 'Resolved') {
      note = await _resolutionNote();
      if (note == null) return;
    }
    setState(() {
      _updating = true;
      _error = null;
    });
    try {
      final report = await widget.service.updateStatus(
        reportId: _report.id,
        status: status,
        resolutionNote: note,
      );
      if (!mounted) return;
      setState(() {
        _report = report;
        _updating = false;
        _changed = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            UiStrings.of(context).format('Report moved to {status}.', {
              'status': UiStrings.of(context).status(status),
            }),
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _updating = false;
          _error = error.toString();
        });
      }
    }
  }

  Future<String?> _resolutionNote() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(UiStrings.of(context).text('Resolution note')),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: UiStrings.of(
              context,
            ).text('Describe the completed work.'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(UiStrings.of(context).text('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(UiStrings.of(context).text('Resolve')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null || result.isEmpty) {
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UiStrings.of(context).text('A resolution note is required.'),
            ),
          ),
        );
      }
      return null;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(UiStrings.of(context).category(_report.issue)),
        leading: BackButton(
          onPressed: () => Navigator.pop(context, _changed ? _report : null),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            if (_report.imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  _report.imageUrl!,
                  height: 240,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => SizedBox(
                    height: 100,
                    child: Center(child: Icon(Icons.broken_image_outlined)),
                  ),
                ),
              ),
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(_report.id, overflow: TextOverflow.ellipsis),
                ),
                _StatusChip(status: _report.status),
              ],
            ),
            SizedBox(height: 12),
            _DetailRow(label: 'Category', value: _report.issue),
            _DetailRow(label: 'Description', value: _report.description),
            _DetailRow(label: 'Location', value: _report.readableLocation),
            _DetailRow(label: 'Created', value: _report.createdAt),
            if (_report.priority != null)
              _DetailRow(label: 'Priority', value: _report.priority!),
            if (_report.audioUrl != null)
              AudioEvidencePlayer(
                reportId: _report.id,
                authToken: widget.service.authToken,
              ),
            OutlinedButton.icon(
              onPressed: () => showReportPdfActions(
                context,
                reportId: _report.id,
                remoteUrl: _report.pdfUrl,
                authToken: widget.service.authToken,
              ),
              icon: Icon(Icons.picture_as_pdf_outlined),
              label: Text(UiStrings.of(context).text('Open report PDF')),
            ),
            if (_report.resolutionNote != null)
              _DetailRow(label: 'Resolution', value: _report.resolutionNote!),
            if (_error != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(UiStrings.of(context).text(_error!)),
                trailing: TextButton(
                  onPressed: _load,
                  child: Text(UiStrings.of(context).text('Retry')),
                ),
              ),
            if (_loading || _updating)
              Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (!_loading && !_updating) ...[
              SizedBox(height: 20),
              _ActionButtons(status: _report.status, onUpdate: _update),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({required this.status, required this.onUpdate});
  final String status;
  final ValueChanged<String> onUpdate;

  @override
  Widget build(BuildContext context) {
    final actions = switch (status) {
      'Issue Raised' => [('Verification pending', 'Send to verification')],
      'Verification pending' => [
        ('In Progress', 'Accept report'),
        ('Invalid Report', 'Reject report'),
      ],
      'In Progress' => [('Resolved', 'Mark resolved')],
      _ => <(String, String)>[],
    };
    if (actions.isEmpty) {
      return Text(
        UiStrings.of(context).text('No actions are available for this status.'),
      );
    }
    return Column(
      children: actions
          .map(
            (action) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => onUpdate(action.$1),
                  child: Text(UiStrings.of(context).text(action.$2)),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;
  @override
  Widget build(BuildContext context) => Chip(
    label: Text(
      UiStrings.of(context).status(status),
      style: TextStyle(fontSize: 11),
    ),
    visualDensity: VisualDensity.compact,
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          UiStrings.of(context).text(label),
          style: Theme.of(context).textTheme.labelMedium,
        ),
        SizedBox(height: 4),
        SelectableText(
          value.isEmpty
              ? UiStrings.of(context).text('Unavailable')
              : label == 'Category'
              ? UiStrings.of(context).category(value)
              : label == 'Created'
              ? UiStrings.of(context).dateString(value)
              : label == 'Priority'
              ? UiStrings.of(context).text(value)
              : value,
        ),
      ],
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            UiStrings.of(context).text(message),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            child: Text(UiStrings.of(context).text('Retry')),
          ),
        ],
      ),
    ),
  );
}
