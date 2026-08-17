import '../../domain/entities/service_request_item.dart';
import '../../domain/failures/service_request_failure.dart';

class ServiceRequestsState {
  const ServiceRequestsState({
    required this.role,
    this.items = const [],
    this.nextCursor = '',
    this.loading = true,
    this.loadingMore = false,
    this.failure,
  });

  final RequestViewerRole role;
  final List<ServiceRequestItem> items;
  final String nextCursor;
  final bool loading;
  final bool loadingMore;
  final ServiceRequestFailure? failure;

  bool get canLoadMore => nextCursor.isNotEmpty && !loadingMore;

  ServiceRequestsState copyWith({
    List<ServiceRequestItem>? items,
    String? nextCursor,
    bool? loading,
    bool? loadingMore,
    ServiceRequestFailure? failure,
    bool clearFailure = false,
  }) => ServiceRequestsState(
    role: role,
    items: items ?? this.items,
    nextCursor: nextCursor ?? this.nextCursor,
    loading: loading ?? this.loading,
    loadingMore: loadingMore ?? this.loadingMore,
    failure: clearFailure ? null : failure ?? this.failure,
  );
}
