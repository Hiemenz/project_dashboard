import 'dart:convert';
import 'package:http/http.dart' as http;

import 'models.dart';

class PiApiException implements Exception {
  final String message;
  PiApiException(this.message);
  @override
  String toString() => message;
}

class PiApiClient {
  final PiHost host;
  PiApiClient(this.host);

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = host.baseUrl.endsWith('/')
        ? host.baseUrl.substring(0, host.baseUrl.length - 1)
        : host.baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${host.token}',
      };

  Future<PiStats> fetchStats({Duration timeout = const Duration(seconds: 5)}) async {
    final res = await http.get(_uri('/stats'), headers: _headers).timeout(timeout);
    _checkStatus(res);
    return PiStats.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  Future<List<PiProcess>> fetchProcesses({
    int limit = 50,
    String sortBy = 'cpu',
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final res = await http
        .get(
          _uri('/processes', {'limit': '$limit', 'sort_by': sortBy}),
          headers: _headers,
        )
        .timeout(timeout);
    _checkStatus(res);
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final list = body['processes'] as List<dynamic>;
    return list
        .map((e) => PiProcess.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  void _checkStatus(http.Response res) {
    if (res.statusCode == 401) {
      throw PiApiException('Unauthorized — check the token for ${host.name}');
    }
    if (res.statusCode != 200) {
      throw PiApiException('${host.name} returned HTTP ${res.statusCode}');
    }
  }
}
