import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'local_db.dart';
import 'models.dart';

class ApiException implements Exception {
  ApiException(
    this.message, {
    this.statusCode,
    this.data,
    this.isNetwork = false,
  });

  final String message;
  final int? statusCode;
  final dynamic data;
  final bool isNetwork;

  @override
  String toString() {
    final buffer = StringBuffer('ApiException(');
    buffer.write('message: $message');
    if (statusCode != null) {
      buffer.write(', statusCode: $statusCode');
    }
    if (isNetwork) {
      buffer.write(', network: true');
    }
    if (data != null) {
      buffer.write(', data: $data');
    }
    buffer.write(')');
    return buffer.toString();
  }
}

class ApiMultipartFile {
  ApiMultipartFile({required this.field, required this.path, this.filename});

  final String field;
  final String path;
  final String? filename;
}

class ApiClient {
  ApiClient({required this.baseUrl, required this.database})
    : _client = http.Client();

  final String baseUrl;
  final LocalDatabase database;
  final http.Client _client;

  String? _accessToken;
  String? _refreshToken;

  bool get hasSession =>
      _refreshToken != null && _refreshToken!.trim().isNotEmpty;

  Future<void> init() async {
    final tokens = await database.loadTokens();
    if (tokens != null) {
      _accessToken = tokens.access;
      _refreshToken = tokens.refresh;
    }
  }

  Future<void> saveTokens(AuthTokens tokens) async {
    _accessToken = tokens.access;
    _refreshToken = tokens.refresh;
    await database.saveTokens(tokens);
  }

  Future<dynamic> get(
    String path, {
    Map<String, String>? query,
    bool auth = true,
  }) {
    return _send('GET', path, query: query, auth: auth);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('POST', path, body: body, auth: auth);
  }

  Future<dynamic> postMultipart(
    String path, {
    Map<String, dynamic>? fields,
    List<ApiMultipartFile> files = const [],
    bool auth = true,
  }) {
    return _sendMultipart(
      'POST',
      path,
      fields: fields,
      files: files,
      auth: auth,
    );
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('PUT', path, body: body, auth: auth);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('PATCH', path, body: body, auth: auth);
  }

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) {
    return _send('DELETE', path, body: body, auth: auth);
  }

  Future<dynamic> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? body,
    bool auth = true,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (auth && _accessToken != null && _accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }

    http.Response response;
    try {
      switch (method) {
        case 'POST':
          response = await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;
        case 'PUT':
          response = await _client.put(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;
        case 'PATCH':
          response = await _client.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;
        case 'DELETE':
          response = await _client.delete(
            uri,
            headers: headers,
            body: jsonEncode(body ?? {}),
          );
          break;
        default:
          response = await _client.get(uri, headers: headers);
      }
    } on SocketException catch (error) {
      throw ApiException(
        'Network error during $method $path: ${error.message}',
        isNetwork: true,
      );
    } on HttpException catch (error) {
      throw ApiException(
        'Network error during $method $path: ${error.message}',
        isNetwork: true,
      );
    } on HandshakeException catch (error) {
      throw ApiException(
        'TLS error during $method $path: ${error.message}',
        isNetwork: true,
      );
    } catch (error) {
      throw ApiException('Unexpected error during $method $path: $error');
    }

    if (response.statusCode == 401 && auth && !retried) {
      final refreshed = await _refreshAccessToken();
      if (refreshed) {
        return _send(
          method,
          path,
          query: query,
          body: body,
          auth: auth,
          retried: true,
        );
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Request failed: $method $path',
        statusCode: response.statusCode,
        data: _decodeResponse(response.body),
      );
    }

    return _decodeResponse(response.body);
  }

  Future<dynamic> _sendMultipart(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, dynamic>? fields,
    List<ApiMultipartFile> files = const [],
    bool auth = true,
    bool retried = false,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final request = http.MultipartRequest(method, uri);
    request.headers['Accept'] = 'application/json';
    if (auth && _accessToken != null && _accessToken!.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $_accessToken';
    }

    void addFieldValue(String key, dynamic value) {
      if (value == null) {
        return;
      }
      if (value is Iterable && value is! String) {
        for (final item in value) {
          addFieldValue(key, item);
        }
        return;
      }
      final text = value.toString();
      if (text.isEmpty) {
        return;
      }
      request.fields[key] = text;
    }

    (fields ?? const <String, dynamic>{}).forEach(addFieldValue);

    try {
      for (final file in files) {
        final filePath = file.path.trim();
        if (filePath.isEmpty) {
          continue;
        }
        request.files.add(
          await http.MultipartFile.fromPath(
            file.field,
            filePath,
            filename: file.filename,
          ),
        );
      }

      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401 && auth && !retried) {
        final refreshed = await _refreshAccessToken();
        if (refreshed) {
          return _sendMultipart(
            method,
            path,
            query: query,
            fields: fields,
            files: files,
            auth: auth,
            retried: true,
          );
        }
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'Request failed: $method $path',
          statusCode: response.statusCode,
          data: _decodeResponse(response.body),
        );
      }

      return _decodeResponse(response.body);
    } on SocketException catch (error) {
      throw ApiException(
        'Network error during $method $path: ${error.message}',
        isNetwork: true,
      );
    } on HttpException catch (error) {
      throw ApiException(
        'Network error during $method $path: ${error.message}',
        isNetwork: true,
      );
    } on HandshakeException catch (error) {
      throw ApiException(
        'TLS error during $method $path: ${error.message}',
        isNetwork: true,
      );
    } catch (error) {
      if (error is ApiException) rethrow;
      throw ApiException('Unexpected error during $method $path: $error');
    }
  }

  dynamic _decodeResponse(String body) {
    if (body.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  Future<bool> _refreshAccessToken() async {
    final refresh = _refreshToken;
    if (refresh == null || refresh.isEmpty) {
      return false;
    }
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/token/refresh/'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'refresh': refresh}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return false;
      }
      final data = _decodeResponse(response.body);
      if (data is Map && data['access'] != null) {
        final access = data['access'].toString();
        await saveTokens(AuthTokens(access: access, refresh: refresh));
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }
}
