import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final Widget? title;
  final String subtitle;
  final Widget? child;
  final Widget? leading;

  const AppHeader({
    super.key,
    this.title,
    required this.subtitle,
    this.child,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFF8A2A),
            Color(0xFFFFB15C),
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(28),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Opacity(
                opacity: 0.035,
                child: Image.asset(
                  'assets/images/background.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (leading != null) ...[
                    leading!,
                    const SizedBox(height: 4),
                  ],
                  Image.asset(
                    'assets/images/logo.png',
                    width: 130,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 8),
                  if (title != null) ...[
                    DefaultTextStyle(
                      style: const TextStyle(color: Colors.white),
                      child: title!,
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (child != null) ...[
                    const SizedBox(height: 16),
                    child!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}