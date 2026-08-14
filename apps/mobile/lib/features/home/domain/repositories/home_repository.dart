import '../../../../core/result/result.dart';
import '../entities/home_content.dart';
import '../failures/home_failure.dart';

typedef HomeOperationResult<T> = Result<T, HomeFailure>;
typedef HomeResult = HomeOperationResult<HomeContent>;

abstract interface class HomeRepository {
  Future<HomeResult> getHome();
}
