import 'package:flutter/material.dart';

import '../main.dart';
import '../services/weather.dart';
import '../state/bus_state.dart';

class SeatMapView extends StatelessWidget {
  const SeatMapView({
    super.key,
    required this.state,
    required this.destination,
    required this.onChooseDestination,
    required this.weather,
    required this.weatherLoading,
    required this.weatherError,
    required this.onRetryWeather,
    required this.mapMessage,
    required this.onOpenSeat,
    required this.onGoToWaitlist,
  });

  final BusState state;
  final Destination destination;
  final ValueChanged<Destination> onChooseDestination;
  final Weather? weather;
  final bool weatherLoading;
  final String? weatherError;
  final VoidCallback onRetryWeather;
  final String mapMessage;
  final ValueChanged<int> onOpenSeat;
  final VoidCallback onGoToWaitlist;

  String _money(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pick a seat',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.place_outlined, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(destination.name, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text('3,000 RWF per seat · 12 seats', style: TextStyle(color: AppColors.textMuted)),
          const SizedBox(height: 12),

          Wrap(
            spacing: 8,
            children: destinations.map((d) {
              final selected = d.name == destination.name;
              return ChoiceChip(
                label: Text(d.name),
                selected: selected,
                onSelected: (_) => onChooseDestination(d),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          _buildWeatherCard(),
          const SizedBox(height: 16),

          // Stat strip
          Row(
            children: [
              Expanded(
                child: _statCard(
                  icon: Icons.event_seat_rounded,
                  label: 'Seats sold',
                  value: '${state.seatsSold} / ${BusState.seatCount}',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.payments_rounded,
                  label: 'Revenue',
                  value: '${_money(state.moneyMade)} RWF',
                  color: AppColors.accent,
                ),
              ),
            ],
          ),

          if (mapMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE0B2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: Color(0xFFB45309), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(mapMessage, style: const TextStyle(color: Color(0xFF92400E), fontWeight: FontWeight.w600))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          // Legend
          Row(
            children: [
              _legendDot(AppColors.free, 'Free'),
              const SizedBox(width: 16),
              _legendDot(AppColors.taken, 'Taken'),
              const Spacer(),
              const Icon(Icons.airline_seat_recline_normal, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 4),
              const Text('Front of bus', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            ],
          ),
          const SizedBox(height: 10),

          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 16, offset: const Offset(0, 6)),
                ],
              ),
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.05,
                children: List.generate(BusState.seatCount, (i) {
                  final name = state.nameAt(i);
                  final taken = name != null;
                  final color = taken ? AppColors.taken : AppColors.free;
                  return InkWell(
                    onTap: () => onOpenSeat(i),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: color.withOpacity(0.35)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_seat_rounded, color: color, size: 22),
                          const SizedBox(height: 2),
                          Text('${i + 1}',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
                          Text(
                            taken ? name : 'Free',
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onGoToWaitlist,
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text('Waitlist  ·  ${state.waitlist.length} waiting'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    Widget content;
    if (weatherLoading) {
      content = const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(width: 12),
          Text('Loading weather…', style: TextStyle(color: AppColors.textMuted)),
        ],
      );
    } else if (weatherError != null) {
      content = Row(
        children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.taken, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(weatherError!, style: const TextStyle(color: AppColors.taken, fontWeight: FontWeight.w600)),
          ),
          TextButton(onPressed: onRetryWeather, child: const Text('Retry')),
        ],
      );
    } else {
      final w = weather!;
      content = Row(
        children: [
          const Icon(Icons.wb_sunny_rounded, color: AppColors.accent, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${w.temperature.round()}°C in ${destination.name}',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Humidity ${w.humidity}% · Wind ${w.windSpeed.round()} km/h',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ],
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: content,
    );
  }

  Widget _statCard({required IconData icon, required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
