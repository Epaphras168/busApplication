import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

// ---------- Destinations ----------
class Destination {
  final String name;
  final double lat;
  final double lon;
  const Destination(this.name, this.lat, this.lon);
}

const destinations = [
  Destination('Huye', -2.5967, 29.7394),
  Destination('Kigali', -1.9441, 30.0619),
  Destination('Musanze', -1.4993, 29.6336),
  Destination('Rubavu', -1.6939, 29.2561),
];

// ---------- Weather ----------
class Weather {
  final double temperature;
  final int humidity;
  final double windSpeed;

  Weather({
    required this.temperature,
    required this.humidity,
    required this.windSpeed,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    return Weather(
      temperature: (json['temperature_2m'] as num).toDouble(),
      humidity: (json['relative_humidity_2m'] as num).toInt(),
      windSpeed: (json['wind_speed_10m'] as num).toDouble(),
    );
  }
}

Future<Weather> fetchWeather(Destination destination) async {
  final url = Uri.parse(
    'https://api.open-meteo.com/v1/forecast?latitude=${destination.lat}&longitude=${destination.lon}&current=temperature_2m,relative_humidity_2m,wind_speed_10m',
  );
  final response = await http.get(url);
  if (response.statusCode != 200) {
    throw Exception('The weather server answered ${response.statusCode}');
  }
  final data = jsonDecode(response.body) as Map<String, dynamic>;
  return Weather.fromJson(data['current'] as Map<String, dynamic>);
}

// ---------- Theme ----------
class AppColors {
  static const bg = Color(0xFFF5F6FB);
  static const primary = Color(0xFF5B5FEF);
  static const primaryDark = Color(0xFF3D3FC4);
  static const accent = Color(0xFFFF8A5B);
  static const free = Color(0xFF22C55E);
  static const taken = Color(0xFFEF4444);
  static const card = Colors.white;
  static const textDark = Color(0xFF1E2140);
  static const textMuted = Color(0xFF8A8DA6);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    final base = ThemeData(useMaterial3: true, colorSchemeSeed: AppColors.primary);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Bus Booking',
      theme: base.copyWith(
        scaffoldBackgroundColor: AppColors.bg,
        textTheme: base.textTheme.apply(
          bodyColor: AppColors.textDark,
          displayColor: AppColors.textDark,
          fontFamily: 'Roboto',
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: AppColors.textDark,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            elevation: 0,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textDark,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: BorderSide(color: Colors.grey.shade300),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      home: const BusBookingScreen(),
    );
  }
}

enum Screen { map, book, details, waitlist }

class WaitlistPerson {
  final String name;
  final bool priority;
  final String reason;

  WaitlistPerson(this.name, this.priority, [this.reason = '']);

  Map<String, dynamic> toJson() => {
        'name': name,
        'priority': priority,
        'reason': reason,
      };

  factory WaitlistPerson.fromJson(Map<String, dynamic> json) => WaitlistPerson(
        json['name'] as String,
        json['priority'] as bool,
        json['reason'] as String,
      );
}

class BusBookingScreen extends StatefulWidget {
  const BusBookingScreen({super.key});
  @override
  State<BusBookingScreen> createState() => _BusBookingScreenState();
}

class _BusBookingScreenState extends State<BusBookingScreen> {
  static const int price = 3000;
  static const int seatCount = 12;

