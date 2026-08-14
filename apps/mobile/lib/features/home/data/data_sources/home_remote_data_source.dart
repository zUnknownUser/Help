import '../models/home_content_model.dart';

abstract interface class HomeRemoteDataSource {
  Future<HomeContentModel> fetchHome();
}
