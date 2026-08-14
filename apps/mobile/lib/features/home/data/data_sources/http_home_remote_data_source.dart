import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../errors/home_data_exception.dart';
import '../models/home_content_model.dart';
import '../models/json_reader.dart';
import 'home_remote_data_source.dart';

class HttpHomeRemoteDataSource implements HomeRemoteDataSource {
  HttpHomeRemoteDataSource({
    required this.client,
    required String baseUrl,
    this.timeout = const Duration(seconds: 8),
  }) : _endpoint = Uri.parse(
         '${baseUrl.trim().replaceFirst(RegExp(r'/+$'), '')}/v1/home',
       );

  final http.Client client;
  final Uri _endpoint;
  final Duration timeout;

  @override
  Future<HomeContentModel> fetchHome() async {
    try {
      final response = await client.get(_endpoint).timeout(timeout);
      if (response.statusCode != HttpStatus.ok) {
        throw HomeDataException(
          HomeDataErrorCode.unavailable,
          debugMessage: 'GET /v1/home returned HTTP ${response.statusCode}',
        );
      }
      final envelope = JsonReader.map(
        jsonDecode(utf8.decode(response.bodyBytes)),
        'response',
      );
      return HomeContentModel.fromJson(
        JsonReader.map(envelope['data'], 'data'),
      );
    } on HomeDataException {
      rethrow;
    } on FormatException catch (error) {
      throw HomeDataException(
        HomeDataErrorCode.invalidResponse,
        debugMessage: error.message,
      );
    } on TimeoutException catch (error) {
      throw _networkError(error);
    } on SocketException catch (error) {
      throw _networkError(error);
    } on http.ClientException catch (error) {
      throw _networkError(error);
    }
  }

  HomeDataException _networkError(Object error) => HomeDataException(
    HomeDataErrorCode.network,
    debugMessage: error.toString(),
  );
}
