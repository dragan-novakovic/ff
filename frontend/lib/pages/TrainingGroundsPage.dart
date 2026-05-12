import 'package:ff/blocs/LoginBloc.dart';
import 'package:ff/blocs/PlayerBloc.dart';
import 'package:ff/blocs/TrainingGroundsBloc.dart';
import 'package:ff/models/PlayerState.dart';
import 'package:ff/models/TrainingGrounds.dart';
import 'package:ff/models/User.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class TrainingGroundsPage extends StatefulWidget {
  final User user;

  const TrainingGroundsPage({super.key, required this.user});

  @override
  State<TrainingGroundsPage> createState() => _TrainingGroundsPageState();
}

class _TrainingGroundsPageState extends State<TrainingGroundsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final login = context.read<LoginBloc>();
    final bloc = context.read<TrainingGroundsBloc>();
    bloc.setBearerToken(login.currentToken);
    await bloc.load(widget.user.uid);
  }

  Future<void> _train() async {
    final login = context.read<LoginBloc>();
    final groundsBloc = context.read<TrainingGroundsBloc>();
    final playerBloc = context.read<PlayerBloc>();
    groundsBloc.setBearerToken(login.currentToken);
    playerBloc.setBearerToken(login.currentToken);
    final result = await groundsBloc.train(widget.user.uid);
    if (result != null) {
      await playerBloc.loadState(widget.user.uid);
      await playerBloc.loadDailyObjectives(widget.user.uid);
    }
    if (!mounted) {
      return;
    }

    final message = result?.message ?? groundsBloc.error;
    if (message != null && message.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6F1),
      appBar: AppBar(
        title: const Text('Training Grounds'),
        backgroundColor: const Color(0xFF253A2E),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh training grounds',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Consumer<TrainingGroundsBloc>(
        builder: (context, bloc, _) {
          if (bloc.isLoading && bloc.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = bloc.summary;
          return RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              children: [
                if (bloc.error != null)
                  _TrainingErrorCard(message: bloc.error!, onRetry: _load),
                if (bloc.lastTraining != null)
                  _TrainingResultCard(result: bloc.lastTraining!),
                if (summary == null)
                  _TrainingFallbackCard(onRetry: _load)
                else ...[
                  _TrainingHero(summary: summary),
                  _TrainingReadinessCard(summary: summary),
                  _DailyDrillCard(
                    summary: summary,
                    isTraining: bloc.isTraining,
                    onTrain: summary.canTrainToday ? _train : null,
                  ),
                  const _TrainingProgramsCard(),
                  _TrainingHistoryCard(sessions: summary.recentSessions),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TrainingErrorCard extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _TrainingErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Colors.red.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.red.shade900),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _TrainingFallbackCard extends StatelessWidget {
  final Future<void> Function() onRetry;

  const _TrainingFallbackCard({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.fitness_center,
                color: Color(0xFF2E7D32),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Training yard is waiting for backend data',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Refresh to load your daily drill, rewards, reset timer, and training history.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Load Training Grounds'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingHero extends StatelessWidget {
  final TrainingGroundsSummary summary;

  const _TrainingHero({required this.summary});

  @override
  Widget build(BuildContext context) {
    final state = summary.state;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF13251C), Color(0xFF2F5D3A), Color(0xFF7A5D1B)],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -30,
              top: -28,
              child: Icon(
                Icons.security,
                size: 156,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: Icon(
                Icons.military_tech,
                size: 72,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.22),
                          ),
                        ),
                        child: const Icon(
                          Icons.fitness_center,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const Spacer(),
                      _StatusPill(
                        label: summary.canTrainToday
                            ? 'Ready to train'
                            : 'Drill complete',
                        color: summary.canTrainToday
                            ? const Color(0xFF86EFAC)
                            : const Color(0xFFFDE68A),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Training Grounds',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.6,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Build permanent strength with one real daily drill. The yard tracks your progress, rewards, and recent sessions.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.82),
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      _HeroMetric(
                        label: 'Strength',
                        value: state.strength.toString(),
                        icon: Icons.sports_martial_arts,
                      ),
                      _HeroMetric(
                        label: 'Level',
                        value: state.level.toString(),
                        icon: Icons.military_tech,
                      ),
                      _HeroMetric(
                        label: 'Energy',
                        value: '${state.energy}/${state.maxEnergy}',
                        icon: Icons.flash_on,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _HeroProgress(state: state),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.75)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 9, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroProgress extends StatelessWidget {
  final PlayerState state;

  const _HeroProgress({required this.state});

  @override
  Widget build(BuildContext context) {
    final levelStart = (state.level - 1) * 100;
    final levelProgress = (state.experience - levelStart).clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Level ${state.level} progress',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            Text(
              '$levelProgress/100 XP',
              style: TextStyle(color: Colors.white.withOpacity(0.78)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: state.experienceProgress,
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.18),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFACC15)),
          ),
        ),
      ],
    );
  }
}

class _TrainingReadinessCard extends StatelessWidget {
  final TrainingGroundsSummary summary;

  const _TrainingReadinessCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final state = summary.state;
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.track_changes,
              title: "Today's readiness",
              subtitle: summary.canTrainToday
                  ? 'The yard is open. Complete your daily drill.'
                  : 'Daily drill logged. Come back after reset.',
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ReadinessTile(
                    icon: Icons.schedule,
                    label: 'Next reset',
                    value: summary.canTrainToday
                        ? 'Available now'
                        : _formatCountdown(summary.nextResetAt),
                    color: const Color(0xFF2E7D32),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _ReadinessTile(
                    icon: Icons.flag,
                    label: 'Status',
                    value: summary.hasTrainedToday ? 'Complete' : 'Pending',
                    color: summary.hasTrainedToday
                        ? const Color(0xFF2563EB)
                        : const Color(0xFFB45309),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ProgressLine(
              label: 'Energy reserve',
              valueLabel: '${state.energy}/${state.maxEnergy}',
              value: state.energyProgress,
              color: const Color(0xFF16A34A),
            ),
            const SizedBox(height: 12),
            _ProgressLine(
              label: 'Experience toward next level',
              valueLabel: '${state.experienceToNextLevel} XP needed',
              value: state.experienceProgress,
              color: const Color(0xFFEAB308),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ReadinessTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;

  const _ProgressLine({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Text(valueLabel, style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 9,
            backgroundColor: color.withOpacity(0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFF253A2E),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(color: Colors.grey.shade700, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _HeroMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFFACC15), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.74),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyDrillCard extends StatelessWidget {
  final TrainingGroundsSummary summary;
  final bool isTraining;
  final Future<void> Function()? onTrain;

  const _DailyDrillCard({
    required this.summary,
    required this.isTraining,
    required this.onTrain,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.fitness_center,
              title: 'Basic daily drill',
              subtitle:
                  'The active v1 drill is persisted and limited to one completion per daily reset.',
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFED7AA)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF97316),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.local_fire_department,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Morning strength circuit',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          summary.canTrainToday
                              ? 'Ready now. Complete it to grow your soldier.'
                              : 'Logged for today. Reset in ${_formatCountdown(summary.nextResetAt)}.',
                          style: TextStyle(color: Colors.grey.shade800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text('+${summary.strengthReward} strength'),
                ),
                Chip(
                  avatar: const Icon(Icons.trending_up, size: 18),
                  label: Text('+${summary.experienceReward} XP'),
                ),
                Chip(
                  avatar: Icon(
                    summary.canTrainToday ? Icons.play_arrow : Icons.check,
                    size: 18,
                  ),
                  label: Text(
                    summary.canTrainToday ? 'Ready today' : 'Done until reset',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isTraining ? null : onTrain,
                icon: isTraining
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(summary.canTrainToday
                        ? Icons.fitness_center
                        : Icons.check_circle),
                style: ElevatedButton.styleFrom(
                  backgroundColor: summary.canTrainToday
                      ? const Color(0xFF2E7D32)
                      : Colors.grey.shade500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                label: Text(summary.canTrainToday
                    ? 'Start daily training'
                    : 'Training complete today'),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                summary.canTrainToday
                    ? 'Rewards are applied immediately to your backend player state.'
                    : 'Next drill unlocks ${_formatDateTime(summary.nextResetAt)}.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrainingProgramsCard extends StatelessWidget {
  const _TrainingProgramsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.map,
              title: 'Training yard',
              subtitle:
                  'A fuller academy layout is visible now; locked programs stay disabled until backend rules exist.',
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 620;
                final itemWidth = wide
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _ProgramTile(
                      width: itemWidth,
                      icon: Icons.fitness_center,
                      title: 'Basic drill lane',
                      description: 'Daily strength and XP training.',
                      badge: 'Active',
                      color: const Color(0xFF2E7D32),
                      locked: false,
                    ),
                    _ProgramTile(
                      width: itemWidth,
                      icon: Icons.flash_on,
                      title: 'Advanced conditioning',
                      description: 'Energy-based stamina work for later.',
                      badge: 'Soon',
                      color: const Color(0xFF0F766E),
                      locked: true,
                    ),
                    _ProgramTile(
                      width: itemWidth,
                      icon: Icons.security,
                      title: 'Weapon practice',
                      description: 'Future combat preparation drills.',
                      badge: 'Soon',
                      color: const Color(0xFF7C3AED),
                      locked: true,
                    ),
                    _ProgramTile(
                      width: itemWidth,
                      icon: Icons.military_tech,
                      title: 'Military academy',
                      description: 'Ranks, perks, and specialization later.',
                      badge: 'Soon',
                      color: const Color(0xFFB45309),
                      locked: true,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgramTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final String title;
  final String description;
  final String badge;
  final Color color;
  final bool locked;

  const _ProgramTile({
    required this.width,
    required this.icon,
    required this.title,
    required this.description,
    required this.badge,
    required this.color,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: locked ? Colors.grey.shade100 : color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: locked ? Colors.grey.shade300 : color.withOpacity(0.28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: locked ? Colors.grey.shade300 : color,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              locked ? Icons.lock : icon,
              color: locked ? Colors.grey.shade700 : Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: locked
                            ? Colors.grey.shade300
                            : color.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: locked ? Colors.grey.shade700 : color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.25),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrainingResultCard extends StatelessWidget {
  final PlayerActionResult result;

  const _TrainingResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: result.completed ? Colors.green.shade50 : Colors.blueGrey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: ListTile(
          leading: Icon(
            result.completed ? Icons.check_circle : Icons.info_outline,
            color: result.completed ? Colors.green : Colors.blueGrey,
          ),
          title: Text(result.message),
          subtitle: Text(
            '+${result.rewards.strength} strength - +${result.rewards.experience} XP',
          ),
        ),
      ),
    );
  }
}

class _TrainingHistoryCard extends StatelessWidget {
  final List<TrainingSession> sessions;

  const _TrainingHistoryCard({required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionHeader(
              icon: Icons.history,
              title: 'Training record',
              subtitle:
                  'Recent persisted sessions from the player-service training ledger.',
            ),
            const SizedBox(height: 16),
            if (sessions.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  children: [
                    Icon(Icons.flag, color: Colors.grey.shade600, size: 34),
                    const SizedBox(height: 10),
                    const Text(
                      'No drills completed yet',
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Start your first daily drill to create a permanent training record.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ],
                ),
              )
            else
              ...sessions.map((session) {
                return _TrainingSessionTile(session: session);
              }),
          ],
        ),
      ),
    );
  }
}

class _TrainingSessionTile extends StatelessWidget {
  final TrainingSession session;

  const _TrainingSessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final leveledUp = session.levelAfter > session.levelBefore;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.check, color: Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDateTime(session.trainedAt),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  'Strength ${session.strengthBefore} -> ${session.strengthAfter} '
                  '(+${session.strengthGained}) - XP +${session.experienceGained}',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          if (leveledUp)
            Chip(
              label: Text('Level ${session.levelAfter}'),
              backgroundColor: const Color(0xFFFEF3C7),
            ),
        ],
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  return DateFormat('MMM d, HH:mm').format(value.toLocal());
}

String _formatCountdown(DateTime value) {
  final remaining = value.toLocal().difference(DateTime.now());
  if (remaining.isNegative || remaining.inSeconds <= 0) {
    return 'ready now';
  }

  final hours = remaining.inHours;
  final minutes = remaining.inMinutes.remainder(60);
  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}m';
  }
  if (hours > 0) {
    return '${hours}h';
  }
  if (minutes <= 0) {
    return '<1m';
  }
  return '${minutes}m';
}
