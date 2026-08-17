import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/user_role.dart';
import '../../domain/entities/profile_details.dart';
import '../errors/profile_data_exception.dart';
import '../models/user_profile_model.dart';
import 'profile_remote_data_source.dart';

class HttpProfileRemoteDataSource implements ProfileRemoteDataSource {
  factory HttpProfileRemoteDataSource({
    required http.Client client,
    required String baseUrl,
    Duration timeout = const Duration(seconds: 8),
  }) => HttpProfileRemoteDataSource._(client, baseUrl, timeout);

  const HttpProfileRemoteDataSource._(
    this._client,
    this._baseUrl,
    this._timeout,
  );

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  Uri get _profileUri => Uri.parse('$_baseUrl/v1/profile');

  @override
  Future<UserProfileModel> getCurrent() async {
    try {
      return _decode(await _client.get(_profileUri).timeout(_timeout));
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  @override
  Future<UserProfileModel> register({
    required String displayName,
    required UserRole role,
  }) async {
    try {
      final response = await _client
          .post(
            _profileUri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'display_name': displayName, 'role': role.value}),
          )
          .timeout(_timeout);
      return _decode(response);
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  @override
  Future<UserProfileModel> update(ProfileUpdate update) async {
    final professional = update.professional;
    return _request(
      () => _client.put(
        _profileUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'display_name': update.displayName,
          'phone': update.phone,
          'contact_preference': update.preferences.contactPreference,
          'photo_visibility': update.preferences.photoVisibility,
          'last_seen_visibility': update.preferences.lastSeenVisibility,
          'show_online': update.preferences.showOnline,
          'allow_conversation_requests':
              update.preferences.allowConversationRequests,
          'professional': professional == null
              ? null
              : {
                  'title': professional.title,
                  'bio': professional.bio,
                  'years_experience': professional.yearsExperience,
                  'service_radius_km': professional.serviceRadiusKm,
                },
        }),
      ),
    );
  }

  @override
  Future<void> uploadAvatar(String filePath) async {
    final response = await _multipart(
      'PUT',
      Uri.parse('$_baseUrl/v1/profile/avatar'),
      filePath,
    );
    _ensureSuccess(response);
  }

  @override
  Future<PortfolioItem> uploadPortfolio(
    String filePath, {
    String caption = '',
  }) async {
    final response = await _multipart(
      'POST',
      Uri.parse('$_baseUrl/v1/profile/portfolio'),
      filePath,
      fields: {'caption': caption},
    );
    _ensureSuccess(response);
    final envelope = jsonDecode(response.body) as Map<String, dynamic>;
    final data = envelope['data'] as Map<String, dynamic>;
    return PortfolioItem(
      id: data['id'] as String,
      url: data['url'] as String,
      caption: data['caption'] as String? ?? '',
    );
  }

  @override
  Future<void> deletePortfolio(String id) async {
    final response = await _network(
      () => _client.delete(Uri.parse('$_baseUrl/v1/profile/portfolio/$id')),
    );
    _ensureSuccess(response);
  }

  @override
  Future<UserProfileModel> syncEmail() => _request(
    () => _client.post(Uri.parse('$_baseUrl/v1/profile/email/sync')),
  );

  Future<UserProfileModel> _request(
    Future<http.Response> Function() operation,
  ) async => _decode(await _network(operation));

  Future<http.Response> _multipart(
    String method,
    Uri uri,
    String filePath, {
    Map<String, String> fields = const {},
  }) async {
    try {
      final request = http.MultipartRequest(method, uri)..fields.addAll(fields);
      request.files.add(await http.MultipartFile.fromPath('file', filePath));
      return http.Response.fromStream(
        await _client.send(request).timeout(_timeout),
      );
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  Future<http.Response> _network(
    Future<http.Response> Function() operation,
  ) async {
    try {
      return await operation().timeout(_timeout);
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 400) {
      throw const ProfileDataException(ProfileDataErrorCode.invalidData);
    }
    if (response.statusCode == 401) {
      throw const ProfileDataException(ProfileDataErrorCode.unauthorized);
    }
    throw const ProfileDataException(ProfileDataErrorCode.unavailable);
  }

  UserProfileModel _decode(http.Response response) {
    if (response.statusCode == 404) {
      throw const ProfileDataException(ProfileDataErrorCode.notFound);
    }
    if (response.statusCode == 401) {
      throw const ProfileDataException(ProfileDataErrorCode.unauthorized);
    }
    if (response.statusCode == 400) {
      throw const ProfileDataException(ProfileDataErrorCode.invalidData);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const ProfileDataException(ProfileDataErrorCode.unavailable);
    }
    try {
      return UserProfileModel.fromEnvelope(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
    } on FormatException catch (error) {
      throw ProfileDataException(
        ProfileDataErrorCode.unknown,
        debugMessage: '$error',
      );
    } on TypeError catch (error) {
      throw ProfileDataException(
        ProfileDataErrorCode.unknown,
        debugMessage: '$error',
      );
    }
  }

  ProfileDataException _networkError(Object error) => ProfileDataException(
    ProfileDataErrorCode.network,
    debugMessage: '$error',
  );
}
