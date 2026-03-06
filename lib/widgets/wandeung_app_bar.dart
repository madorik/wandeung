import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class WandeungAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;
  final bool showBackButton;
  final List<Widget>? extraActions;

  const WandeungAppBar({
    super.key,
    this.title,
    this.showBackButton = false,
    this.extraActions,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final user = ref.watch(authProvider).valueOrNull;
    final photoUrl = user?.userMetadata?['picture'] as String?;

    return AppBar(
      leading: showBackButton ? const BackButton() : null,
      automaticallyImplyLeading: showBackButton,
      titleSpacing: showBackButton ? 0 : 20,
      title: title != null
          ? Text(
              title!,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        colorScheme.primary,
                        colorScheme.primary.withOpacity(0.8),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.primary.withOpacity(0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.terrain_rounded,
                    size: 18,
                    color: colorScheme.onPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '완등',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: colorScheme.primary,
                    letterSpacing: -1.5,
                  ),
                ),
              ],
            ),
      centerTitle: false,
      actions: [
        if (extraActions != null) ...extraActions!,
        PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'logout') {
              ref.read(authProvider.notifier).signOut();
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem<String>(
              value: 'logout',
              child: Text('로그아웃'),
            ),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  photoUrl != null ? NetworkImage(photoUrl) : null,
              child: photoUrl == null
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
