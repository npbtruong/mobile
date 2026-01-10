import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../constants/api_constants.dart';

class ApiException implements Exception {
	ApiException(this.message, {this.statusCode});

	final String message;
	final int? statusCode;

	@override
	String toString() => 'ApiException(statusCode: $statusCode, message: $message)';
}

class ApiService {
	ApiService({HttpClient? httpClient}) : _httpClient = httpClient ?? HttpClient();

	final HttpClient _httpClient;

	Future<Map<String, dynamic>> postJson(
		String endpoint, {
		required Map<String, dynamic> body,
		Map<String, String>? headers,
		Duration timeout = const Duration(seconds: 20),
	}) async {
		final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
		final request = await _httpClient.postUrl(uri);

		request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
		headers?.forEach((key, value) => request.headers.set(key, value));

		request.add(utf8.encode(jsonEncode(body)));

		late final HttpClientResponse response;
		try {
			response = await request.close().timeout(timeout);
		} on TimeoutException {
			request.abort();
			throw ApiException('Request timed out');
		} on SocketException catch (e) {
			throw ApiException('Network error: ${e.message}');
		}

		final responseBody = await response.transform(utf8.decoder).join();
		final statusCode = response.statusCode;

		Map<String, dynamic> decoded;
		try {
			final jsonValue = jsonDecode(responseBody);
			decoded = (jsonValue is Map<String, dynamic>) ? jsonValue : <String, dynamic>{};
		} catch (_) {
			decoded = <String, dynamic>{};
		}

		final isSuccess = statusCode >= 200 && statusCode < 300;
		if (!isSuccess) {
			final message = (decoded['message'] is String && (decoded['message'] as String).isNotEmpty)
					? decoded['message'] as String
					: 'Request failed';
			throw ApiException(message, statusCode: statusCode);
		}

		return decoded;
	}
}

