import '../../../../core/result/result.dart';
import '../entities/home_content.dart';
import '../failures/home_failure.dart';

typedef HomeResult = Result<HomeContent, HomeFailure>;

abstract interface class HomeRepository {
  Future<HomeResult> getHome();
}
