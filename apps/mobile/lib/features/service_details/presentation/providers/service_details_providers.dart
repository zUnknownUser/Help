import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers/service_details_data_providers.dart';
import '../../domain/entities/service_details.dart';
import '../../domain/failures/service_details_failure.dart';
import '../../domain/use_cases/create_service_request.dart';
import '../../domain/use_cases/get_service_details.dart';

final getServiceDetailsProvider = Provider<GetServiceDetails>(
  (ref) => GetServiceDetails(ref.watch(serviceDetailsRepositoryProvider)),
);

final createServiceRequestProvider = Provider<CreateServiceRequest>(
  (ref) => CreateServiceRequest(ref.watch(serviceDetailsRepositoryProvider)),
);

final serviceDetailsProvider = FutureProvider.autoDispose
    .family<ServiceDetails, String>((ref, serviceId) async {
      final result = await ref.watch(getServiceDetailsProvider)(serviceId);
      return result.fold(
        onSuccess: (details) => details,
        onFailure: (failure) =>
            throw ServiceDetailsPresentationException(failure),
      );
    });

class ServiceDetailsPresentationException implements Exception {
  const ServiceDetailsPresentationException(this.failure);
  final ServiceDetailsFailure failure;
}
