import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/entities/user_role.dart';
import '../errors/profile_data_exception.dart';
import '../models/user_profile_model.dart';
import 'profile_remote_data_source.dart';

class HttpProfileRemoteDataSource implements ProfileRemoteDataSource {
  factory HttpProfileRemoteDataSource({
    required http.Client client,
    required String baseUrl,
  }) => HttpProfileRemoteDataSource._(client, baseUrl);

  const HttpProfileRemoteDataSource._(this._client, this._baseUrl);

  final http.Client _client;
  final String _baseUrl;

  Uri get _profileUri => Uri.parse('$_baseUrl/v1/profile');

  @override
  Future<UserProfileModel> getCurrent() async {
    try {
      return _decode(await _client.get(_profileUri));
    } on http.ClientException catch (error) {
      throw ProfileDataException(
        ProfileDataErrorCode.network,
        debugMessage: '$error',
      );
    }
  }

  @override
  Future<UserProfileModel> register({
    required String displayName,
    required UserRole role,
  }) async {
    try {
      final response = await _client.post(
        _profileUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'display_name': displayName, 'role': role.value}),
      );
      return _decode(response);
    } on http.ClientException catch (error) {
      throw ProfileDataException(
        ProfileDataErrorCode.network,
        debugMessage: '$error',
      );
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
}
