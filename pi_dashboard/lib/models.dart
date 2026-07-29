class PiHost {
  final String id;
  final String name;
  final String baseUrl; // e.g. http://100.x.x.x:8765
  final String token;

  const PiHost({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.token,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'baseUrl': baseUrl,
        'token': token,
      };

  factory PiHost.fromJson(Map<String, dynamic> json) => PiHost(
        id: json['id'] as String,
        name: json['name'] as String,
        baseUrl: json['baseUrl'] as String,
        token: json['token'] as String,
      );

  PiHost copyWith({String? name, String? baseUrl, String? token}) => PiHost(
        id: id,
        name: name ?? this.name,
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
      );
}

class PiStats {
  final String hostname;
  final double uptimeSeconds;
  final double cpuPercent;
  final int cpuCount;
  final double load1m;
  final double? cpuTempC;
  final int memTotal;
  final int memUsed;
  final double memPercent;
  final int diskTotal;
  final int diskUsed;
  final double diskPercent;

  const PiStats({
    required this.hostname,
    required this.uptimeSeconds,
    required this.cpuPercent,
    required this.cpuCount,
    required this.load1m,
    required this.cpuTempC,
    required this.memTotal,
    required this.memUsed,
    required this.memPercent,
    required this.diskTotal,
    required this.diskUsed,
    required this.diskPercent,
  });

  factory PiStats.fromJson(Map<String, dynamic> json) {
    final mem = json['memory'] as Map<String, dynamic>;
    final disk = json['disk'] as Map<String, dynamic>;
    final load = json['load_avg'] as Map<String, dynamic>;
    return PiStats(
      hostname: json['hostname'] as String,
      uptimeSeconds: (json['uptime_seconds'] as num).toDouble(),
      cpuPercent: (json['cpu_percent'] as num).toDouble(),
      cpuCount: json['cpu_count'] as int,
      load1m: (load['1m'] as num).toDouble(),
      cpuTempC: (json['cpu_temp_c'] as num?)?.toDouble(),
      memTotal: mem['total'] as int,
      memUsed: mem['used'] as int,
      memPercent: (mem['percent'] as num).toDouble(),
      diskTotal: disk['total'] as int,
      diskUsed: disk['used'] as int,
      diskPercent: (disk['percent'] as num).toDouble(),
    );
  }
}

class PiProcess {
  final int pid;
  final String name;
  final String? user;
  final String status;
  final double cpuPercent;
  final double memoryPercent;

  const PiProcess({
    required this.pid,
    required this.name,
    required this.user,
    required this.status,
    required this.cpuPercent,
    required this.memoryPercent,
  });

  factory PiProcess.fromJson(Map<String, dynamic> json) => PiProcess(
        pid: json['pid'] as int,
        name: json['name'] as String? ?? '?',
        user: json['user'] as String?,
        status: json['status'] as String? ?? '',
        cpuPercent: (json['cpu_percent'] as num).toDouble(),
        memoryPercent: (json['memory_percent'] as num).toDouble(),
      );
}
