import '../domain/failures/provider_failure.dart';

String providerFailureMessage(ProviderFailure failure) =>
    switch (failure.type) {
      ProviderFailureType.network =>
        'Sem conexão com o servidor. Confira sua internet e tente novamente.',
      ProviderFailureType.invalidData =>
        'Revise os dados informados antes de continuar.',
      ProviderFailureType.forbidden =>
        'Seu perfil profissional ainda não está liberado para essa ação.',
      ProviderFailureType.notFound => 'Esse serviço não está mais disponível.',
      ProviderFailureType.invalidResponse ||
      ProviderFailureType.unavailable ||
      ProviderFailureType.unknown =>
        'Não foi possível concluir a operação agora. Tente novamente.',
    };
