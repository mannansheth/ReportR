import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../l10n/ui_strings.dart';
import '../services/report_pdf_service.dart';

Future<void> showReportPdfActions(
  BuildContext context, {
  required String reportId,
  String? localPath,
  String? remoteUrl,
  bool submitted = false,
  String? authToken,
  ReportPdfService? service,
}) => showDialog<void>(
  context: context,
  barrierDismissible: !submitted,
  builder: (_) => _ReportPdfActions(
    reportId: reportId,
    localPath: localPath,
    remoteUrl: remoteUrl,
    submitted: submitted,
    service: service ?? ReportPdfService(authToken: authToken),
  ),
);

class _ReportPdfActions extends StatefulWidget {
  const _ReportPdfActions({
    required this.reportId,
    required this.localPath,
    required this.remoteUrl,
    required this.submitted,
    required this.service,
  });
  final String reportId;
  final String? localPath, remoteUrl;
  final bool submitted;
  final ReportPdfService service;
  @override
  State<_ReportPdfActions> createState() => _ReportPdfActionsState();
}

class _ReportPdfActionsState extends State<_ReportPdfActions> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final bytes = await widget.service.load(
        widget.reportId,
        localPath: widget.localPath,
        remoteUrl: widget.remoteUrl,
      );
      if (mounted) setState(() => _bytes = bytes);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Unable to load the report PDF. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final saved = await widget.service.save(_bytes!, widget.reportId);
      if (mounted && saved) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              UiStrings.of(context).text('PDF saved to the selected location.'),
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to save this PDF. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final box = context.findRenderObject() as RenderBox?;
      await widget.service.share(
        _bytes!,
        widget.reportId,
        origin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to share this PDF. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = UiStrings.of(context);
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        icon: Icon(
          widget.submitted
              ? Icons.check_circle_rounded
              : Icons.picture_as_pdf_rounded,
          color: widget.submitted ? Colors.green : colors.primary,
          size: 48,
        ),
        title: Text(
          strings.text(widget.submitted ? 'Report submitted' : 'Report PDF'),
        ),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  strings.text(
                    widget.submitted
                        ? 'Your report has been submitted. Keep a PDF copy for your records.'
                        : 'View, save or share a copy of your report.',
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  widget.reportId,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 20),
                if (_loading) ...[
                  const LinearProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    strings.text('Preparing PDF...'),
                    textAlign: TextAlign.center,
                  ),
                ] else if (_bytes != null) ...[
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ReportPdfPreviewScreen(
                                reportId: widget.reportId,
                                bytes: _bytes!,
                              ),
                            ),
                          ),
                    icon: const Icon(Icons.visibility_outlined),
                    label: Text(strings.text('View PDF')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy ? null : _save,
                    icon: const Icon(Icons.download_outlined),
                    label: Text(strings.text('Download PDF')),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _share,
                    icon: const Icon(Icons.share_outlined),
                    label: Text(strings.text('Share PDF')),
                  ),
                ],
                if (_busy)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: LinearProgressIndicator(),
                  ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    strings.text(_error!),
                    style: TextStyle(color: colors.error),
                    textAlign: TextAlign.center,
                  ),
                  if (_bytes == null)
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(strings.text('Try again')),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(strings.text(widget.submitted ? 'Done' : 'Close')),
          ),
        ],
      ),
    );
  }
}

class ReportPdfPreviewScreen extends StatelessWidget {
  const ReportPdfPreviewScreen({
    super.key,
    required this.reportId,
    required this.bytes,
  });
  final String reportId;
  final Uint8List bytes;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        UiStrings.of(context).format('Report PDF - {id}', {'id': reportId}),
      ),
    ),
    body: PdfPreview(
      build: (_) async => bytes,
      allowPrinting: false,
      allowSharing: false,
      canChangeOrientation: false,
      canChangePageFormat: false,
      canDebug: false,
      useActions: false,
      onError: (context, error) => Center(
        child: Text(UiStrings.of(context).text('PDF preview unavailable.')),
      ),
    ),
  );
}
