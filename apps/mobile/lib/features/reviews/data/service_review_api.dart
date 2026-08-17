import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../domain/service_review.dart';

class ServiceReviewApi {
  const ServiceReviewApi(this._client, this._baseUrl);
  final http.Client _client;
  final String _baseUrl;

  Future<List<ServiceReview>> list(String requestId) async {
    final response = await _send(
      () => _client.get(
        Uri.parse('$_baseUrl/v1/service-requests/$requestId/reviews'),
      ),
    );
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>;
    final items = data['items'] as List;
    return items
        .whereType<Map<String, dynamic>>()
        .map(_review)
        .toList(growable: false);
  }

  Future<ServiceReview> save(
    String requestId,
    int rating,
    String comment,
  ) async {
    final response = await _send(
      () => _client.put(
        Uri.parse('$_baseUrl/v1/service-requests/$requestId/reviews/mine'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'rating': rating, 'comment': comment}),
      ),
    );
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    return _review(envelope['data'] as Map<String, dynamic>);
  }

  Future<http.Response> _send(Future<http.Response> Function() action) async {
    try {
      final response = await action().timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ServiceReviewException(_message(response));
      }
      return response;
    } on TimeoutException {
      throw const ServiceReviewException('Sem conexão. Tente novamente.');
    } on SocketException {
      throw const ServiceReviewException('Sem conexão. Tente novamente.');
    } on http.ClientException {
      throw const ServiceReviewException('Sem conexão. Tente novamente.');
    }
  }

  String _message(http.Response response) {
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return body['message'] as String? ??
          'Não foi possível salvar a avaliação.';
    } catch (_) {
      return 'Não foi possível salvar a avaliação.';
    }
  }
}

ServiceReview _review(Map<String, dynamic> json) => ServiceReview(
  id: json['id'] as String,
  reviewerRole: json['reviewer_role'] as String,
  rating: json['rating'] as int,
  comment: json['comment'] as String? ?? '',
);

class ServiceReviewException implements Exception {
  const ServiceReviewException(this.message);
  final String message;
}
