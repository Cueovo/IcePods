enum QqMusicRequestPlatform { web, android }

class QqMusicCgiRequest {
  const QqMusicCgiRequest({
    required this.module,
    required this.method,
    this.param = const {},
    this.preserveBool = false,
  });

  final String module;
  final String method;
  final Map<String, Object?> param;
  final bool preserveBool;
}
