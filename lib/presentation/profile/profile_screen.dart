import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_page.dart';
import '../widgets/header.dart';
import '../../utils/dialog_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? profileData;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        setState(() => isLoading = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      setState(() {
        profileData = profile;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  Future<void> logout() async {
    await supabase.auth.signOut();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  String get todayText {
    final now = DateTime.now();

    const days = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];

    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    return '${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}';
  }

  String formatRole(String? role) {
    if (role == null || role.isEmpty) return '-';

    switch (role.toLowerCase()) {
      case 'owner':
        return 'Owner';
      case 'rider':
        return 'Rider';
      default:
        return role;
    }
  }

  String _getPhotoUrl() {
    final directPhoto = profileData?['photo_url']?.toString();
    final avatarPhoto = profileData?['avatar_url']?.toString();
    final imagePhoto = profileData?['image_url']?.toString();

    if (directPhoto != null && directPhoto.isNotEmpty) return directPhoto;
    if (avatarPhoto != null && avatarPhoto.isNotEmpty) return avatarPhoto;
    if (imagePhoto != null && imagePhoto.isNotEmpty) return imagePhoto;

    return '';
  }

  String _getInitials(String name, String email) {
    final cleanName = name.trim();
    if (cleanName.isNotEmpty && cleanName != 'AD.A Coffee User') {
      final parts = cleanName.split(RegExp(r'\s+'));
      if (parts.length == 1) {
        return parts.first.substring(0, parts.first.length >= 2 ? 2 : 1).toUpperCase();
      }
      return (parts.first.characters.first + parts.last.characters.first).toUpperCase();
    }

    final safeEmail = email.trim();
    if (safeEmail.isNotEmpty && safeEmail != '-') {
      return safeEmail.substring(0, safeEmail.length >= 2 ? 2 : 1).toUpperCase();
    }

    return 'U';
  }

  Color _getAvatarColor(String seed) {
    const colors = [
      Color(0xFFE3F2FD),
      Color(0xFFF3E5F5),
      Color(0xFFE8F5E9),
      Color(0xFFFFF3E0),
      Color(0xFFFFEBEE),
      Color(0xFFE0F7FA),
      Color(0xFFF1F8E9),
    ];

    final hash = seed.runes.fold<int>(0, (prev, element) => prev + element);
    return colors[hash % colors.length];
  }

  Widget _buildProfileAvatar({
    required String name,
    required String email,
  }) {
    final photoUrl = _getPhotoUrl();

    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 42,
        backgroundColor: const Color(0xFFFFF0E3),
        backgroundImage: NetworkImage(photoUrl),
      );
    }

    final initials = _getInitials(name, email);
    final seed = '${name}_$email';
    final bgColor = _getAvatarColor(seed);

    return CircleAvatar(
      radius: 42,
      backgroundColor: bgColor,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? "-";
    final name = profileData?['name']?.toString() ?? 'AD.A Coffee User';
    final role = formatRole(profileData?['role']?.toString());

    return Scaffold(
      backgroundColor: const Color(0xFFF8F5F2),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  AppHeader(
                    title: const Text(
                      "Profile",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: todayText,
                  ),
                  Transform.translate(
                    offset: const Offset(0, -12),
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildProfileAvatar(
                            name: name,
                            email: email,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            name,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            email,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.orange.withAlpha(18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              role,
                              style: const TextStyle(
                                color: Colors.orange,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _infoTile(
                            icon: Icons.verified_user_outlined,
                            title: "Status",
                            value: "Authenticated User",
                          ),
                          const SizedBox(height: 12),
                          _infoTile(
                            icon: Icons.badge_outlined,
                            title: "Role",
                            value: role,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final ok = await DialogHelper.confirm(
                                  context,
                                  title: "Logout",
                                  message: "Yakin anda ingin keluar?",
                                );
                                if (!ok) return;
                                await logout();
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text("Logout"),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 15),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.orange.withAlpha(20),
            child: Icon(
              icon,
              color: Colors.orange,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}