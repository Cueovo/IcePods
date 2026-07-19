class QqMusicApiException implements Exception {
  const QqMusicApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final int? code;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => message;
}
