import 'package:ff/blocs/OnboardingQuestlineBloc.dart';
import 'package:ff/models/OnboardingQuestline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OnboardingGuidanceCard extends StatelessWidget {
  final OnboardingQuestline? questline;
  final String? route;
  final Future<void> Function(OnboardingQuest quest)? onClaim;
  final Future<void> Function(OnboardingQuest quest)? onSkip;
  final VoidCallback? onNavigate;

  const OnboardingGuidanceCard({
    super.key,
    required this.questline,
    this.route,
    this.onClaim,
    this.onSkip,
    this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final line = questline;
    final quest = line?.currentQuest;
    if (line == null || quest == null) {
      return const SizedBox.shrink();
    }
    if (route != null && quest.route != route) {
      return const SizedBox.shrink();
    }

    final rewards = <String>[
      if (quest.rewards.gold > 0) '${quest.rewards.gold} gold',
      if (quest.rewards.experience > 0) '${quest.rewards.experience} XP',
      if (quest.rewards.strength > 0) '${quest.rewards.strength} strength',
      if (quest.rewards.energy > 0) '${quest.rewards.energy} energy',
    ].join(' • ');
    final claiming = context
        .watch<OnboardingQuestlineBloc>()
        .claimingQuestIds
        .contains(quest.questId);
    final skipping = context
        .watch<OnboardingQuestlineBloc>()
        .skippingQuestIds
        .contains(quest.questId);

    final accent =
        quest.claimable ? const Color(0xFF22C55E) : const Color(0xFF38BDF8);
    return Card(
      margin: EdgeInsets.zero,
      color: const Color(0xFF0F2136),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withOpacity(0.34)),
                  ),
                  child: Icon(
                    quest.claimable ? Icons.card_giftcard : Icons.tour,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tutorial: ${quest.title}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: accent.withOpacity(0.28)),
                  ),
                  child: Text(
                    '${line.completionPercent}%',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              quest.claimable
                  ? 'Step complete. Claim your reward.'
                  : quest.guidance,
              style: TextStyle(color: Colors.white.withOpacity(0.72)),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: quest.progress,
                minHeight: 8,
                backgroundColor: Colors.white.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Progress ${quest.currentCount}/${quest.targetCount}'
              '${rewards.isEmpty ? '' : ' • Reward: $rewards'}',
              style: TextStyle(color: Colors.white.withOpacity(0.58)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (quest.claimable && onClaim != null)
                  ElevatedButton.icon(
                    onPressed: claiming ? null : () => onClaim!(quest),
                    icon: claiming
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.card_giftcard),
                    label: Text(claiming ? 'Claiming...' : 'Claim reward'),
                  ),
                if (!quest.claimable && onNavigate != null)
                  OutlinedButton.icon(
                    onPressed: onNavigate,
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Go to step'),
                  ),
                if (!quest.claimed && onSkip != null)
                  TextButton(
                    onPressed: skipping ? null : () => onSkip!(quest),
                    child: Text(skipping ? 'Skipping...' : 'Skip'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
