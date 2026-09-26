import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

/// The account and the short settings directory share one scrollable box.
class SettingMenu extends StatelessWidget {
  const SettingMenu({super.key, required this.account, required this.items});

  final Widget account;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final inset = math.max(0.0, (constraints.maxWidth - 720) / 2);
      return SingleChildScrollView(
        key: const PageStorageKey<String>('setting_tab'),
        physics: const AlwaysScrollableScrollPhysics(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(inset + 20, 24, inset + 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                account,
                CupertinoListSection.insetGrouped(
                  margin: const EdgeInsets.only(top: 24),
                  hasLeading: true,
                  children: items,
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
