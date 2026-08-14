import '../../domain/failures/home_failure.dart';

class HomeActionState {
  const HomeActionState({this.isLoading = false, this.failure});

  final bool isLoading;
  final HomeFailure? failure;
}
