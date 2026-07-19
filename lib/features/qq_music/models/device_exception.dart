class QqMusicDeviceException implements Exception {
  const QqMusicDeviceException(this.message, {this.statusCode, this.data});

  final String message;
  final int? statusCode;
  final Object? data;

  @override
  String toString() => message;
}
