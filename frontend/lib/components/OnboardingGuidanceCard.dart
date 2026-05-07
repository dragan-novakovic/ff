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

    return Card(
      margin: const EdgeInsets.all(12),
      color: quest.claimable ? Colors.green.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  quest.claimable ? Icons.card_giftcard : Icons.tour,
                  color: quest.claimable ? Colors.green : Colors.blue,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tutorial: ${quest.title}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text('${line.completionPercent}%'),
              ],
            ),
            const SizedBox(height: 8),
            Text(quest.claimable
                ? 'Step complete. Claim your reward.'
                : quest.guidance),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: quest.progress),
            const SizedBox(height: 8),
            Text(
              'Progress ${quest.currentCount}/${quest.targetCount}'
              '${rewards.isEmpty ? '' : ' • Reward: $rewards'}',
              style: Theme.of(context).textTheme.bodySmall,
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
