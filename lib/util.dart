import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'creds.dart';

Uri? optionalParseUri(String? s) => s == null ? null : Uri.parse(s);

String jsonEncode(Object? data) =>
    const JsonEncoder.withIndent(' ').convert(data);

Uri ensureUriEndsWithSlash(Uri uri) {
  String uriStr = uri.toString();
  if (!uriStr.endsWith('/')) {
    uri = Uri.parse('$uriStr/');
  }
  return uri;
}

Uri getLoginUri({
  required Uri cognitoUri,
  required String clientId,
  required Uri redirectUri,
  List<String>? scopes,
}) {
  Map<String, String> queryParams = {
    'client_id': clientId,
    'response_type': 'code',
    'redirect_uri': redirectUri.toString()
  };
  if (scopes != null && scopes.isNotEmpty) {
    queryParams['scope'] = scopes.join(' ');
  }
  final loginUri =
      cognitoUri.resolve('login').replace(queryParameters: queryParams);
  return loginUri;
}

String getTokenAuthorizationHeader({
  required String clientId,
  required String clientSecret,
}) {
  final secretValue = "$clientId:$clientSecret";
  final secretBase64 = base64.encode(utf8.encode(secretValue));
  final tokenAuthHeader = "Basic $secretBase64";
  return tokenAuthHeader;
}

Future<Map<String, dynamic>> getTokensFromAuthCode({
  required Uri tokenUri,
  required String clientId,
  String? clientSecret,
  required String authCode,
  required Uri redirectUri,
}) async {
  final client = http.Client();
  try {
    final Map<String, String> headers = {};
    if (clientSecret != null) {
      headers["Authorization"] = getTokenAuthorizationHeader(
          clientId: clientId, clientSecret: clientSecret);
    }
    final Map<String, String> queryParameters = {
      "grant_type": "authorization_code",
      "client_id": clientId,
      "code": authCode,
      "redirect_uri": redirectUri.toString(),
    };
    final response = await client.post(
      tokenUri,
      headers: headers,
      body: queryParameters,
    );
    if (response.statusCode != 200) {
      throw HttpException(
        "Bad HTTP status code ${response.statusCode} in token endpoint response",
        uri: tokenUri,
      );
    }
    // print(response.toString());
    final decodedResponse = jsonDecode(
      utf8.decode(response.bodyBytes),
    ) as Map<String, dynamic>;
    // print(decodedResponse.toString());
    return decodedResponse;
  } finally {
    client.close();
  }
}

Future<Creds> getCredsFromAuthCode({
  required Uri tokenUri,
  required String clientId,
  String? clientSecret,
  required String authCode,
  required Uri redirectUri,
}) async {
  final tokens = await getTokensFromAuthCode(
    tokenUri: tokenUri,
    clientId: clientId,
    clientSecret: clientSecret,
    authCode: authCode,
    redirectUri: redirectUri,
  );
  final creds = Creds(
    accessToken: tokens['access_token'],
    idToken: tokens['id_token'],
    refreshToken: tokens['refresh_token'],
    expireSeconds: tokens['expires_in'],
  );
  return creds;
}