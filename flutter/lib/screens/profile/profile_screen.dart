import 'package:flutter/material.dart';

import '../../app.dart';
import '../../core/network/api_client.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/ui_strings.dart';
import '../../services/profile_service.dart';
import '../../widgets/language_selector.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.controller,
    this.profileService,
    this.isActive = true,
  });
  final AppController controller;
  final ProfileService? profileService;
  final bool isActive;
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context);
  bool _saving = false;
  bool _loading = false;
  String? _error;
  ProfileService get _service =>
      widget.profileService ??
      ProfileService(ApiClient(authToken: widget.controller.authToken));
  @override
  void initState() {
    super.initState();
    if (widget.isActive) _load();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _load();
  }

  Future<void> _load() async {
    if (_loading || _saving || widget.controller.session == null) return;
    final userId = widget.controller.session!.id;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = await _service.getProfile();
      if (!mounted || widget.controller.session?.id != userId) return;
      await widget.controller.saveSession(
        session,
        authToken: widget.controller.authToken,
      );
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editName() async {
    var editedName = widget.controller.session?.name ?? '';
    final form = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileEditName),
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: editedName,
            onChanged: (value) => editedName = value,
            autofocus: true,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: l10n.profileFullName),
            validator: (v) => v == null || v.trim().length < 2
                ? l10n.profileNameValidation
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, editedName.trim());
              }
            },
            child: Text(l10n.profileSave),
          ),
        ],
      ),
    );
    if (name == null || !mounted || name == widget.controller.session?.name) {
      return;
    }
    setState(() => _saving = true);
    try {
      final session =
          await (widget.profileService ??
                  ProfileService(
                    ApiClient(authToken: widget.controller.authToken),
                  ))
              .updateName(name);
      await widget.controller.saveSession(
        session,
        authToken: widget.controller.authToken,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.profileUpdated)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(UiStrings.of(context).text(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileSignOutQuestion),
        content: Text(l10n.profileSignOutExplanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.profileCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.profileSignOut),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.controller.clearSession();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.controller.session;
    final theme = Theme.of(context);
    if (session == null) {
      return Center(child: Text(l10n.profileSignIn));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(20),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(UiStrings.of(context).text(_error!)),
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.pageRetry),
                    ),
                  ],
                ),
              ),
            ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 38,
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  child: Text(
                    session.name.trim().isEmpty
                        ? '?'
                        : session.name.trim().characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  session.name,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(session.number),
                const SizedBox(height: 12),
                Chip(
                  avatar: const Icon(Icons.verified_user_outlined, size: 18),
                  label: Text(UiStrings.of(context).text(session.role)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.profileAccountDetails,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(l10n.profileFullName),
                  subtitle: Text(session.name),
                  trailing: _saving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.edit_outlined),
                  onTap: _saving || _loading ? null : _editName,
                ),
                const Divider(height: 1, indent: 56),
                ListTile(
                  leading: const Icon(Icons.phone_outlined),
                  title: Text(l10n.profileVerifiedPhone),
                  subtitle: Text(session.number),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.profilePreferences,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.translate),
                      SizedBox(width: 12),
                      Text(
                        l10n.profileAppLanguage,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LanguageSelector(controller: widget.controller),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileTipsTitle,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.profileTips),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _saving ? null : _logout,
            icon: const Icon(Icons.logout),
            label: Text(l10n.profileSignOut),
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              padding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.profileTagline,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
