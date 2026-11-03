import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';
import '../services/weather.dart';
import '../state/bus_state.dart';
import 'book_seat_view.dart';
import 'seat_details_view.dart';
import 'seat_map_view.dart';
import 'waitlist_view.dart';

enum Screen { map, book, details, waitlist }

class BusBookingScreen extends StatefulWidget {
  const BusBookingScreen({super.key});
  @override
  State<BusBookingScreen> createState() => _BusBookingScreenState();
}

class _BusBookingScreenState extends State<BusBookingScreen> {
  // Ephemeral: only this screen cares about any of this.
  Screen currentScreen = Screen.map;
  int? selectedSeat;
  String mapMessage = '';

  final TextEditingController nameController = TextEditingController();
  final TextEditingController cashController = TextEditingController();
  final TextEditingController waitlistNameController = TextEditingController();
  final TextEditingController reasonController = TextEditingController();
  bool waitlistPriority = false;
  String bookError = '';
  String waitlistError = '';

  Destination destination = destinations.first;
  Weather? weather;
  bool weatherLoading = true;
  String? weatherError;

  @override
  void initState() {
    super.initState();
    _loadDestination();
    _loadWeather();
  }

  Future<void> _loadDestination() async {
    final prefs = await SharedPreferences.getInstance();
    final savedDestination = prefs.getString('destination');
    if (savedDestination != null) {
      setState(() {
        destination = destinations.firstWhere(
          (d) => d.name == savedDestination,
          orElse: () => destinations.first,
        );
      });
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await FirebaseAuth.instance.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully logged out.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sign out failed: Firebase is not configured or initialized for Web.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void chooseDestination(Destination d) async {
    setState(() {
      destination = d;
      weatherLoading = true;
      weatherError = null;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('destination', d.name);
    _loadWeather();
  }

  Future<void> _loadWeather() async {
    try {
      final result = await fetchWeather(destination);
      setState(() {
        weather = result;
        weatherLoading = false;
        weatherError = null;
      });
    } catch (e) {
      setState(() {
        weatherLoading = false;
        weatherError = 'Could not load the weather.';
      });
    }
  }

  void retryWeather() {
    setState(() {
      weatherLoading = true;
      weatherError = null;
    });
    _loadWeather();
  }

  @override
  void dispose() {
    nameController.dispose();
    cashController.dispose();
    waitlistNameController.dispose();
    reasonController.dispose();
    super.dispose();
  }

  String _money(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');

  List<String> changeInNotes(int amount) {
    const notes = [5000, 2000, 1000, 500, 100];
    List<String> parts = [];
    int left = amount;
    for (int note in notes) {
      int count = left ~/ note;
      if (count > 0) {
        parts.add('${_money(note)} × $count');
        left -= count * note;
      }
    }
    return parts;
  }

  void goToMap() {
    setState(() {
      currentScreen = Screen.map;
      selectedSeat = null;
      bookError = '';
      waitlistError = '';
      nameController.clear();
      cashController.clear();
      waitlistNameController.clear();
      waitlistPriority = false;
      reasonController.clear();
    });
  }

  void openSeat(int index) {
    final state = context.read<BusState>();
    setState(() {
      mapMessage = '';
      selectedSeat = index;
      if (state.nameAt(index) != null) {
        currentScreen = Screen.details;
      } else {
        currentScreen = Screen.book;
        nameController.clear();
        cashController.clear();
        bookError = '';
      }
    });
  }

  void submitBooking() {
    final state = context.read<BusState>(); // read before any await
    final name = nameController.text.trim();
    final cashText = cashController.text.trim();
    final cash = int.tryParse(cashText);

    if (name.isEmpty) {
      setState(() => bookError = 'Please type the passenger name.');
      return;
    }
    if (state.bookedNames.any((s) => s.toLowerCase() == name.toLowerCase())) {
      setState(() => bookError = '$name already has a seat on this bus.');
      return;
    }
    if (cash == null) {
      setState(() => bookError = 'Please type the cash handed over.');
      return;
    }
    if (cash < BusState.price) {
      setState(() => bookError = 'Cash must be at least 3,000 RWF.');
      return;
    }
    if (cash % 100 != 0) {
      setState(() => bookError = 'Cash must be a multiple of 100 RWF.');
      return;
    }

    final change = cash - BusState.price;
    state.bookSeat(selectedSeat!, name, cash);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFFE8FAF0), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, color: AppColors.free, size: 32),
        ),
        title: const Text('Booking confirmed', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _receiptRow('Seat', '${selectedSeat! + 1}'),
            _receiptRow('Passenger', name),
            _receiptRow('Cash received', '${_money(cash)} RWF'),
            const Divider(height: 24),
            if (change == 0)
              _receiptRow('Change', 'None', bold: true)
            else ...[
              _receiptRow('Change due', '${_money(change)} RWF', bold: true),
              const SizedBox(height: 6),
              ...changeInNotes(change).map(
                (n) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(n, style: const TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                goToMap();
              },
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textMuted)),
          Text(
            value,
            style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
          ),
        ],
      ),
    );
  }

