import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/ui_strings.dart';
import '../../models/community_analytics.dart';
import '../../models/report_analytics.dart';
import '../../models/user_session.dart';
import '../../services/analytics_service.dart';
import '../../services/report_service.dart';
import '../../widgets/brand.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({
    super.key,
    required this.session,
    this.authToken,
    this.isActive = true,
    this.analyticsService,
    this.reportService,
  });
  final UserSession? session;
  final String? authToken;
  final bool isActive;
  final AnalyticsService? analyticsService;
  final ReportService? reportService;
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  String _scope = 'community';
  CommunityAnalytics? _data;
  String? _error;
  bool _loading = false;
  int _generation = 0;
  DateTime? _updated;
  UiStrings get ui => UiStrings.of(context);
  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((!oldWidget.isActive && widget.isActive) ||
        oldWidget.session?.id != widget.session?.id) {
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final scope = _scope;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final legacy = widget.reportService;
      final data = legacy != null
          ? CommunityAnalytics.fromReports(
              ReportAnalytics(
                await legacy.getUserReports(widget.session?.id ?? ''),
              ),
            )
          : await (widget.analyticsService ??
                    AnalyticsService(ApiClient(authToken: widget.authToken)))
                .load(scope: scope);
      if (mounted && generation == _generation) {
        setState(() {
          _data = data;
          _updated = DateTime.now();
        });
      }
    } catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.toString());
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  void _changeScope(Set<String> scopes) {
    if (scopes.first == _scope) return;
    setState(() {
      _scope = scopes.first;
      _data = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context);
    final data = _data;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            ui.text(_scope == 'community' ? 'Community impact' : 'My impact'),
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            ui.text(
              _scope == 'community'
                  ? 'See reports and progress across the whole community.'
                  : 'Your reports and the progress they are making.',
            ),
          ),
          const SizedBox(height: 20),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(
                value: 'community',
                icon: const Icon(Icons.groups_outlined),
                label: Text(ui.text('Community')),
              ),
              ButtonSegment(
                value: 'mine',
                icon: const Icon(Icons.person_outline),
                label: Text(ui.text('My impact')),
              ),
            ],
            selected: {_scope},
            onSelectionChanged: _changeScope,
          ),
          const SizedBox(height: 20),
          if (_loading && data == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const ReportRLoader(),
                  const SizedBox(height: 12),
                  Text(ui.text('Loading community progress...')),
                ],
              ),
            )
          else if (_loading)
            const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.cloud_off_outlined, size: 36),
                    const SizedBox(height: 12),
                    Text(ui.text(_error!), textAlign: TextAlign.center),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.pageRetry),
                    ),
                  ],
                ),
              ),
            ),
          if (data != null) ...[
            if (data.total == 0)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    ui.text(
                      _scope == 'community'
                          ? 'No reports have been submitted in this community yet.'
                          : 'You have not submitted a report yet. Switch to Community to explore local progress.',
                    ),
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    l10n.impactSubmitted,
                    data.total,
                    Icons.assignment_outlined,
                    colors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    l10n.impactResolved,
                    data.resolved,
                    Icons.task_alt,
                    Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _metric(
                    l10n.impactActive,
                    data.active,
                    Icons.pending_actions,
                    Colors.orange.shade800,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _metric(
                    l10n.impactInvalid,
                    data.invalid,
                    Icons.info_outline,
                    colors.error,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                ui.text(
                  'Live totals from submitted reports. Active excludes resolved and invalid reports.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            _section(
              l10n.impactResolutionRate,
              ui.text(
                'All submitted reports are included in the resolution rate.',
              ),
              [
                Text(
                  '${(data.resolutionRate * 100).round()}%',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.teal,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: data.resolutionRate.clamp(0, 1),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.teal,
                ),
                const SizedBox(height: 10),
                Text('${data.resolved} / ${data.total}'),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              ui.text('Community confirmations'),
              ui.text('Independent confirmations recorded on reports.'),
              [
                Text(
                  '${data.confirmationCount}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              ui.text('Resolved with photo evidence'),
              ui.text('Resolved reports with a recorded completion photo.'),
              [
                Text(
                  '${data.resolvedWithEvidence}',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(
              ui.text('Average time to resolve'),
              ui.text(
                'Based on resolved reports with valid submission and resolution times.',
              ),
              [
                Text(
                  data.averageResolutionHours == null
                      ? ui.text('No resolution times recorded yet.')
                      : ui.format('{hours} hours', {
                          'hours': data.averageResolutionHours!.toStringAsFixed(
                            1,
                          ),
                        }),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _section(l10n.impactActivity, l10n.impactActivitySubtitle, [
              for (final month in data.monthly)
                _bar(
                  month.date == null
                      ? month.month
                      : ui.date(month.date!, pattern: 'MMM yyyy'),
                  month.count,
                  data.monthly.fold<int>(
                    1,
                    (max, item) => item.count > max ? item.count : max,
                  ),
                  colors.primary,
                ),
            ]),
            const SizedBox(height: 12),
            _section(
              l10n.impactStatus,
              l10n.impactStatusSubtitle,
              data.byStatus.entries
                  .map(
                    (e) => _bar(
                      ui.status(e.key),
                      e.value,
                      data.total,
                      e.key == 'Resolved' ? Colors.teal : colors.primary,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _section(
              l10n.impactIssues,
              l10n.impactIssuesSubtitle,
              data.byCategory.entries
                  .map(
                    (e) => _bar(
                      ui.category(e.key),
                      e.value,
                      data.total,
                      colors.secondary,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            _section(
              ui.text('Reports by priority'),
              ui.text('Priority recorded on submitted reports.'),
              data.byPriority.entries
                  .map(
                    (e) => _bar(
                      ui.text(e.key),
                      e.value,
                      data.total,
                      colors.tertiary,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            if (_updated != null)
              Text(
                '${ui.date(_updated!, pattern: 'd MMM, h:mm a')} · ${l10n.impactRefresh}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _metric(String label, int value, IconData icon, Color color) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          Text(label),
        ],
      ),
    ),
  );
  Widget _section(String title, String subtitle, List<Widget> content) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          ...content,
        ],
      ),
    ),
  );
  Widget _bar(String label, int value, int max, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text('$value', style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: max == 0 ? 0 : (value / max).clamp(0, 1),
          minHeight: 7,
          color: color,
          borderRadius: BorderRadius.circular(7),
        ),
      ],
    ),
  );
}
