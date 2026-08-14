import '../models/home_content_model.dart';

abstract interface class HomeCacheDataSource {
  HomeContentModel? read();
  void write(HomeContentModel content);
}

class InMemoryHomeCacheDataSource implements HomeCacheDataSource {
  HomeContentModel? _content;

  @override
  HomeContentModel? read() => _content;

  @override
  void write(HomeContentModel content) => _content = content;
}
