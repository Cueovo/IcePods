import 'package:http/http.dart' as http;

http.Client createQqMusicHttpClient() => http.Client();

http.Client createQqMusicAuthenticatedHttpClient() => http.Client();

bool get canUseBrowserCredentials => false;

void syncBrowserCredentialCookies(
  Uri baseUri,
  Map<String, String> credentialFields,
) {}

void clearBrowserCredentialCookies(Uri baseUri, Iterable<String> names) {}
