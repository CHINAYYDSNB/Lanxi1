// ---
// Directory: lib/models/dto/
// Responsibility: Data Transfer Objects for 1Panel V2 API.
// All DTOs have toDomain() → converts to domain models.
// Pattern: ApiResponse<T> → FooDto.fromJson() → .toDomain()
// ---
//
// Files:
//   api_response.dart      — ApiResponse<T> generic wrapper
//   host_status_dto.dart   — HostStatusDto, DiskDataDto
//   file_item_dto.dart     — FileItemDto, FilePermissionDto
//   container_dto.dart     — ContainerDto, ImageDto, ContainerDomain
