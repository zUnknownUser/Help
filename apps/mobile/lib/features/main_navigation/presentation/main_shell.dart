import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../chat/presentation/pages/chat_list_page.dart';
import '../../chat/presentation/providers/chat_providers.dart';
import '../../profile/presentation/pages/account_page.dart';
import '../../service_requests/presentation/pages/service_requests_page.dart';
import '../../help_now/presentation/pages/help_now_tracking_page.dart';
import '../../help_now/presentation/providers/help_now_providers.dart';
import '../../help_now/presentation/widgets/help_now_active_banner.dart';
import 'main_tab.dart';
import 'main_shell_controller.dart';
import 'widgets/main_tab_bar.dart';

typedef MainHomeBuilder = Widget Function(ValueChanged<MainTab> onTabSelected);

class MainShell extends ConsumerStatefulWidget {
  const MainShell({
    required this.homeBuilder,
    this.requestsPage,
    this.conversationsPage,
    this.accountPage,
    this.controller,
    this.showCustomerHelpNow = false,
    super.key,
  });

  final MainHomeBuilder homeBuilder;
  final Widget? requestsPage;
  final Widget? conversationsPage;
  final Widget? accountPage;
  final MainShellController? controller;
  final bool showCustomerHelpNow;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late final PageController _pages;
  late MainShellController _controller;
  late bool _ownsController;
  MainTab _selected = MainTab.home;

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    _pages = PageController(initialPage: _selected.index);
  }

  @override
  void didUpdateWidget(covariant MainShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    _controller.removeListener(_onExternalSelection);
    if (_ownsController) _controller.dispose();
    _attachController(widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onExternalSelection());
  }

  void _attachController(MainShellController? controller) {
    _ownsController = controller == null;
    _controller = controller ?? MainShellController();
    _selected = _controller.selected;
    _controller.addListener(_onExternalSelection);
  }

  @override
  void dispose() {
    _controller.removeListener(_onExternalSelection);
    if (_ownsController) _controller.dispose();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadChatCountProvider).value ?? 0;
    final activeHelpNow = widget.showCustomerHelpNow
        ? ref.watch(customerHelpNowControllerProvider).value
        : null;
    return PopScope(
      canPop: _selected == MainTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selected != MainTab.home) _select(MainTab.home);
      },
      child: Scaffold(
        body: PageView(
          controller: _pages,
          onPageChanged: (index) {
            final tab = MainTab.values[index];
            _controller.synchronize(tab);
            setState(() => _selected = tab);
          },
          children: [
            _KeepAlivePage(
              key: const PageStorageKey('main_home'),
              child: widget.homeBuilder(_select),
            ),
            _KeepAlivePage(
              key: const PageStorageKey('main_requests'),
              child: widget.requestsPage ?? const ServiceRequestsPage(),
            ),
            _KeepAlivePage(
              key: const PageStorageKey('main_conversations'),
              child: widget.conversationsPage ?? const ChatListPage(),
            ),
            _KeepAlivePage(
              key: const PageStorageKey('main_account'),
              child: widget.accountPage ?? AccountPage(onTabSelected: _select),
            ),
          ],
        ),
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (activeHelpNow != null && activeHelpNow.active)
              HelpNowActiveBanner(
                request: activeHelpNow,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => const HelpNowTrackingPage(),
                  ),
                ),
              ),
            MainTabBar(
              selected: _selected,
              chatUnreadCount: unread,
              onSelected: _select,
            ),
          ],
        ),
      ),
    );
  }

  void _select(MainTab tab) {
    if (tab == _selected || !_pages.hasClients) return;
    _controller.synchronize(tab);
    _pages.animateToPage(
      tab.index,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _onExternalSelection() {
    if (!_pages.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _select(_controller.selected);
      });
      return;
    }
    _select(_controller.selected);
  }
}

class _KeepAlivePage extends StatefulWidget {
  const _KeepAlivePage({required this.child, super.key});

  final Widget child;

  @override
  State<_KeepAlivePage> createState() => _KeepAlivePageState();
}

class _KeepAlivePageState extends State<_KeepAlivePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
