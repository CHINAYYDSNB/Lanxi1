import 'package:flutter/material.dart';

/// Reusable Material card with an optional icon + title header.
///
/// Borrows the *layout* of Mono-Dash's InfoPanel (rounded panel + header row
/// with an icon and title), but implemented with Material Design — never
/// Cupertino. Used across overview / files / tools / connection pages so every
/// surface shares one card shape.
class AppCard extends StatelessWidget {
  final IconData? icon;
  final String? title;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  const AppCard({
    super.key,
    this.icon,
    this.title,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 14,
  });

  bool get _hasHeader =>
      icon != null || (title != null && title!.isNotEmpty) || trailing != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_hasHeader) ...[
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                  ],
                  if (title != null && title!.isNotEmpty)
                    Expanded(
                      child: Text(
                        title!,
                        style: theme.textTheme.titleMedium,
                      ),
                    ),
                  if (trailing != null) trailing!,
                ],
              ),
              const Divider(),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
