/// Maps 1Panel Docker container API responses.
class ContainerDto {
  final String containerId;
  final String name;
  final String image;
  final String status;
  final String state;
  final String? ip;
  final int? port;
  final String? createdAt;

  const ContainerDto({
    required this.containerId,
    required this.name,
    required this.image,
    required this.status,
    required this.state,
    this.ip,
    this.port,
    this.createdAt,
  });

  factory ContainerDto.fromJson(Map<String, dynamic> json) {
    return ContainerDto(
      containerId: json['containerId'] as String? ?? json['ID'] as String? ?? '',
      name: json['name'] as String? ?? json['Name'] as String? ?? '',
      image: json['image'] as String? ?? json['Image'] as String? ?? '',
      status: json['status'] as String? ?? json['Status'] as String? ?? '',
      state: json['state'] as String? ?? json['State'] as String? ?? '',
      ip: json['ip'] as String? ?? json['IP'] as String?,
      port: (json['port'] as num?)?.toInt() ?? (json['Port'] as num?)?.toInt(),
      createdAt: json['createdAt'] as String? ?? json['CreatedAt'] as String?,
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
    );
  }
}

/// Maps 1Panel Docker image API responses.
class ImageDto {
  final String imageId;
  final String repository;
  final String tag;
  final int size;
  final String? createdAt;

  const ImageDto({
    required this.imageId,
    required this.repository,
    required this.tag,
    required this.size,
    this.createdAt,
  });

  factory ImageDto.fromJson(Map<String, dynamic> json) {
    return ImageDto(
      imageId: json['imageId'] as String? ?? json['ID'] as String? ?? '',
      repository: json['repository'] as String? ?? json['Repository'] as String? ?? '',
      tag: json['tag'] as String? ?? json['Tag'] as String? ?? 'latest',
      size: (json['size'] as num?)?.toInt() ?? 0,
      createdAt: json['createdAt'] as String? ?? json['CreatedAt'] as String?,
    );
  }
}

/// Domain model for a Docker container (used by UI).
class ContainerDomain {
  final String id;
  final String name;
  final String image;
  final String status;
  final String state;
  final String ipAddress;
  final int? port;

  const ContainerDomain({
    required this.id,
    required this.name,
    required this.image,
    required this.status,
    required this.state,
    this.ipAddress = '',
    this.port,
  });

  bool get isRunning => state == 'running';
  bool get isStopped => state == 'exited' || state == 'stopped';
}
