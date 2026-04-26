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
    final topPadding = MediaQuery.of(context).padding.top;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF5F5F5), // ini biar ada putih di atas
      padding: EdgeInsets.only(top: topPadding),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
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
            bottom: Radius.circular(24),
          ),
          child: Stack(
            children: [
              // 🔥 BALIKIN BACKGROUND KOPI
              Positioned.fill(
                child: Opacity(
                  opacity: 0.04,
                  child: Image.asset(
                    'assets/images/background.png', // pastikan ini ada
                    fit: BoxFit.cover,
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (leading != null) ...[
                      leading!,
                      const SizedBox(height: 8),
                    ],

                    title ??
                        Image.asset(
                          'assets/images/logo.png',
                          width: 145,
                          fit: BoxFit.contain,
                        ),

                    const SizedBox(height: 8),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (child != null) ...[
                      const SizedBox(height: 18),
                      child!,
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}