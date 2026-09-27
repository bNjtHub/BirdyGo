/// Passive home entry: restoring a checklist never starts a GPS request.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/utils/app_icons.dart';
import '../design/birdy_tokens.dart';
import 'daily_goal_providers.dart';

class DailyGoalCard extends ConsumerWidget {
  const DailyGoalCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final goal = ref.watch(dailyGoalProvider).goal;
    final completed =
        goal == null ? null : ref.watch(dailyGoalProgressProvider);
    final c = BirdyColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      color: c.surface1,
      child: InkWell(
        borderRadius: BorderRadius.circular(BirdyRadii.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(BirdySpace.m),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(AppIcons.flagRounded),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.forkDailyGoalTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(AppIcons.chevronRight),
                ],
              ),
              const SizedBox(height: 8),
              if (goal == null) ...[
                Text(l10n.forkDailyGoalIntro),
                const SizedBox(height: 8),
                Text(
                  l10n.forkDailyGoalStart,
                  style: TextStyle(color: c.accentText),
                ),
              ] else if (completed!.hasError)
                Text(l10n.forkDailyGoalError)
              else if (completed.isLoading)
                const LinearProgressIndicator()
              else ...[
                Text(
                  l10n.forkDailyGoalProgress(
                    completed.value!.length,
                    goal.total,
                  ),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value:
                      goal.total == 0
                          ? 0
                          : completed.value!.length / goal.total,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
