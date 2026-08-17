import 'package:flutter/foundation.dart';

import 'main_tab.dart';

class MainShellController extends ChangeNotifier {
  MainTab _selected = MainTab.home;

  MainTab get selected => _selected;

  void select(MainTab tab) {
    if (_selected == tab) return;
    _selected = tab;
    notifyListeners();
  }

  void synchronize(MainTab tab) => _selected = tab;
}
