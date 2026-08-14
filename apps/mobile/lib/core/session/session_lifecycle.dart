import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/chat/data/providers/chat_data_providers.dart';
import '../../features/notifications/data/push_providers.dart';

typedef SessionStarter = void Function(String userId);

final sessionStarterProvider = Provider<SessionStarter>((ref) {
  return (userId) {
    ref.read(chatRealtimeCoordinatorProvider).start(userId);
    unawaited(ref.read(pushRegistrationServiceProvider).start());
  };
});

class SessionLifecycle extends ConsumerStatefulWidget {
  const SessionLifecycle({
    required this.userId,
    required this.child,
    super.key,
  });

  final String userId;
  final Widget child;

  @override
  ConsumerState<SessionLifecycle> createState() => _SessionLifecycleState();
}

class _SessionLifecycleState extends ConsumerState<SessionLifecycle> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void didUpdateWidget(covariant SessionLifecycle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) _start();
  }

  void _start() {
    if (!mounted) return;
    ref.read(sessionStarterProvider)(widget.userId);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
