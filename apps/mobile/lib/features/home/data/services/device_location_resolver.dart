import 'dart:convert';

import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import '../../domain/entities/home_location.dart';
import '../../domain/services/location_resolver.dart';

class DeviceLocationResolver implements LocationResolver {
  DeviceLocationResolver(this._client)
    : _geocoding = geocoding.Geocoding(locale: const Locale('pt', 'BR'));

  final http.Client _client;
  final geocoding.Geocoding _geocoding;

  @override
  Future<HomeLocation> current({String label = 'Localização atual'}) async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationResolutionException(
        LocationResolutionError.serviceDisabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const LocationResolutionException(
        LocationResolutionError.permissionDeniedForever,
      );
    }
    if (permission == LocationPermission.denied) {
      throw const LocationResolutionException(
        LocationResolutionError.permissionDenied,
      );
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      final placemarks = await _geocoding
          .placemarkFromCoordinates(position.latitude, position.longitude)
          .timeout(const Duration(seconds: 8));
      if (placemarks.isEmpty) throw StateError('empty reverse geocoding');
      return _fromPlacemark(
        placemarks.first,
        latitude: position.latitude,
        longitude: position.longitude,
        label: label,
      );
    } catch (_) {
      throw const LocationResolutionException(
        LocationResolutionError.unavailable,
      );
    }
  }

  @override
  Future<HomeLocation> fromPostalCode({
    required String postalCode,
    required String number,
    String complement = '',
    String label = 'Endereço selecionado',
  }) async {
    final cep = postalCode.replaceAll(RegExp(r'\D'), '');
    if (cep.length != 8 || number.trim().isEmpty) {
      throw const LocationResolutionException(
        LocationResolutionError.postalCodeNotFound,
      );
    }
    try {
      final response = await _client
          .get(Uri.https('viacep.com.br', '/ws/$cep/json/'))
          .timeout(const Duration(seconds: 8));
      final json = jsonDecode(utf8.decode(response.bodyBytes));
      if (response.statusCode != 200 ||
          json is! Map<String, dynamic> ||
          json['erro'] == true) {
        throw const LocationResolutionException(
          LocationResolutionError.postalCodeNotFound,
        );
      }
      final street = _value(json['logradouro']);
      final district = _value(json['bairro']);
      final city = _value(json['localidade']);
      final state = _value(json['uf']);
      final normalizedNumber = number.trim();
      final normalizedComplement = complement.trim();
      final address = _formatAddress(
        street: street,
        number: normalizedNumber,
        complement: normalizedComplement,
        district: district,
        city: city,
        state: state,
        postalCode: cep,
      );
      final coordinates = await _geocoding
          .locationFromAddress(address)
          .timeout(const Duration(seconds: 8));
      if (coordinates.isEmpty) throw StateError('empty forward geocoding');
      return HomeLocation(
        address: address,
        availabilityLabel: label,
        postalCode: cep,
        street: street,
        streetNumber: normalizedNumber,
        complement: normalizedComplement,
        district: district,
        city: city,
        state: state,
        latitude: coordinates.first.latitude,
        longitude: coordinates.first.longitude,
      );
    } on LocationResolutionException {
      rethrow;
    } catch (_) {
      throw const LocationResolutionException(
        LocationResolutionError.unavailable,
      );
    }
  }

  HomeLocation _fromPlacemark(
    geocoding.Placemark place, {
    required double latitude,
    required double longitude,
    required String label,
  }) {
    final street = (place.street ?? place.thoroughfare ?? '').trim();
    final number = (place.subThoroughfare ?? '').trim();
    final district = (place.subLocality ?? '').trim();
    final city = (place.locality ?? place.subAdministrativeArea ?? '').trim();
    final state = (place.administrativeArea ?? '').trim();
    final postalCode = (place.postalCode ?? '').replaceAll(RegExp(r'\D'), '');
    return HomeLocation(
      address: _formatAddress(
        street: street,
        number: number,
        complement: '',
        district: district,
        city: city,
        state: state,
        postalCode: postalCode,
      ),
      availabilityLabel: label,
      postalCode: postalCode,
      street: street,
      streetNumber: number,
      district: district,
      city: city,
      state: state.length == 2 ? state : _stateCode(state),
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String _value(Object? value) => value is String ? value.trim() : '';

  static String _formatAddress({
    required String street,
    required String number,
    required String complement,
    required String district,
    required String city,
    required String state,
    required String postalCode,
  }) => [
    [street, number].where((value) => value.isNotEmpty).join(', '),
    complement,
    district,
    [city, state].where((value) => value.isNotEmpty).join(' - '),
    postalCode,
  ].where((value) => value.isNotEmpty).join(', ');

  static String _stateCode(String value) {
    const codes = {
      'Acre': 'AC',
      'Alagoas': 'AL',
      'Amapá': 'AP',
      'Amazonas': 'AM',
      'Bahia': 'BA',
      'Ceará': 'CE',
      'Distrito Federal': 'DF',
      'Espírito Santo': 'ES',
      'Goiás': 'GO',
      'Maranhão': 'MA',
      'Mato Grosso': 'MT',
      'Mato Grosso do Sul': 'MS',
      'Minas Gerais': 'MG',
      'Pará': 'PA',
      'Paraíba': 'PB',
      'Paraná': 'PR',
      'Pernambuco': 'PE',
      'Piauí': 'PI',
      'Rio de Janeiro': 'RJ',
      'Rio Grande do Norte': 'RN',
      'Rio Grande do Sul': 'RS',
      'Rondônia': 'RO',
      'Roraima': 'RR',
      'Santa Catarina': 'SC',
      'São Paulo': 'SP',
      'Sergipe': 'SE',
      'Tocantins': 'TO',
    };
    return codes[value] ??
        value.substring(0, value.length.clamp(0, 2)).toUpperCase();
  }
}
