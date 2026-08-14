import '../repositories/home_repository.dart';

class GetHome {
  const GetHome(this._repository);

  final HomeRepository _repository;

  Future<HomeResult> call() => _repository.getHome();
}
