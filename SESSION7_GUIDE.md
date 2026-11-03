# Session 7 guide — applied to Bus Booking

This is your Session 7 translation table and step-by-step plan, written against your
actual files (not MoMo Wallet). Follow it top to bottom; run the app after every step.

## 0. Before you start

```
git add -A
git commit -m "before state management"
git push
```

## 1. Your translation table

| MoMo Wallet | What it is | Bus Booking (yours) |
|---|---|---|
| `Txn`, `txn.dart` | Your model | `Booking` in `models/booking.dart`, plus `WaitlistPerson` in `models/waitlist_person.dart` |
| `transactions` collection | Firestore collection | `bookings` **and** `waitlist` (two collections, same user) |
| `TxnRepository` | Your repository | `BusRepository` in `repositories/bus_repository.dart` |
| `WalletState` | Your state class | `BusState` in `state/bus_state.dart` |
| `balance` | Computed value | `seatsSold`, `moneyMade`, `isFull` (all computed getters) |
| `WalletScreen`, `TxnForm` | List screen + form | `BusBookingScreen` today — you'll split it (step 6) |

**One structural difference from MoMo Wallet, worth knowing up front:** MoMo Wallet pushes
`TxnForm` with `Navigator.push`, which is why it needs the `ChangeNotifierProvider.value`
trick (step 8/14 in the guide). Your app doesn't push routes at all — `BusBookingScreen`
just swaps an internal `Screen` enum (`map`, `book`, `details`, `waitlist`) to decide what
to draw. That actually makes your life easier: as long as every screen widget sits *below*
one `ChangeNotifierProvider<BusState>` in the tree, every one of them can
`context.watch<BusState>()` directly — no `.value` wrapping needed anywhere, because
nothing is ever pushed onto a new route. Keep that in mind in step 6.

## 2. Make the folders

```
flutter pub add provider
```

Create `lib/models/`, `lib/repositories/`, `lib/state/`, `lib/screens/`.

Move these two files into `screens/` (use your editor's "move/refactor", not drag-in-Finder,
so imports update automatically):

- `lib/auth_gate.dart` → `lib/screens/auth_gate.dart`
- `lib/login_screen.dart` → `lib/screens/login_screen.dart`

Run the app. Nothing should look different yet — you've only moved two files, and
`main.dart` now imports `screens/auth_gate.dart`.

## 3. The models

Right now your "model" logic is scattered: `WaitlistPerson` lives inline in `main.dart`
(around line 145), and there's no `Booking` class at all — seats are just a
`List<String?>` built by hand inside `_listenToData` (main.dart:218–247). Give both a
real home.

Create `lib/models/booking.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Booking {
  Booking({
    required this.seat,
    required this.name,
    required this.cash,
  });

  final int seat;
  final String name;
  final int cash;

  Map<String, dynamic> toMap() => {
        'seat': seat,
        'name': name,
        'cash': cash,
      };

  factory Booking.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return Booking(
      seat: data['seat'] as int,
      name: data['name'] as String,
      cash: (data['cash'] as num).toInt(),
    );
  }
}
```

Create `lib/models/waitlist_person.dart` — this is just your current `WaitlistPerson`
class (main.dart:145–161) moved out, with its `fromDoc` kept as-is:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

class WaitlistPerson {
  WaitlistPerson(this.id, this.name, this.priority, [this.reason = '']);

  final String id;
  final String name;
  final bool priority;
  final String reason;

  factory WaitlistPerson.fromDoc(
          QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      WaitlistPerson(
        doc.id,
        doc.data()['name'] as String,
        doc.data()['priority'] as bool,
        (doc.data()['reason'] as String?) ?? '',
      );
}
```

Delete the `WaitlistPerson` class out of `main.dart` once nothing there needs it anymore
(you'll import it from the state class instead).

## 4. The repository

All your Firestore code today lives in `lib/booking_data.dart` (`myBookings`,
`myWaitlist`, `addSampleBookings`) plus three more places inside `main.dart`:
`submitBooking` (≈368), `_performCancel` (≈506), and `joinWaitlist` (≈528) all call
`myBookings()`/`myWaitlist()` directly. The repository gathers **all** of that into one
class, keyed to one user — same idea as `TxnRepository(uid)`.

Create `lib/repositories/bus_repository.dart`:

```dart
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/booking.dart';
import '../models/waitlist_person.dart';

class BusRepository {
  BusRepository(this.uid);

