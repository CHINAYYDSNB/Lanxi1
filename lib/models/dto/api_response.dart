/// Generic wrapper for 1Panel V2 API responses.
///
/// All 1Panel endpoints return: `{"code": 200, "message": "success", "data": ...}`
class ApiResponse<T> {
  final int code;
  final String message;
  final T? data;

  const ApiResponse({
    required this.code,
    required this.message,
    this.data,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJsonT,
  ) {
    return ApiResponse(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: json['data'] != null && (json['data'] as Map<String, dynamic>).isNotEmpty
          ? fromJsonT(json['data'] as Map<String, dynamic>)
          : null,
    );
  }

  factory ApiResponse.fromJsonList(
    Map<String, dynamic> json,
    T Function(List<dynamic>) fromJsonList,
  ) {
    return ApiResponse(
      code: json['code'] as int? ?? 0,
      message: json['message'] as String? ?? '',
      data: json['data'] != null ? fromJsonList(json['data'] as List<dynamic>) : null,
    );
  }

  bool get isSuccess => code == 200;
}
