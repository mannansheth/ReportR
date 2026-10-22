import 'dart:async';

import 'package:flutter/material.dart';
import '../../l10n/ui_strings.dart';
import 'package:flutter/services.dart';

import '../../app.dart';
import '../../l10n/app_localizations.dart';
import '../../services/notification_service.dart';
import '../../widgets/language_selector.dart';
import '../../widgets/brand.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.controller});
  final AppController controller;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _otpSent = false;
  String? _errorMessage;
  int _resendSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    NotificationService.receivedOtp.addListener(_receivedOtp);
  }

  void _receivedOtp() {
    final otp = NotificationService.receivedOtp.value;
    if (mounted && otp != null) {
      _otpController.text = otp;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    NotificationService.receivedOtp.removeListener(_receivedOtp);
    _nameController.dispose();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final refreshed = await widget.controller.refreshPushToken?.call();
    final token = refreshed ?? widget.controller.fcmToken;
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to register for notifications. Check internet access, allow notifications, and try again.';
      });
      return;
    }
    NotificationService.receivedOtp.value = null;
    _otpController.clear();
    final result = await widget.controller.authService.sendOtp(
      name: _nameController.text,
      phone: _phoneController.text,
      token: token,
    );
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (result.isSuccess) _otpSent = true;
      _errorMessage = result.isSuccess ? null : result.message;
    });
    if (result.isSuccess) {
      _timer?.cancel();
      setState(() => _resendSeconds = 60);
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (!mounted || _resendSeconds <= 1) {
          timer.cancel();
          if (mounted) setState(() => _resendSeconds = 0);
        } else {
          setState(() => _resendSeconds--);
        }
      });
    }
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;
    if (!RegExp(r'^\d{6}$').hasMatch(_otpController.text.trim())) {
      setState(
        () => _errorMessage =
            'Enter the six-digit code from your ReportR notification.',
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    final result = await widget.controller.authService.verifyOtp(
      name: _nameController.text,
      phone: _phoneController.text,
      otp: _otpController.text,
      token: widget.controller.fcmToken ?? '',
    );
    if (!mounted) return;
    if (result.isSuccess && result.data != null) {
      await widget.controller.saveSession(
        result.data!,
        authToken: result.authToken,
      );
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('ReportR', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          LanguageSelector(controller: widget.controller),
          SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const ReportRLogo(size: 92),
                      ),
                    ),
                    SizedBox(height: 28),
                    Text(
                      l10n.authWelcome,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 10),
                    Text(
                      l10n.authSubtitle,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_isLoading && !_otpSent,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.name],
                      validator: (value) => (value?.trim().isEmpty ?? true)
                          ? UiStrings.of(context).text('Enter your name.')
                          : null,
                      decoration: InputDecoration(
                        labelText: l10n.enterName,
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_isLoading && !_otpSent,
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      validator: (value) =>
                          RegExp(r'^\d{10}$').hasMatch(value?.trim() ?? '')
                          ? null
                          : UiStrings.of(
                              context,
                            ).text('Enter a 10-digit phone number.'),
                      decoration: InputDecoration(
                        labelText: l10n.enterPhone,
                        prefixIcon: Icon(Icons.phone_outlined),
                        prefixText: '+91 ',
                      ),
                    ),
                    SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: colors.primaryContainer.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.notifications_active_outlined,
                            size: 22,
                            color: colors.primary,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              UiStrings.of(context).text(
                                'Your sign-in code arrives as a ReportR notification on this phone. Allow notifications and keep internet access enabled.',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_otpSent) ...[
                      SizedBox(height: 20),
                      TextFormField(
                        controller: _otpController,
                        enabled: !_isLoading,
                        keyboardType: TextInputType.number,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          labelText: l10n.enterOtp,
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        UiStrings.of(
                          context,
                        ).text('Code expires after 5 minutes.'),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          UiStrings.of(context).text(_errorMessage!),
                          style: TextStyle(color: colors.onErrorContainer),
                        ),
                      ),
                    ],
                    SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _isLoading
                          ? null
                          : (_otpSent ? _verifyOtp : _sendOtp),
                      icon: _isLoading
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _otpSent ? Icons.lock_open : Icons.arrow_forward,
                            ),
                      label: Text(_otpSent ? l10n.verifyOtp : l10n.sendOtp),
                    ),
                    if (_otpSent) ...[
                      TextButton(
                        onPressed: _isLoading || _resendSeconds > 0
                            ? null
                            : _sendOtp,
                        child: Text(
                          _resendSeconds > 0
                              ? UiStrings.of(context).format(
                                  'Resend code in {seconds}s',
                                  {'seconds': _resendSeconds},
                                )
                              : UiStrings.of(context).text('Resend code'),
                        ),
                      ),
                      TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => setState(() {
                                _otpSent = false;
                                _errorMessage = null;
                                _otpController.clear();
                              }),
                        child: Text(l10n.editLoginDetails),
                      ),
                    ],
                    SizedBox(height: 24),
                    Text(
                      UiStrings.of(
                        context,
                      ).text('A better neighbourhood starts with you.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
