import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:help/features/profile/data/data_sources/http_profile_remote_data_source.dart';
import 'package:help/features/profile/data/errors/profile_data_exception.dart';
import 'package:help/features/profile/domain/entities/user_role.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('cadastra o perfil com papel escolhido e lê o envelope', () async {
    late http.Request captured;
    final dataSource = HttpProfileRemoteDataSource(
      client: MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({
            'data': {
              'email': 'maria@example.com',
              'display_name': 'Maria Silva',
              'active_role': 'provider',
              'roles': ['provider'],
            },
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      }),
      baseUrl: 'https://api.example.com',
    );

    final profile = await dataSource.register(
      displayName: 'Maria Silva',
      role: UserRole.provider,
    );

    expect(captured.method, 'POST');
    expect(jsonDecode(captured.body), {
      'display_name': 'Maria Silva',
      'role': 'provider',
    });
    expect(profile.activeRole, UserRole.provider);
    expect(profile.roles, [UserRole.provider]);
  });

  test('traduz perfil ainda não cadastrado', () async {
    final dataSource = HttpProfileRemoteDataSource(
      client: MockClient((_) async => http.Response('{}', 404)),
      baseUrl: 'https://api.example.com',
    );

    expect(dataSource.getCurrent, throwsA(isA<ProfileDataException>()));
  });
  test(
    'encerra cadastro sem conexÃ£o em vez de carregar para sempre',
    () async {
      final pending = Completer<http.Response>();
      final dataSource = HttpProfileRemoteDataSource(
        client: MockClient((_) => pending.future),
        baseUrl: 'https://api.example.com',
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        dataSource.register(displayName: 'Maria', role: UserRole.customer),
        throwsA(
          isA<ProfileDataException>().having(
            (error) => error.code,
            'code',
            ProfileDataErrorCode.network,
          ),
        ),
      );
    },
  );
}
