import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/booking.dart';
import '../models/waitlist_person.dart';
import '../repositories/bus_repository.dart';

class BusState extends ChangeNotifier {
  BusState(this._repo) {
    _bookingsSub = _repo.watchBookings().listen(
          (map) {
        _bookingsBySeat = map;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (Object e) {
        _loading = false;
        _error = 'Could not load your bookings.';
        notifyListeners();
      },
    );
    _waitlistSub = _repo.watchWaitlist().listen((list) {
      final priority = list.where((p) => p.priority).toList();
      final regular = list.where((p) => !p.priority).toList();
      _waitlist = [...priority, ...regular];
      notifyListeners();
    });
  }

  final BusRepository _repo;
  StreamSubscription<Map<int, String>>? _bookingsSub;
  StreamSubscription<List<WaitlistPerson>>? _waitlistSub;

  static const int seatCount = 12;
  static const int price = 3000;

  Map<int, String> _bookingsBySeat = {};
  List<WaitlistPerson> _waitlist = [];
  bool _loading = true;
  String? _error;

  // Read-only views.
  bool get loading => _loading;
  String? get error => _error;
  List<WaitlistPerson> get waitlist => _waitlist;
  String? nameAt(int seat) => _bookingsBySeat[seat];
  List<String> get bookedNames => _bookingsBySeat.values.toList();

  // Computed — never stored (Habit 2).
  int get seatsSold => _bookingsBySeat.length;
  int get seatsLeft => seatCount - seatsSold;
  int get moneyMade => seatsSold * price;
  bool get isFull => seatsSold == seatCount;

  // The filter: who sees it? Several screens could, so it lives here, not
  // in one screen's setState.
  bool _priorityOnly = false;
  bool get priorityOnly => _priorityOnly;


  WaitlistFilter _currentFilter = WaitlistFilter.all;
  WaitlistFilter get currentFilter => _currentFilter;

  // 2. Modifier to change filter via Buttons / Segmented Selectors
  void updateFilter(WaitlistFilter filter) {
    _currentFilter = filter;
    notifyListeners();
  }



  void setPriorityOnly(bool value) {
    _priorityOnly = value;
    notifyListeners();
  }

  // Computed from _waitlist and _priorityOnly — never stored separately.
  // 3. Computed Filtered List based on the active selection
  List<WaitlistPerson> get visibleWaitlist {
    switch (_currentFilter) {
      case WaitlistFilter.priorityOnly:
        return _waitlist.where((p) => p.priority).toList();
      case WaitlistFilter.regularOnly:
        return _waitlist.where((p) => !p.priority).toList();
      case WaitlistFilter.all:
      default:
        return _waitlist;
    }
  }

  // Actions: the brain hands the job to the repository.
  Future<void> bookSeat(int seat, String name, int cash) =>
      _repo.bookSeat(seat, Booking(seat: seat, name: name, cash: cash));

  Future<void> cancelSeat(int seat) async {
    await _repo.cancelSeat(seat);
    if (_waitlist.isNotEmpty) {
      final person = _waitlist.first;
      await _repo.bookSeat(seat, Booking(seat: seat, name: person.name, cash: price));
      await _repo.leaveWaitlist(person.id);
    }
  }

  Future<void> joinWaitlist(String name, bool priority, String reason) =>
      _repo.joinWaitlist(name, priority, reason);

  @override
  void dispose() {
    _bookingsSub?.cancel();
    _waitlistSub?.cancel();
    super.dispose();
  }
}