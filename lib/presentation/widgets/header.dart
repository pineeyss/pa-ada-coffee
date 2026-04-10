import 'package:flutter/material.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? child;

  const AppHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFFFF9A4D),
            Color(0xFFFFB366),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(24),
        ),
      ),
      child: Stack(
        children: [
          /// LOGO BACKGROUND
          Positioned(
            right: -10,
            top: -10,
            child: Opacity(
              opacity: 0.18,
              child: Image.asset(
                'lib/assets/images/logo.png',
                width: 140,
                fit: BoxFit.contain,
              ),
            ),
          ),

          /// CONTENT
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
              if (child != null) ...[
                const SizedBox(height: 14),
                child!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}