class QqMusicApiException implements Exception {
  const QqMusicApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final int? code;

  /// True login / session failures (not VIP, copyright, or missing guest URL).
  bool get isUnauthorized =>
      statusCode == 401 ||
      code == 1000 ||
      code == 104400 ||
      code == 104401;

  @override
  String toString() => message;
}