  List<String?> seats = List.filled(seatCount, null);
  List<WaitlistPerson> waitlist = [];
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
    seats[0] = 'Alice';
    seats[1] = 'Bob';
    seats[5] = 'Clara';
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeats = prefs.getString('seats');
    final savedWaitlist = prefs.getString('waitlist');
    final savedDestination = prefs.getString('destination');
    setState(() {
      if (savedSeats != null) {
        seats = (jsonDecode(savedSeats) as List).cast<String?>();
      }
      if (savedWaitlist != null) {
        waitlist = (jsonDecode(savedWaitlist) as List)
            .map((e) => WaitlistPerson.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (savedDestination != null) {
        destination = destinations.firstWhere(
          (d) => d.name == savedDestination,
          orElse: () => destinations.first,
        );
      }
    });
    _loadWeather();
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('seats', jsonEncode(seats));
    await prefs.setString(
      'waitlist',
      jsonEncode(waitlist.map((p) => p.toJson()).toList()),
    );
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

  int get seatsSold => seats.where((s) => s != null).length;
  int get moneyMade => seatsSold * price;
  bool get isFull => seatsSold == seatCount;

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
    setState(() {
      mapMessage = '';
      selectedSeat = index;
      if (seats[index] != null) {
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
    final name = nameController.text.trim();
    final cashText = cashController.text.trim();
    final cash = int.tryParse(cashText);

    if (name.isEmpty) {
      setState(() => bookError = 'Please type the passenger name.');
      return;
    }
    if (seats.any((s) => s != null && s.toLowerCase() == name.toLowerCase())) {
      setState(() => bookError = '$name already has a seat on this bus.');
      return;
    }
    if (cash == null) {
      setState(() => bookError = 'Please type the cash handed over.');
      return;
    }
    if (cash < price) {
      setState(() => bookError = 'Cash must be at least 3,000 RWF.');
      return;
    }
    if (cash % 100 != 0) {
      setState(() => bookError = 'Cash must be a multiple of 100 RWF.');
      return;
    }

    final change = cash - price;
    seats[selectedSeat!] = name;
    _saveData();

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
                _performCancel();
              },
              child: const Text('Cancel it'),
            ),
          ),
        ],
      ),
    );
  }

  void _performCancel() {
    final index = selectedSeat!;
    seats[index] = null;
    String msg = '';
    if (waitlist.isNotEmpty) {
      final person = waitlist.removeAt(0);
      seats[index] = person.name;
      msg = '${person.name} moved into seat ${index + 1}.';
    }
    setState(() {
      mapMessage = msg;
      currentScreen = Screen.map;
      selectedSeat = null;
    });
    _saveData();
  }

  void joinWaitlist() {
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

    final person = WaitlistPerson(name, waitlistPriority, waitlistPriority ? reason : '');

    if (person.priority) {
      int i = 0;
      while (i < waitlist.length && waitlist[i].priority) {
        i++;
      }
      waitlist.insert(i, person);
    } else {
      waitlist.add(person);
    }

    setState(() {
      waitlistNameController.clear();
      reasonController.clear();
      waitlistPriority = false;
      waitlistError = '';
    });
    _saveData();
  }

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (currentScreen) {
      case Screen.map:
        return _buildMap();
      case Screen.book:
        return _buildBook();
      case Screen.details:
        return _buildDetails();
      case Screen.waitlist:
        return _buildWaitlist();
    }
  }

  // ---------- MAP ----------
  Widget _buildMap() {
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
                onSelected: (_) => chooseDestination(d),
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
                  value: '$seatsSold / $seatCount',
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  icon: Icons.payments_rounded,
                  label: 'Revenue',
                  value: '${_money(moneyMade)} RWF',
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
                children: List.generate(seatCount, (i) {
                  final taken = seats[i] != null;
                  final color = taken ? AppColors.taken : AppColors.free;
                  return InkWell(
                    onTap: () => openSeat(i),
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
                            taken ? seats[i]! : 'Free',
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
            onPressed: () {
              setState(() {
                currentScreen = Screen.waitlist;
                waitlistError = '';
              });
            },
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text('Waitlist  ·  ${waitlist.length} waiting'),
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
          TextButton(onPressed: retryWeather, child: const Text('Retry')),
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

  // ---------- BOOK ----------
  Widget _buildBook() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: goToMap,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
              ),
              const SizedBox(width: 10),
              Text('Book seat ${selectedSeat! + 1}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
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
            onPressed: submitBooking,
            child: const Text('Confirm booking'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: goToMap,
            child: const Text('Back to seat map'),
          ),
        ],
      ),
    );
  }

  // ---------- DETAILS ----------
  Widget _buildDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: goToMap,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
              ),
              const SizedBox(width: 10),
              const Text('Booking details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('CONFIRMED', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                    ),
                    const Icon(Icons.event_seat_rounded, color: Colors.white, size: 26),
                  ],
                ),
                const SizedBox(height: 18),
                Text('Seat ${selectedSeat! + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(seats[selectedSeat!] ?? '',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 18),
                Container(height: 1, color: Colors.white.withOpacity(0.2)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Amount paid', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13)),
                    const Text('3,000 RWF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.taken),
            onPressed: cancelBooking,
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancel booking'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: goToMap,
            child: const Text('Back to seat map'),
          ),
        ],
      ),
    );
  }

  // ---------- WAITLIST ----------
  Widget _buildWaitlist() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: goToMap,
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: Colors.white, shape: const CircleBorder()),
              ),
              const SizedBox(width: 10),
              const Text('Waitlist', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: waitlist.isEmpty
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
                    onChanged: (v) => setState(() => waitlistPriority = v),
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
                    onPressed: joinWaitlist,
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
            onPressed: goToMap,
            child: const Text('Back to seat map'),
          ),
        ],
      ),
    );
  }
}