  void cancelBooking() {
    final state = context.read<BusState>(); // read before any await
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(color: Color(0xFFFDEAEA), shape: BoxShape.circle),
          child: const Icon(Icons.warning_rounded, color: AppColors.taken, size: 32),
        ),
        title: const Text('Cancel booking?', textAlign: TextAlign.center),
        content: const Text(
          'This will free up the seat. If someone is waiting, they\'ll take it instead.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textMuted),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep it'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.taken),
              onPressed: () {
                Navigator.pop(ctx);
                _performCancel(state);
              },
              child: const Text('Cancel it'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performCancel(BusState state) async {
    final index = selectedSeat!;
    final hadWaitlist = state.waitlist.isNotEmpty;
    final nextName = hadWaitlist ? state.waitlist.first.name : null;
    await state.cancelSeat(index);
    if (!mounted) return;
    setState(() {
      mapMessage = hadWaitlist ? '$nextName moved into seat ${index + 1}.' : '';
      currentScreen = Screen.map;
      selectedSeat = null;
    });
  }

  void joinWaitlist() {
    final state = context.read<BusState>();
    final name = waitlistNameController.text.trim();
    final reason = reasonController.text.trim();

    if (name.isEmpty) {
      setState(() => waitlistError = 'Please type the passenger name.');
      return;
    }
    if (waitlistPriority && reason.isEmpty) {
      setState(() => waitlistError = 'Please give a reason for priority.');
      return;
    }

    state.joinWaitlist(name, waitlistPriority, reason);

    setState(() {
      waitlistNameController.clear();
      reasonController.clear();
      waitlistPriority = false;
      waitlistError = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<BusState>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_bus_filled, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Text('${destination.name} Express', style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
            onPressed: _handleSignOut,
          ),
        ],
      ),
      body: SafeArea(child: _buildRoot(state)),
    );
  }

  Widget _buildRoot(BusState state) {
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(state.error!, textAlign: TextAlign.center),
        ),
      );
    }
    return _buildBody(state);
  }

  Widget _buildBody(BusState state) {
    switch (currentScreen) {
      case Screen.map:
        return SeatMapView(
          state: state,
          destination: destination,
          onChooseDestination: chooseDestination,
          weather: weather,
          weatherLoading: weatherLoading,
          weatherError: weatherError,
          onRetryWeather: retryWeather,
          mapMessage: mapMessage,
          onOpenSeat: openSeat,
          onGoToWaitlist: () => setState(() {
            currentScreen = Screen.waitlist;
            waitlistError = '';
          }),
        );
      case Screen.book:
        return BookSeatView(
          selectedSeat: selectedSeat!,
          nameController: nameController,
          cashController: cashController,
          bookError: bookError,
          onSubmit: submitBooking,
          onBack: goToMap,
        );
      case Screen.details:
        return SeatDetailsView(
          selectedSeat: selectedSeat!,
          passengerName: state.nameAt(selectedSeat!) ?? '',
          onCancel: cancelBooking,
          onBack: goToMap,
        );
      case Screen.waitlist:
        return WaitlistView(
          isFull: state.isFull,
          waitlistNameController: waitlistNameController,
          reasonController: reasonController,
          waitlistPriority: waitlistPriority,
          onPriorityChanged: (v) => setState(() => waitlistPriority = v),
          waitlistError: waitlistError,
          onJoin: joinWaitlist,
          onBack: goToMap,
        );
    }
  }
}
