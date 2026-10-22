import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../l10n/ui_strings.dart';
import '../../models/community_report.dart';
import '../../models/user_session.dart';
import '../../services/community_service.dart';
import '../../services/map_distance_service.dart';
import 'community_report_detail_screen.dart';

class CommunityReportsScreen extends StatefulWidget {
  const CommunityReportsScreen({
    super.key,
    this.session,
    this.authToken,
    this.isActive = true,
    this.service,
    this.locationService,
  });
  final UserSession? session;
  final String? authToken;
  final bool isActive;
  final CommunityService? service;
  final CommunityLocationService? locationService;
  @override
  State<CommunityReportsScreen> createState() => _CommunityReportsScreenState();
}

class _CommunityReportsScreenState extends State<CommunityReportsScreen> {
  late final CommunityService _service;
  List<CommunityReport> _reports = [];
  CommunityPosition? _location;
  String _sort = 'priority';
  String? _error;
  String? _confirmingId;
  bool _loading = false, _hasMore = false, _locating = false;
  int _page = 0, _total = 0;
  UiStrings get strings => UiStrings.of(context);
  @override
  void initState() {
    super.initState();
    _service =
        widget.service ??
        CommunityService(ApiClient(authToken: widget.authToken));
    _load();
  }

  @override
  void didUpdateWidget(covariant CommunityReportsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) _load();
  }

  Future<void> _load({bool more = false}) async {
    if (_loading || _confirmingId != null || !mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.getReports(
        page: more ? _page + 1 : 1,
        sort: _sort,
        location: _location,
      );
      if (mounted) {
        setState(() {
          _reports = more
              ? [
                  ..._reports,
                  ...page.reports.where(
                    (report) =>
                        !_reports.any((previous) => previous.id == report.id),
                  ),
                ]
              : page.reports;
          _page = page.page;
          _hasMore = page.hasMore;
          _total = page.total;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _chooseSort(String sort) async {
    if (_loading || _locating || _confirmingId != null || sort == _sort) return;
    if (sort == 'nearby') {
      setState(() => _locating = true);
      try {
        _location = await (widget.locationService ?? CommunityLocationService())
            .currentPosition();
      } catch (error) {
        if (mounted) setState(() => _error = error.toString());
        return;
      } finally {
        if (mounted) setState(() => _locating = false);
      }
    }
    if (!mounted) return;
    setState(() => _sort = sort);
    await _load();
  }

  Future<void> _open(CommunityReport report) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CommunityReportDetailScreen(
          report: report,
          session: widget.session,
          authToken: widget.authToken,
          service: _service,
          locationService: widget.locationService,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _confirm(CommunityReport report) async {
    if (_confirmingId != null || report.confirmedByMe || !report.isOpen) return;
    setState(() {
      _confirmingId = report.id;
      _error = null;
    });
    try {
      final position =
          await (widget.locationService ?? CommunityLocationService())
              .currentPosition();
      final distance = MapDistance.meters(
        position.latitude,
        position.longitude,
        report.latitude,
        report.longitude,
      );
      if (!CommunityRange.canConfirm(distance)) {
        throw const ApiClientException(
          'Move within 500 metres of the issue to confirm it.',
        );
      }
      final updated = await _service.confirm(report.id, position);
      if (!mounted) return;
      setState(() {
        _reports = _reports
            .map((item) => item.id == updated.id ? updated : item)
            .toList();
        if (_sort == 'priority') {
          _reports.sort((a, b) => b.priority.compareTo(a.priority));
        }
      });
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
      if (mounted) setState(() => _confirmingId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.text('Community issues'),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    strings.format('{count} reports across the community', {
                      'count': _total,
                    }),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loading ? null : () => _load(),
              tooltip: strings.text('Refresh reports'),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(strings.text('Highest priority')),
              selected: _sort == 'priority',
              onSelected: (_) => _chooseSort('priority'),
            ),
            ChoiceChip(
              label: Text(strings.text('Nearest first')),
              avatar: const Icon(Icons.near_me_outlined, size: 16),
              selected: _sort == 'nearby',
              onSelected: (_) => _chooseSort('nearby'),
            ),
          ],
        ),
      ),
      if (_locating || (_loading && _reports.isNotEmpty))
        const LinearProgressIndicator(),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            strings.text(_error!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      Expanded(
        child: RefreshIndicator(
          onRefresh: () => _load(),
          child: _loading && _reports.isEmpty
              ? ListView(
                  children: const [
                    Padding(
                      padding: EdgeInsets.all(80),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ],
                )
              : ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: _reports.isEmpty
                      ? 1
                      : _reports.length + (_hasMore ? 1 : 0),
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (_reports.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            const Icon(Icons.location_city_outlined, size: 52),
                            const SizedBox(height: 16),
                            Text(
                              strings.text(
                                _error == null
                                    ? 'No community reports yet. Be the first to report an issue.'
                                    : 'Unable to load community reports.',
                              ),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => _load(),
                              child: Text(strings.text('Retry')),
                            ),
                          ],
                        ),
                      );
                    }
                    if (index == _reports.length) {
                      return OutlinedButton(
                        onPressed: _loading ? null : () => _load(more: true),
                        child: Text(strings.text('Load more reports')),
                      );
                    }
                    final report = _reports[index];
                    return CommunityReportCard(
                      report: report,
                      onTap: () => _open(report),
                      onConfirm:
                          _loading ||
                              _confirmingId != null ||
                              report.confirmedByMe ||
                              !report.isOpen
                          ? null
                          : () => _confirm(report),
                      confirming: _confirmingId == report.id,
                    );
                  },
                ),
        ),
      ),
    ],
  );
}

class CommunityReportCard extends StatelessWidget {
  const CommunityReportCard({
    super.key,
    required this.report,
    required this.onTap,
    this.onConfirm,
    this.confirming = false,
  });
  final CommunityReport report;
  final VoidCallback onTap;
  final VoidCallback? onConfirm;
  final bool confirming;
  @override
  Widget build(BuildContext context) {
    final strings = UiStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (report.imageUrl?.isNotEmpty == true) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        report.imageUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox(
                          width: 70,
                          height: 70,
                          child: Icon(Icons.image_not_supported_outlined),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.category(report.issue),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          report.locationName.isEmpty
                              ? report.description
                              : report.locationName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      strings.status(report.status),
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    avatar: const Icon(Icons.people_outline, size: 16),
                    label: Text(
                      strings.format('Reported by {count} people', {
                        'count': report.confirmationCount,
                      }),
                    ),
                  ),
                  Chip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: colors.primaryContainer,
                    label: Text(
                      strings.format('Priority {priority}', {
                        'priority': report.priority.toStringAsFixed(0),
                      }),
                    ),
                  ),
                  if (report.distanceMeters != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        strings.format('{distance} km away', {
                          'distance': (report.distanceMeters! / 1000)
                              .toStringAsFixed(1),
                        }),
                      ),
                    ),
                ],
              ),
              if (report.resolutionWeight > 0 && !report.isResolved)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: report.resolutionProgress),
                      const SizedBox(height: 5),
                      Text(
                        strings.text(
                          'Community resolution verification in progress',
                        ),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              if (report.confirmedByMe)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    strings.text('You confirmed this issue'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              if (report.isOpen && !report.confirmedByMe)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onConfirm,
                    icon: confirming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.visibility_outlined),
                    label: Text(strings.text('I see this too')),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
