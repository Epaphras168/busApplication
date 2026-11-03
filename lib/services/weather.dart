import 'dart:convert';
import 'package:http/http.dart' as http;

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
