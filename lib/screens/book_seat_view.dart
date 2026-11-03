import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../state/bus_state.dart';

class BookSeatView extends StatelessWidget {
  const BookSeatView({
    super.key,
    required this.selectedSeat,
    required this.nameController,
    required this.cashController,
    required this.bookError,
    required this.onSubmit,
    required this.onBack,
  });

  final int selectedSeat;
  final TextEditingController nameController;
  final TextEditingController cashController;
  final String bookError;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    // Live from the brain: updates here even if another device books a
    // different seat while this form is open — nobody passed it in.
    final seatsLeft = context.watch<BusState>().seatsLeft;
    return SingleChildScrollView(
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
              Text('Book seat ${selectedSeat + 1}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 6),
          Text('$seatsLeft seat${seatsLeft == 1 ? '' : 's'} left on this bus',
              style: const TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Passenger name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(hintText: 'e.g. Jean Claude'),
                ),
                const SizedBox(height: 16),
                const Text('Cash handed over (RWF)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                const SizedBox(height: 8),
                TextField(
                  controller: cashController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(hintText: 'e.g. 5000'),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary.withOpacity(0.8)),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Price is 3,000 RWF. Cash must be at least that, and a multiple of 100.',
                          style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
                if (bookError.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.taken),
                      const SizedBox(width: 6),
                      Expanded(child: Text(bookError, style: const TextStyle(color: AppColors.taken, fontWeight: FontWeight.w600, fontSize: 13))),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: onSubmit,
            child: const Text('Confirm booking'),
          ),
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
