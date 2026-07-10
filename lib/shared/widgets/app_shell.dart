import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../features/learn/path/path_provider.dart';

const _brandLogoAsset = 'assets/branding/otic-studio-logo.png';

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  static final mobileScaffoldKey = GlobalKey<ScaffoldState>();

  static const _destinations = [
    _NavDest('Home', Icons.home_outlined, Icons.home, '/'),
    _NavDest('Learn', Icons.menu_book_outlined, Icons.menu_book, '/learn'),
    _NavDest('Practice', Icons.edit_outlined, Icons.edit, '/practice'),
    _NavDest('Create', Icons.lightbulb_outlined, Icons.lightbulb, '/create'),
    _NavDest('Projects', Icons.folder_outlined, Icons.folder, '/projects'),
    _NavDest('Web Dev Lab', Icons.code_outlined, Icons.code, '/weblab'),
    _NavDest('Python Lab', Icons.terminal_outlined, Icons.terminal, '/pythonlab'),
    _NavDest('App Dev Lab', Icons.phone_android_outlined, Icons.phone_android, '/applab'),
    _NavDest('AI Chat', Icons.chat_outlined, Icons.chat, '/chat'),
    _NavDest(
      'Achievements',
      Icons.emoji_events_outlined,
      Icons.emoji_events,
      '/achievements',
    ),
    _NavDest(
      'Certificates',
      Icons.workspace_premium_outlined,
      Icons.workspace_premium,
      '/certificates',
    ),
    _NavDest('Settings', Icons.settings_outlined, Icons.settings, '/settings'),
  ];

  // Bottom nav shows first 5 destinations; rest accessible via drawer
  static const _mobileIndices = [0, 1, 2, 3, 4];

  int _selectedIndex(BuildContext context) {
    final path = GoRouterState.of(context).uri.path;
    final i = _destinations.indexWhere((d) => d.path == path);
    return i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = _selectedIndex(context);
    final isWide = MediaQuery.sizeOf(context).width >= 640;

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            _SideNav(selectedIndex: selectedIndex, destinations: _destinations),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: child),
          ],
        ),
      );
    }

    final mobileSelected = _mobileIndices.contains(selectedIndex)
        ? _mobileIndices.indexOf(selectedIndex)
        : 0;

    return Scaffold(
      key: mobileScaffoldKey,
      body: Stack(
        children: [
          child,
          Positioned(
            top: MediaQuery.of(context).padding.top + 4,
            right: 4,
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const Icon(Icons.menu, size: 22),
                  tooltip: 'Menu',
                  onPressed: () => mobileScaffoldKey.currentState?.openDrawer(),
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      drawer: _AppDrawer(
        selectedIndex: selectedIndex,
        destinations: _destinations,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
        ),
        child: NavigationBar(
          selectedIndex: mobileSelected,
          onDestinationSelected: (i) =>
              context.go(_destinations[_mobileIndices[i]].path),
          destinations: _mobileIndices
              .map(
                (i) => NavigationDestination(
                  icon: Icon(_destinations[i].icon),
                  selectedIcon: Icon(_destinations[i].selectedIcon),
                  label: _destinations[i].label,
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  const _SideNav({required this.selectedIndex, required this.destinations});

  final int selectedIndex;
  final List<_NavDest> destinations;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Column(
        children: [
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _BrandLogo(size: 44),
            ),
          ),
          const SizedBox(height: 20),
          const Divider(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: destinations.length,
              itemBuilder: (context, i) {
                final dest = destinations[i];
                final selected = selectedIndex == i;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: ListTile(
                    dense: true,
                    selected: selected,
                    selectedTileColor: AppColors.primary.withValues(
                      alpha: 0.08,
                    ),
                    leading: Icon(
                      selected ? dest.selectedIcon : dest.icon,
                      color: selected
                          ? AppColors.primary
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      size: 20,
                    ),
                    title: Text(
                      dest.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: selected
                            ? AppColors.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onTap: () => context.go(dest.path),
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.teachColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Offline · v1.1',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.selectedIndex, required this.destinations});

  final int selectedIndex;
  final List<_NavDest> destinations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pathsAsync = ref.watch(studentPathsProvider);

    return NavigationDrawer(
      selectedIndex: selectedIndex,
      onDestinationSelected: (i) {
        context.go(destinations[i].path);
        Navigator.pop(context);
      },
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 28, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_BrandLogo(size: 48)],
          ),
        ),
        const Divider(indent: 16, endIndent: 16),
        // My Paths section
        pathsAsync.when(
          data: (rows) {
            if (rows.isEmpty) return const SizedBox.shrink();
            final paths = rows.map(parsedFromRow).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    'MY PATHS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ),
                ...paths.take(5).map((p) => ListTile(
                      dense: true,
                      leading: const Icon(Icons.route, size: 18, color: AppColors.learnColor),
                      title: Text(
                        p.topic,
                        style: const TextStyle(fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${p.completedLessons}/${p.totalLessons} lessons',
                        style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor),
                      ),
                      trailing: Text(
                        '${(p.progressFraction * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.learnColor,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/path/${Uri.encodeComponent(p.topic)}');
                      },
                    )),
                const Divider(indent: 16, endIndent: 16),
              ],
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
        ...destinations.map(
          (d) => NavigationDrawerDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon),
            label: Text(d.label),
          ),
        ),
      ],
    );
  }
}

class _NavDest {
  const _NavDest(this.label, this.icon, this.selectedIcon, this.path);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String path;
}

class _BrandLogo extends StatelessWidget {
  const _BrandLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      _brandLogoAsset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      semanticLabel: 'Logo',
    );
  }
}
