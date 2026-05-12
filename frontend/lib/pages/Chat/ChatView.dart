import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/pages/Chat/ChatBody.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/User.dart';

const _bbmBackground = Color(0xFF07100D);
const _bbmPanel = Color(0xFF101A16);
const _bbmPanelAlt = Color(0xFF14241E);
const _bbmGreen = Color(0xFF24D366);
const _bbmLime = Color(0xFFA3E635);
const _bbmBlue = Color(0xFF38BDF8);
const _bbmMuted = Color(0xFF9AA8A1);

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  @override
  Widget build(BuildContext context) {
    final loginBloc = Provider.of<LoginBloc>(context);
    return StreamBuilder(
      stream: loginBloc.userData,
      initialData: loginBloc.currentUser,
      builder: (context, snapshot) {
        final user = snapshot.data as User?;
        return Scaffold(
          backgroundColor: _bbmBackground,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: _bbmBackground,
            foregroundColor: Colors.white,
            titleSpacing: 0,
            title: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _bbmGreen.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _bbmGreen.withOpacity(0.45)),
                  ),
                  child: const Icon(Icons.chat_bubble, color: _bbmGreen),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Inbox',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        'BBM-style secure channels',
                        style: TextStyle(color: _bbmMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          drawer: Drawer(
            backgroundColor: _bbmBackground,
            child: chatDrawer(context, user),
          ),
          body: ChatBody(
            userId: user?.uid,
            contactId: 'global',
          ),
        );
      },
    );
  }
}

Widget chatDrawer(BuildContext context, User? user) {
  return SafeArea(
    child: Column(
      children: [
        _BbmDrawerHeader(user: user),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
            children: [
              const _DrawerSectionTitle(
                title: 'Conversations',
                subtitle: 'Open channels and direct contacts',
              ),
              if (user == null)
                const _BbmLoadingTile()
              else
                ...fetchInboxList(context, user.contacts, user.uid),
            ],
          ),
        ),
      ],
    ),
  );
}

List<Widget> fetchInboxList(
  BuildContext context,
  List<String>? data,
  String userId,
) {
  final contacts = <String>['global', ...?data]
      .where((name) => name.trim().isNotEmpty)
      .toSet()
      .toList();

  return contacts
      .map(
        (name) => _BbmContactTile(
          name: name,
          subtitle: name == 'global' ? 'World broadcast channel' : 'Direct PIN',
          onTap: () => Navigator.pushNamed(
            context,
            '/inbox/chat',
            arguments: {
              'id': name,
              'userId': userId,
            },
          ),
        ),
      )
      .toList();
}

class _BbmDrawerHeader extends StatelessWidget {
  final User? user;

  const _BbmDrawerHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user == null
        ? 'Connecting...'
        : user!.username.isNotEmpty
            ? user!.username
            : user!.email;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _bbmGreen.withOpacity(0.35)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF10251B),
            Color(0xFF0D3B25),
            Color(0xFF07100D),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _bbmGreen.withOpacity(0.55)),
                ),
                child: const Icon(
                  Icons.person_pin,
                  color: _bbmGreen,
                  size: 34,
                ),
              ),
              const Spacer(),
              const _BbmPresencePill(label: 'Available', color: _bbmGreen),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'PIN ${_bbmPin(user?.uid)}',
            style: const TextStyle(
              color: _bbmLime,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            user?.email ?? 'Loading profile and contacts',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: _bbmMuted),
          ),
        ],
      ),
    );
  }
}

class _DrawerSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _DrawerSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: _bbmGreen,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: const TextStyle(color: _bbmMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _BbmContactTile extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback onTap;

  const _BbmContactTile({
    required this.name,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGlobal = name == 'global';
    final color = isGlobal ? _bbmBlue : _bbmGreen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _bbmPanel,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: color.withOpacity(0.42)),
                      ),
                      child: Icon(
                        isGlobal ? Icons.public : Icons.person,
                        color: color,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: _bbmGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: _bbmPanel, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isGlobal ? 'Global Chat' : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$subtitle - PIN ${_bbmPin(name)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _bbmMuted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: _bbmMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BbmLoadingTile extends StatelessWidget {
  const _BbmLoadingTile();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bbmPanel,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Loading inbox...', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _BbmPresencePill extends StatelessWidget {
  final String label;
  final Color color;

  const _BbmPresencePill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

String _bbmPin(String? value) {
  final source = value == null || value.isEmpty ? 'offline' : value;
  final hash = source.hashCode.abs().toRadixString(16).toUpperCase();
  return hash.padLeft(8, '0').substring(0, 8);
}
