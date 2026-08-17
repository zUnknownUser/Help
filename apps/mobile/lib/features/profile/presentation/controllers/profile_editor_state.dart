import '../../domain/failures/profile_failure.dart';

class ProfileEditorState {
  const ProfileEditorState({this.isSaving = false, this.failure});

  final bool isSaving;
  final ProfileFailure? failure;
}
