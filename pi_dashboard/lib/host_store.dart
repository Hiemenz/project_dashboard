import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';

class HostStore {
  static const _key = 'pi_hosts';

  Future<List<PiHost>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List<dynamic>;
    return list
        .map((e) => PiHost.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> save(List<PiHost> hosts) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode(hosts.map((h) => h.toJson()).toList());
    await prefs.setString(_key, raw);
  }
}
