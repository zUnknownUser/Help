import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../domain/entities/user_role.dart';
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
