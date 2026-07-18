import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

http.Client createQqMusicHttpClient() => BrowserClient();

http.Client createQqMusicAuthenticatedHttpClient() =>
    BrowserClient()..withCredentials = true;

bool get canUseBrowserCredentials => true;

void syncBrowserCredentialCookies(
  Uri baseUri,
  Map<String, String> credentialFields,
) {
  _requireSameHost(baseUri);
  final secure = web.window.location.protocol == 'https:' ? '; Secure' : '';
  for (final entry in credentialFields.entries) {
    if (entry.value.isEmpty || entry.value == '0') {
      continue;
    }
    web.document.cookie =
        '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}; Path=/; SameSite=Lax$secure';
  }
}

void clearBrowserCredentialCookies(Uri baseUri, Iterable<String> names) {
  _requireSameHost(baseUri);
  final secure = web.window.location.protocol == 'https:' ? '; Secure' : '';
  for (final name in names) {
    web.document.cookie =
        '${Uri.encodeComponent(name)}=; Path=/; Max-Age=0; SameSite=Lax$secure';
  }
}

void _requireSameHost(Uri baseUri) {
  final pageHost = web.window.location.hostname;
  if (baseUri.host != pageHost) {
    throw StateError(
      'Web 登录要求页面与 QQ 音乐 API 使用相同主机；当前页面主机是 $pageHost，API 主机是 ${baseUri.host}',
    );
  }
}
