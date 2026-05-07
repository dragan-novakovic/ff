import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/models/AuthSecurity.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class AccountSecurityPage extends StatefulWidget {
  final User user;

  const AccountSecurityPage({super.key, required this.user});

  @override
  State<AccountSecurityPage> createState() => _AccountSecurityPageState();
}

class _AccountSecurityPageState extends State<AccountSecurityPage> {
  late final LoginBloc _loginBloc;
  late Future<AccountSecurityProfile> _profileFuture;
  final _verificationTokenController = TextEditingController();
  final _resetTokenController = TextEditingController();
  final _newPasswordController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loginBloc = Provider.of<LoginBloc>(context, listen: false);
    _profileFuture = _loginBloc.fetchAccountSecurity();
  }

  @override
  void dispose() {
    _verificationTokenController.dispose();
    _resetTokenController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _profileFuture = _loginBloc.fetchAccountSecurity();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_isSubmitting) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });
    try {
      await action();
      if (mounted) {
        await _reload();
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _requestEmailVerification() async {
    await _run(() async {
      final result = await _loginBloc.requestEmailVerification();
      if (result.devToken != null) {
        _verificationTokenController.text = result.devToken!;
      }
      _showMessage(result.message);
    });
  }

  Future<void> _confirmEmailVerification() async {
    await _run(() async {
      final result = await _loginBloc.confirmEmailVerification(
        _verificationTokenController.text.trim(),
      );
      _verificationTokenController.clear();
      _showMessage(result.message);
    });
  }

  Future<void> _requestPasswordReset() async {
    await _run(() async {
      final result = await _loginBloc.requestPasswordReset(widget.user.email);
      if (result.devToken != null) {
        _resetTokenController.text = result.devToken!;
      }
      _showMessage(result.message);
    });
  }

  Future<void> _confirmPasswordReset() async {
    await _run(() async {
      final result = await _loginBloc.confirmPasswordReset(
        token: _resetTokenController.text.trim(),
        password: _newPasswordController.text,
      );
      _resetTokenController.clear();
      _newPasswordController.clear();
      _showMessage(result.message);
    });
  }

  Future<void> _revokeAllSessions() async {
    await _run(() async {
      final result = await _loginBloc.revokeAllSessions();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account security'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _isSubmitting ? null : _reload,
          ),
        ],
      ),
      body: FutureBuilder<AccountSecurityProfile>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString(),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _reload,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final profile = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _identityCard(profile.user),
              const SizedBox(height: 12),
              _emailVerificationCard(profile.user),
              const SizedBox(height: 12),
              _passwordCard(),
              const SizedBox(height: 12),
              _sessionsCard(profile.sessions),
            ],
          );
        },
      ),
    );
  }

  Widget _identityCard(User user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Identity', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person),
              title: Text(user.username),
              subtitle: Text(user.email),
            ),
            Wrap(
              spacing: 8,
              children: user.roles
                  .map((role) => Chip(
                        label: Text(role),
                        avatar: const Icon(Icons.verified_user, size: 16),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emailVerificationCard(User user) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                user.emailVerified
                    ? Icons.mark_email_read
                    : Icons.mark_email_unread,
                color: user.emailVerified ? Colors.green : Colors.orange,
              ),
              title: Text(
                  user.emailVerified ? 'Email verified' : 'Email not verified'),
              subtitle:
                  const Text('Request a token and paste it below to verify.'),
            ),
            TextField(
              controller: _verificationTokenController,
              decoration:
                  const InputDecoration(labelText: 'Verification token'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _requestEmailVerification,
                  icon: const Icon(Icons.send),
                  label: const Text('Request token'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _confirmEmailVerification,
                  icon: const Icon(Icons.check),
                  label: const Text('Confirm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _passwordCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Password reset',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('Request a reset token for your account email.'),
            TextField(
              controller: _resetTokenController,
              decoration: const InputDecoration(labelText: 'Reset token'),
            ),
            TextField(
              controller: _newPasswordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting ? null : _requestPasswordReset,
                  icon: const Icon(Icons.key),
                  label: const Text('Request token'),
                ),
                ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _confirmPasswordReset,
                  icon: const Icon(Icons.lock_reset),
                  label: const Text('Reset password'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sessionsCard(List<AccountSession> sessions) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Refresh sessions',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Text('No refresh sessions were returned.')
            else
              ...sessions.map(
                (session) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    session.isActive ? Icons.phonelink_lock : Icons.block,
                    color: session.isActive ? Colors.green : Colors.grey,
                  ),
                  title: Text(session.sessionId),
                  subtitle: Text(
                    'Last seen ${_formatDate(session.lastSeenAt)} · expires ${_formatDate(session.expiresAt)}',
                  ),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _revokeAllSessions,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out everywhere'),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'unknown';
    }

    return date.toLocal().toString().split('.').first;
  }
}
