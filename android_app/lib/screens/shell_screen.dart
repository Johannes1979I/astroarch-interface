import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../i18n/strings.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'dashboard_screen.dart';
import 'mount_screen.dart';
import 'capture_screen.dart';
import 'guide_screen.dart';
import 'focus_screen.dart';
import 'align_screen.dart';
import 'observatory_screen.dart';
import 'indi_panel_screen.dart';
import 'files_screen.dart';
import 'logs_screen.dart';
import 'live_view_screen.dart';
import 'activity_log_screen.dart';
import 'setup_screen.dart';
import 'settings_screen.dart';
import 'analyze_screen.dart';
import 'scheduler_screen.dart';

/// Key globale dello Scaffold di Shell, usata dalle schermate annidate
/// per aprire il drawer (Scaffold.of() trova lo Scaffold locale, non Shell).
final GlobalKey<ScaffoldState> shellScaffoldKey = GlobalKey<ScaffoldState>();

/// Helper per aprire il drawer dalla AppBar di qualsiasi schermata.
void openShellDrawer() => shellScaffoldKey.currentState?.openDrawer();

/// Shell con bottom nav (5 tab) + drawer per le altre sezioni.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key});
  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _idx = 0;

  // Bottom nav: Dash · Mount · Align · Capture · Guide
  // (Align tra Mount e Capture: workflow notturno = punta → allinea → scatta → guida)
  // Drawer aperto da icona "menu" in AppBar di ogni schermata (Builder).
  static const _bottomScreens = <Widget>[
    DashboardScreen(),
    MountScreen(),
    AlignScreen(),
    CaptureScreen(),
    GuideScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: shellScaffoldKey,
      drawer: const _AppDrawer(),
      body: _bottomScreens[_idx],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: 'Dash'.tr(context)),
          NavigationDestination(icon: const Icon(Icons.adjust_outlined),
              selectedIcon: const Icon(Icons.adjust),
              label: 'Mount'.tr(context)),
          NavigationDestination(icon: const Icon(Icons.gps_fixed_outlined),
              selectedIcon: const Icon(Icons.gps_fixed),
              label: 'Align'.tr(context)),
          NavigationDestination(icon: const Icon(Icons.camera_alt_outlined),
              selectedIcon: const Icon(Icons.camera_alt),
              label: 'Capture'.tr(context)),
          NavigationDestination(icon: const Icon(Icons.center_focus_strong_outlined),
              selectedIcon: const Icon(Icons.center_focus_strong),
              label: 'Guide'.tr(context)),
        ],
      ),
    );
  }
}

class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text.rich(
              TextSpan(children: [
                const TextSpan(text: 'Astroarch ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                TextSpan(text: 'Interface', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: T.accent(context))),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 14),
              child: Text(
                'Zarletti-Osservatorio Jupiter\n${state.host}:${state.port}',
                style: TextStyle(color: T.muted(context), fontSize: 11),
              ),
            ),
            _section(context, 'Connessione'.tr(context)),
            _statusTile(context, 'INDI', state.indiConn),
            _statusTile(context, 'PHD2', state.phd2Conn),
            _statusTile(context, 'WS state'.tr(context), state.wsStateLabel),
            _statusTile(context, 'WS frames'.tr(context), state.wsFramesLabel),
            const SizedBox(height: 8),
            _section(context, 'Moduli'.tr(context)),
            _navTile(context, Icons.dashboard, 'Dashboard'.tr(context), () => Navigator.pop(context)),
            _navTile(context, Icons.center_focus_strong, 'Live View'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LiveViewScreen()));
            }),
            _navTile(context, Icons.tune, 'Focus'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FocusScreen()));
            }),
            _navTile(context, Icons.cloud_outlined, 'Observatory'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ObservatoryScreen()));
            }),
            _navTile(context, Icons.calendar_month, 'Scheduler'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulerScreen()));
            }),
            _navTile(context, Icons.bookmarks_outlined, 'Setup / Profili'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
            }),
            _navTile(context, Icons.analytics_outlined, 'Analyze'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyzeScreen()));
            }),
            const SizedBox(height: 8),
            _section(context, 'Sistema'.tr(context)),
            _navTile(context, Icons.settings_input_component, 'INDI Panel'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const IndiPanelScreen()));
            }),
            _navTile(context, Icons.folder_outlined, 'Files'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const FilesScreen()));
            }),
            _navTile(context, Icons.terminal, 'INDI Logs'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsScreen()));
            }),
            _navTile(context, Icons.history, 'Activity Log (chiamate API)'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogScreen()));
            }),
            _navTile(context, Icons.settings, 'Impostazioni'.tr(context), () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            }),
            const Divider(),
            _navTile(context, Icons.power_settings_new, 'Disconnetti'.tr(context), () async {
              Navigator.pop(context);
              await state.disconnect();
            }, danger: true),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext c, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
        child: Text(t.toUpperCase(),
            style: TextStyle(fontSize: 10, color: T.muted(c), letterSpacing: 2, fontWeight: FontWeight.w600)),
      );

  Widget _navTile(BuildContext c, IconData i, String t, VoidCallback tap, {bool danger = false}) {
    return ListTile(
      leading: Icon(i, color: danger ? T.err(c) : T.accent(c)),
      title: Text(t, style: TextStyle(color: danger ? T.err(c) : T.text(c), fontSize: 14)),
      onTap: tap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );
  }

  Widget _statusTile(BuildContext c, String name, String state) {
    Color color;
    switch (state) {
      case 'connected':
        color = T.ok(c); break;
      case 'reconnecting':
      case 'connecting':
      case 'pinging':
        color = T.warn(c); break;
      default:
        color = T.muted(c);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(name, style: TextStyle(color: T.muted(c), fontSize: 12)),
          const Spacer(),
          Text(state, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
