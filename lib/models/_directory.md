// ---
// Directory: lib/models/
// Responsibility: Data models split into DTO (API-facing) and Domain (business logic).
//
// dto/     — Data Transfer Objects. Map 1Panel API responses.
//            All DTOs have toDomain() to convert to domain models.
// domain/  — Business domain models used by UI and services.
//            Independent of API structure.
// ---
//
// Files:
//   compress_result.dart — Compression result (not from API, stays flat)
