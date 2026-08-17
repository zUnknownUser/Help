import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppStoreReviewService {
  AppStoreReviewService({
    InAppReview? review,
    SharedPreferencesAsync? preferences,
  }) : _review = review ?? InAppReview.instance,
       _preferences = preferences ?? SharedPreferencesAsync();

  static const _lastPromptKey = 'store_review_last_prompt_at';
  static const _cooldown = Duration(days: 120);
  final InAppReview _review;
  final SharedPreferencesAsync _preferences;

  Future<void> maybeRequest() async {
    final stored = await _preferences.getString(_lastPromptKey);
    final lastPrompt = stored == null ? null : DateTime.tryParse(stored);
    if (lastPrompt != null &&
        DateTime.now().difference(lastPrompt) < _cooldown) {
      return;
    }
    if (!await _review.isAvailable()) return;
    await _preferences.setString(
      _lastPromptKey,
      DateTime.now().toIso8601String(),
    );
    await _review.requestReview();
  }
}
