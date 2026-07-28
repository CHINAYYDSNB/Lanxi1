/// Maps 1Panel Docker container API responses and defines the domain model
/// used by the Docker UI.
library;

/// Maps 1Panel Docker container list responses (`POST /api/v2/containers/search`).
///
/// Field names are tolerant: 1Panel returns `containerID`/`name`/`image`/`state`
/// while the raw Docker CLI returns `ID`/`Names`/`Image`/`State`. Both shapes
/// are accepted so the same DTO works for the SSH and 1Panel sources.
class ContainerDto {
  final String containerId;
  final String name;
  final String image;
  final String status;
  final String state;
  final String? ip;
  final int? port;
  final List<String> ports;
  final String? createdAt;

  const ContainerDto({
    required this.containerId,
    required this.name,
    required this.image,
    required this.status,
    required this.state,
    this.ip,
    this.port,
    this.ports = const [],
    this.createdAt,
  });

  factory ContainerDto.fromJson(Map<String, dynamic> json) {
    String? s(dynamic v) => v?.toString();
    final rawPorts = json['ports'];
    final ports = rawPorts is List
        ? rawPorts.map((e) => e.toString()).toList()
        : <String>[];
    return ContainerDto(
      containerId: s(json['containerID']) ?? s(json['ID']) ?? '',
      name: s(json['name']) ?? s(json['Names']) ?? '',
      image:
          s(json['image']) ?? s(json['imageName']) ?? s(json['Image']) ?? '',
      status: s(json['status']) ?? s(json['Status']) ?? '',
      state: s(json['state']) ?? s(json['State']) ?? '',
      ip: json['ip'] as String? ?? json['IP'] as String?,
      port: (json['port'] as num?)?.toInt() ?? (json['Port'] as num?)?.toInt(),
      ports: ports,
      createdAt:
          json['createdAt'] as String? ?? json['CreatedAt'] as String?,
    );
  }

  ContainerDomain toDomain() {
    return ContainerDomain(
      id: containerId.isNotEmpty ? containerId : '(unknown)',
      name: name.isNotEmpty ? name : '(unnamed)',
      image: image,
      status: status,
      state: state,
      ipAddress: ip ?? '',
      port: port,
      ports: ports,
      createdTime: createdAt ?? '',
    );
  }
}

/// Domain model for a Docker container (used by the UI).
class ContainerDomain {
  final String id;
  final String name;
  final String image;
  final String status;
  final String state;
  final String ipAddress;
  final int? port;
  final List<String> ports;
  final String createdTime;

  ContainerDomain({
    required this.id,
    required this.name,
    required this.image,
    required this.status,
    required this.state,
    this.ipAddress = '',
    this.port,
    this.ports = const [],
    this.createdTime = '',
  });

  /// Build a domain object from a raw `docker ps --format '{{json .}}'` line.
  factory ContainerDomain.fromCliJson(Map<String, dynamic> json) {
    String s(dynamic v) => v?.toString() ?? '';
    final status = s(json['Status']);
    final state = _deriveState(status);
    final names = s(json['Names']).split(',').first.trim();
    final portsRaw = s(json['Ports']);
    final ports = portsRaw.isNotEmpty
        ? portsRaw
            .split(',')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList()
        : const <String>[];
    return ContainerDomain(
      id: s(json['ID']),
      name: names,
      image: s(json['Image']),
      status: status,
      state: state,
      createdTime: s(json['CreatedAt']),
      ports: ports,
    );
  }

  bool get isRunning => state == 'running';
  bool get isStopped => state == 'exited' || state == 'stopped';
  bool get isPaused => state == 'paused';

  static String _deriveState(String status) {
    if (status.startsWith('Up')) return 'running';
    if (status.startsWith('Exited')) return 'exited';
    if (status.startsWith('Paused')) return 'paused';
    if (status.startsWith('Created')) return 'created';
    if (status.startsWith('Restarting')) return 'restarting';
    if (status.contains('Removing')) return 'removing';
    if (status.contains('Dead')) return 'dead';
    return status;
  }

  /// Human-readable state label (Chinese).
  String get stateLabel {
    switch (state) {
      case 'running':
        return '运行中';
      case 'exited':
      case 'stopped':
        return '已停止';
      case 'paused':
        return '已暂停';
      case 'restarting':
        return '重启中';
      case 'created':
        return '已创建';
      case 'removing':
        return '删除中';
      case 'dead':
        return '已退出';
      default:
        return state.isEmpty ? '未知' : state;
    }
  }
}

/// Detailed inspection result for a single container.
///
/// Wraps the raw inspect JSON (from either `docker inspect` or the 1Panel
/// `containers/inspect` endpoint) and exposes defensive typed getters so the
/// UI never crashes on missing/renamed fields.
class ContainerInspect {
  final Map<String, dynamic> raw;

  ContainerInspect(this.raw);

  String get id => raw['Id']?.toString() ?? raw['containerID']?.toString() ?? '';

  String get name =>
      (raw['Name']?.toString() ?? '').replaceFirst(RegExp(r'^/'), '');

  String get image {
    final config = raw['Config'];
    if (config is Map) return config['Image']?.toString() ?? '';
    return raw['image']?.toString() ?? raw['imageName']?.toString() ?? '';
  }

  String get created => raw['Created']?.toString() ?? '';

  String get status {
    final state = raw['State'];
    if (state is Map) return state['Status']?.toString() ?? '';
    return raw['status']?.toString() ?? '';
  }

  /// Port mappings as display strings, e.g. "0.0.0.0:8080->80/tcp".
  List<String> get ports {
    final ns = raw['NetworkSettings'];
    if (ns is! Map) return const [];
    final portsMap = ns['Ports'];
    if (portsMap is! Map) return const [];
    final out = <String>[];
    portsMap.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        for (final binding in value) {
          if (binding is Map) {
            final hostIp = binding['HostIp']?.toString() ?? '';
            final hostPort = binding['HostPort']?.toString() ?? '';
            final addr = hostIp.isNotEmpty ? '$hostIp:$hostPort' : hostPort;
            out.add('$addr->$key');
          }
        }
      } else {
        out.add(key.toString());
      }
    });
    return out;
  }

  List<String> get mounts {
    final mounts = raw['Mounts'];
    if (mounts is! List) return const [];
    return mounts.map((m) {
      if (m is Map) {
        final src = m['Source']?.toString() ?? '';
        final dst = m['Destination']?.toString() ?? '';
        return '$src -> $dst';
      }
      return m.toString();
    }).toList();
  }

  List<String> get env {
    final config = raw['Config'];
    if (config is Map && config['Env'] is List) {
      return (config['Env'] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  String get cmd {
    final config = raw['Config'];
    if (config is Map) {
      final cmd = config['Cmd'];
      if (cmd is List) return cmd.join(' ');
      if (cmd is String) return cmd;
    }
    return '';
  }

  String get restartPolicy {
    final hostConfig = raw['HostConfig'];
    if (hostConfig is Map) {
      final rp = hostConfig['RestartPolicy'];
      if (rp is Map) return rp['Name']?.toString() ?? 'no';
    }
    return 'no';
  }

  String get networkMode {
    final hostConfig = raw['HostConfig'];
    if (hostConfig is Map) return hostConfig['NetworkMode']?.toString() ?? 'default';
    return 'default';
  }
}
