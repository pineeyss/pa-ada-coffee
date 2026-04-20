import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/dialog_helper.dart';
import '../auth/login_page.dart';
import '../widgets/header.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final SupabaseClient supabase = Supabase.instance.client;

  Map<String, dynamic>? profileData;
  bool isLoading = true;
  bool isUploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    try {
      final user = supabase.auth.currentUser;

      if (user == null) {
        if (!mounted) return;
        setState(() => isLoading = false);
        return;
      }

      final profile = await supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;

      setState(() {
        profileData = profile;
        isLoading = false;
      });

      debugPrint('PROFILE DATA: $profile');
    } catch (e) {
      debugPrint('LOAD PROFILE ERROR: $e');

      if (!mounted) return;
      setState(() => isLoading = false);
    }
  }

  Future<void> pickAndUploadImage() async {
    if (isUploadingPhoto) return;

    try {
      final picker = ImagePicker();

      final image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (image == null) return;

      final user = supabase.auth.currentUser;
      if (user == null) return;

      setState(() => isUploadingPhoto = true);

      final bytes = await image.readAsBytes();
      final ext = _getSafeExtension(image.name);

      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final filePath = '${user.id}/$fileName';

      debugPrint('UPLOAD FILE PATH: $filePath');

      await supabase.storage.from('avatars').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(
              upsert: true,
              contentType: _getContentType(ext),
            ),
          );

      final publicUrl = supabase.storage.from('avatars').getPublicUrl(filePath);
      final finalPhotoUrl =
          '$publicUrl?v=${DateTime.now().millisecondsSinceEpoch}';

      debugPrint('FINAL PHOTO URL: $finalPhotoUrl');

      await supabase.from('profiles').update({
        'photo_url': finalPhotoUrl,
      }).eq('id', user.id);

      if (!mounted) return;

      setState(() {
        profileData = {
          ...?profileData,
          'photo_url': finalPhotoUrl,
        };
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Foto profil berhasil diperbarui'),
        ),
      );
    } catch (e) {
      debugPrint('UPLOAD ERROR: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal upload foto: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isUploadingPhoto = false);
      }
    }
  }

  String _getSafeExtension(String fileName) {
    final lower = fileName.toLowerCase();

    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.jpeg')) return 'jpeg';
    if (lower.endsWith('.jpg')) return 'jpg';
    if (lower.endsWith('.webp')) return 'webp';

    return 'jpg';
  }

  String _getContentType(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'jpeg':
        return 'image/jpeg';
      case 'jpg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }

  String _getPhotoUrl() {
    final photoUrl = profileData?['photo_url']?.toString().trim() ?? '';

    debugPrint('PHOTO URL FROM DB: $photoUrl');

    return photoUrl;
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

  Widget _buildAvatarImage() {
    final imageUrl = _getPhotoUrl();

    if (imageUrl.isEmpty) {
      return Container(
        width: 84,
        height: 84,
        decoration: const BoxDecoration(
          color: Color(0xFFFFF0E3),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: const Icon(
          Icons.person,
          size: 40,
          color: Colors.brown,
        ),
      );
    }

    return ClipOval(
      child: Image.network(
        imageUrl,
        key: ValueKey(imageUrl),
        width: 84,
        height: 84,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('IMAGE LOAD ERROR: $error');
          debugPrint('FAILED IMAGE URL: $imageUrl');

          return Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0E3),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.brown,
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileAvatar() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: pickAndUploadImage,
          child: Container(
            width: 92,
            height: 92,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFF0E3),
              border: Border.all(
                color: Colors.orange.withOpacity(0.25),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                _buildAvatarImage(),
                if (isUploadingPhoto)
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.6,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: pickAndUploadImage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = supabase.auth.currentUser;
    final email = user?.email ?? '-';
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
                      'Profile',
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
                          _buildProfileAvatar(),
                          const SizedBox(height: 14),
                          const Text(
                            'Tap foto untuk mengganti',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 10),
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
                              color: Colors.orange.withOpacity(0.08),
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
                            title: 'Status',
                            value: 'Authenticated User',
                          ),
                          const SizedBox(height: 12),
                          _infoTile(
                            icon: Icons.badge_outlined,
                            title: 'Role',
                            value: role,
                          ),
                          const SizedBox(height: 28),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                final ok = await DialogHelper.confirm(
                                  context,
                                  title: 'Logout',
                                  message: 'Yakin anda ingin keluar?',
                                );
                                if (!ok) return;
                                await logout();
                              },
                              icon: const Icon(Icons.logout),
                              label: const Text('Logout'),
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
            backgroundColor: Colors.orange.withOpacity(0.20),
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