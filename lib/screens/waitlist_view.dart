import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../state/bus_state.dart';

class WaitlistView extends StatelessWidget {
  const WaitlistView({
    super.key,
    required this.isFull,
    required this.waitlistNameController,
    required this.reasonController,
    required this.waitlistPriority,
    required this.onPriorityChanged,
    required this.waitlistError,
    required this.onJoin,
    required this.onBack,
  });

  final bool isFull;
  final TextEditingController waitlistNameController;
  final TextEditingController reasonController;
  final bool waitlistPriority;
  final ValueChanged<bool> onPriorityChanged;
  final String waitlistError;
  final VoidCallback onJoin;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusState>();
    final fullWaitlist = state.waitlist;
    final waitlist = state.visibleWaitlist;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onBack,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
              ),
              const SizedBox(width: 10),
              const Text('Waitlist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 12),
          if (fullWaitlist.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: state.waitlistFilter == WaitlistFilter.all,
                  onSelected: (_) => context.read<BusState>().setWaitlistFilter(WaitlistFilter.all),
                ),
                ChoiceChip(
                  label: const Text('Priority'),
                  selected: state.waitlistFilter == WaitlistFilter.priorityOnly,
                  onSelected: (_) => context.read<BusState>().setWaitlistFilter(WaitlistFilter.priorityOnly),
                ),
                ChoiceChip(
                  label: const Text('Regular'),
                  selected: state.waitlistFilter == WaitlistFilter.regularOnly,
                  onSelected: (_) => context.read<BusState>().setWaitlistFilter(WaitlistFilter.regularOnly),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Expanded(
            child: fullWaitlist.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.event_available_rounded, size: 48, color: Colors.grey.shade300),
                        const SizedBox(height: 10),
                        const Text('Nobody is waiting.', style: TextStyle(color: AppColors.textMuted)),
                      ],
                    ),
                  )
                : waitlist.isEmpty
                    ? const Center(child: Text('Nobody matches this filter.', style: TextStyle(color: AppColors.textMuted)))
                    : ListView.separated(
                        itemCount: waitlist.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (ctx, i) {
                          final p = waitlist[i];
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text('${i + 1}',
                                      style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.primary, fontSize: 13)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                                      if (p.priority && p.reason.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text('Reason: ${p.reason}',
                                              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                                        ),
                                    ],
                                  ),
                                ),
                                if (p.priority)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Text(
                                      'Priority',
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.accent),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          if (isFull) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Add to waitlist', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: waitlistNameController,
                    decoration: const InputDecoration(hintText: 'Passenger name'),
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    title: const Text('Priority (elderly, pregnant, disabled)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    value: waitlistPriority,
                    activeColor: AppColors.primary,
                    onChanged: onPriorityChanged,
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (waitlistPriority) ...[
                    const SizedBox(height: 4),
                    TextField(
                      controller: reasonController,
                      decoration: const InputDecoration(
                        hintText: 'e.g. elderly, pregnant, disabled',
                      ),
                    ),
                  ],
                  if (waitlistError.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.taken),
                        const SizedBox(width: 6),
                        Expanded(child: Text(waitlistError, style: const TextStyle(color: AppColors.taken, fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: onJoin,
                    child: const Text('Join waitlist'),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'The bus is not full yet, so nobody can join the waitlist.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: onBack,
            child: const Text('Back to seat map'),
          ),
        ],
      ),
    );
  }
}