  final String uid;

  CollectionReference<Map<String, dynamic>> get _bookings => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('bookings');

  CollectionReference<Map<String, dynamic>> get _waitlist => FirebaseFirestore
      .instance
      .collection('users')
      .doc(uid)
      .collection('waitlist');

  // The pipe for bookings: a map from doc id -> name, keyed by seat index.
  Stream<Map<int, String>> watchBookings() => _bookings.snapshots().map(
        (snapshot) => {
          for (final doc in snapshot.docs)
            if (int.tryParse(doc.id) != null) int.parse(doc.id): doc.data()['name'] as String,
        },
      );

  Stream<List<WaitlistPerson>> watchWaitlist() =>
      _waitlist.orderBy('joinedAt').snapshots().map(
            (snapshot) => snapshot.docs.map(WaitlistPerson.fromDoc).toList(),
          );

  Future<void> bookSeat(int seat, Booking booking) =>
      _bookings.doc('$seat').set({
        ...booking.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> cancelSeat(int seat) => _bookings.doc('$seat').delete();

  Future<void> joinWaitlist(String name, bool priority, String reason) =>
      _waitlist.add({
        'name': name,
        'priority': priority,
        'reason': priority ? reason : '',
        'joinedAt': FieldValue.serverTimestamp(),
      });

  Future<void> leaveWaitlist(String id) => _waitlist.doc(id).delete();

  Future<void> addSamples() async {
    const price = 3000;
    const samples = {0: 'Alice', 1: 'Bob', 5: 'Clara'};
    final batch = FirebaseFirestore.instance.batch();
    for (final entry in samples.entries) {
      batch.set(_bookings.doc('${entry.key}'), {
        'seat': entry.key,
        'name': entry.value,
        'cash': price,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
```

Keep `lib/booking_data.dart` for now — you delete it in step 7, once nothing calls it.

## 5. The state class: the brain

Create `lib/state/bus_state.dart`. This replaces `_listenToData`, `submitBooking`,
`_performCancel`, and `joinWaitlist` from `main.dart` — all of it becomes brain code, not
widget code:

```dart
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

  // Computed — never stored (Habit 2).
  int get seatsSold => _bookingsBySeat.length;
  int get moneyMade => seatsSold * price;
  bool get isFull => seatsSold == seatCount;

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
```

Note `cancelSeat` keeps the exact "bump the first waitlisted person into the freed seat"
behaviour your current `_performCancel` (main.dart:506–524) has — it just lives in the
brain now instead of the widget.

## 6. Give the brain to your screens

In `lib/screens/auth_gate.dart`, wrap the signed-in branch:

```dart
import 'package:provider/provider.dart';

import '../repositories/bus_repository.dart';
import '../state/bus_state.dart';
import 'bus_booking_screen.dart'; // see step 7

// ...
if (user == null) {
  return const LoginScreen();
}
return ChangeNotifierProvider<BusState>(
  create: (_) => BusState(BusRepository(user.uid)),
  child: const BusBookingScreen(),
);
```

Because nothing below this point ever uses `Navigator.push`, every screen widget under
`BusBookingScreen` can `context.watch<BusState>()` with no extra wrapping — see the note
in step 1.

## 7. Split `main.dart` into screens — recommended

**Yes, split it.** At 1,238 lines, `main.dart` currently holds the theme, the weather
fetcher, the destinations list, and all four "screens" (map, book, details, waitlist) as
methods on one giant `State` class. That's exactly the "UI and logic tangled" problem
from step 1 of tonight's guide, just at the *file* level instead of the data level.
Suggested split:

```
lib/
├── main.dart                      MyApp, theme, Firebase init only
├── models/
│   ├── booking.dart
│   └── waitlist_person.dart
├── repositories/
│   └── bus_repository.dart
├── state/
│   └── bus_state.dart
├── services/
│   └── weather.dart                Destination, Weather, fetchWeather — no screen needs to own this
└── screens/
    ├── auth_gate.dart
    ├── login_screen.dart
    ├── bus_booking_screen.dart     holds the Screen enum + selectedSeat (ephemeral — stays local, step 2 of tonight's guide)
    ├── seat_map_view.dart          the _buildMap body, as its own widget
    ├── book_seat_view.dart         the _buildBook body
    ├── seat_details_view.dart      the _buildDetails body
    └── waitlist_view.dart          the _buildWaitlist body
```

`bus_booking_screen.dart` keeps the `Screen` enum, `selectedSeat`, and the four text
controllers (all ephemeral — one widget's own business, step 2). It watches `BusState`
once and passes the bits each child view needs down as constructor parameters; the
children themselves also `context.watch<BusState>()` directly, since they're all in the
same tree under the provider — pick whichever is less typing per screen, both are correct.

Weather and `Destination` aren't app state in the Session 7 sense (only the map view uses
them), so they don't belong in `BusState`. Leave them as local `State` fields on whichever
widget shows the weather card, loaded with `services/weather.dart`'s `fetchWeather`.

If splitting into 4 view files feels like too much right now, the **minimum** that still
satisfies "Done when": move the Firestore-touching code out of `main.dart` into
`repositories/` and `state/`, and keep the four screen bodies as private methods in one
`screens/bus_booking_screen.dart` file. The folder structure and layer rule (`cloud_firestore`
only in `models/` and `repositories/`) is what's actually graded — the 4-way view split is
a readability bonus, not a requirement.

## 8. Rewire the UI to the brain

Wherever `main.dart` currently does this (search for `myBookings()` and `myWaitlist()` to
find every spot):

| Was (in `_BusBookingScreenState`) | Becomes |
|---|---|
| `_listenToData()` + `_bookingsSub`/`_waitlistSub` fields | deleted — `BusState`'s constructor does this now |
| `seats[i]` | `context.watch<BusState>().nameAt(i)` |
| `seatsSold`, `moneyMade`, `isFull` getters | `context.watch<BusState>().seatsSold` etc. |
| `myBookings().doc('$selectedSeat').set({...})` in `submitBooking` | `context.read<BusState>().bookSeat(selectedSeat!, name, cash)` |
| the delete+reassign block in `_performCancel` | `context.read<BusState>().cancelSeat(selectedSeat!)` |
| the `myWaitlist().add({...})` in `joinWaitlist` | `context.read<BusState>().joinWaitlist(name, priority, reason)` |
| `dataLoading` / `dataError` fields | `context.watch<BusState>().loading` / `.error` |

Same `read`-before-`await` rule as MoMo Wallet: in `submitBooking`/`cancelBooking`/
`joinWaitlist`, grab `context.read<BusState>()` into a variable **before** any `await` or
`showDialog`.

In `lib/screens/login_screen.dart`, the sample-data line becomes:

```dart
await BusRepository(auth.currentUser!.uid).addSamples(); // was: addSampleBookings()
```

This is the one place a screen talks to a repository directly — same reason as MoMo
Wallet: the brain doesn't exist yet at that point, it's born a moment later when the gate
sees the new user.

## 9. Clean up and prove nothing broke

1. Search the project for `myBookings`, `myWaitlist`, `addSampleBookings`. Once nothing
   calls them, delete `lib/booking_data.dart` entirely.
2. Search for `cloud_firestore` — it should now appear in exactly **3** files:
   `models/booking.dart`, `models/waitlist_person.dart`, `repositories/bus_repository.dart`.
   (Your guide's checklist says "models and repository" — you have two small models, so
   two + one repository is the correct count here, not a mistake.)
3. Run the Session 6 checklist again: log out/in, book a seat, cancel a seat (watch the
   waitlist bump), add a document by hand in the console (live update), second account
   sees nothing of the first.

```
git add -A
git commit -m "state management with provider"
git push
```

## 10. The payoff — a filter (step 18 equivalent)

Natural filter for this app: show only seats matching a destination, or filter the
waitlist to priority-only. Example — priority-only waitlist toggle, in `BusState`:

```dart
bool _priorityOnly = false;
bool get priorityOnly => _priorityOnly;

void setPriorityOnly(bool value) {
  _priorityOnly = value;
  notifyListeners();
}

List<WaitlistPerson> get visibleWaitlist =>
    _priorityOnly ? _waitlist.where((p) => p.priority).toList() : _waitlist;
```

Then a `SwitchListTile` in the waitlist view reads `context.watch<BusState>().priorityOnly`
to draw itself and calls `context.read<BusState>().setPriorityOnly(v)` in `onChanged` —
same two-getter-one-setter pattern as everything else tonight.
