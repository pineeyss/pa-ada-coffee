import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../widgets/app_button.dart';
import '../widgets/header.dart';
import '../../utils/dialog_helper.dart';


class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  String? nameError;
  String? emailError;
  String? passwordError;

  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  final supabase = Supabase.instance.client;

  bool isLoading = false;
  bool obscurePassword = true;
  String selectedRole = 'owner';

  bool isValidName(String name) {
    return RegExp(r'^[a-zA-Z0-9._]{2,32}$').hasMatch(name);
  }

  bool isValidPassword(String password) {
    if (password.length < 8 || password.length > 12) return false;

    final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
    final hasLower = RegExp(r'[a-z]').hasMatch(password);
    final hasNumber = RegExp(r'[0-9]').hasMatch(password);
    final hasInvalid = RegExp(r'[!@#\$%\^&\* ]').hasMatch(password);

    return hasUpper && hasLower && hasNumber && !hasInvalid;
  }

  bool isValidEmail(String email) {
    return RegExp(r'^[a-z0-9.]+@[a-z0-9]+\.[a-z]{2,}$')
        .hasMatch(email);
  }

  Future<void> register() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      nameError = null;
      emailError = null;
      passwordError = null;
    });

    // NAME
    if (name.isEmpty) {
      setState(() => nameError = "Nama wajib diisi");
      return;
    }

    if (!isValidName(name)) {
      setState(() => nameError = "Nama hanya boleh huruf, angka, . dan _");
      return;
    }

    // EMAIL
    if (email.isEmpty) {
      setState(() => emailError = "Email wajib diisi");
      return;
    }

    if (!isValidEmail(email)) {
      setState(() => emailError = "Format email tidak valid");
      return;
    }

    // PASSWORD
    if (!isValidPassword(password)) {
      setState(() {
        passwordError =
            "Password 8-12 karakter, wajib ada huruf besar, kecil, dan angka";
      });
      return;
    }

    try {
      setState(() => isLoading = true);

      final response = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user != null) {
        final existingProfile = await supabase
            .from('profiles')
            .select('id')
            .eq('id', user.id)
            .maybeSingle();

        if (existingProfile == null) {
          await supabase.from('profiles').insert({
            'id': user.id,
            'name': name,
            'email': email,
            'role': selectedRole,
          });
        }
      }

    if (!mounted) return;

    await DialogHelper.success(
      context,
      title: "Registrasi Berhasil",
      message: "Akun berhasil dibuat. Kamu akan kembali ke halaman login.",
    );

    if (!mounted) return;
    Navigator.pop(context);

  } on AuthException catch (e) {
    if (!mounted) return;

    String message = e.message.toLowerCase();

    if (message.contains('already registered')) {
      setState(() {
        emailError = "Email sudah terdaftar";
      });
    } else if (message.contains('password')) {
      setState(() {
        passwordError = "Password tidak valid";
      });
    } else if (message.contains('email')) {
      setState(() {
        emailError = "Email tidak valid";
      });
    } else {
      setState(() {
        passwordError = "Registrasi gagal";
      });
    }

  } catch (e) {
    if (!mounted) return;

    setState(() {
      passwordError = "Terjadi kesalahan";
    });
  } finally {
    if (!mounted) return;
    setState(() => isLoading = false);
  }
}

  InputDecoration inputStyle({
    required String hint,
    IconData? prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: Colors.grey.shade500,
        fontSize: 15,
      ),
      prefixIcon: prefix != null ? Icon(prefix, color: Colors.grey.shade600) : null,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F7F7),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.orange, width: 1.2),
      ),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF8F5F2),
    body: SafeArea(
      child: SingleChildScrollView(
        child: Column(
          children: [
            AppHeader(
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back,
                  color: Colors.white,
                ),
              ),
              subtitle: 'Daftarkan akun baru untuk aplikasi',
            ),
            Transform.translate(
              offset: const Offset(0, -16),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(18),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Create Account",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Buat akun baru untuk mulai menggunakan aplikasi",
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // NAME
                    TextField(
                      controller: nameController,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (nameError != null) {
                          setState(() => nameError = null);
                        }
                      },
                      decoration: inputStyle(
                        hint: "Masukkan nama",
                        prefix: Icons.person_outline,
                      ).copyWith(
                        errorText: nameError,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: nameError != null
                                ? Colors.red
                                : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: nameError != null
                                ? Colors.red
                                : Colors.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // EMAIL
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: (_) {
                        if (emailError != null) {
                          setState(() => emailError = null);
                        }
                      },
                      decoration: inputStyle(
                        hint: "Masukkan email",
                        prefix: Icons.email_outlined,
                      ).copyWith(
                        errorText: emailError,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: emailError != null
                                ? Colors.red
                                : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: emailError != null
                                ? Colors.red
                                : Colors.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // PASSWORD
                    TextField(
                      controller: passwordController,
                      obscureText: obscurePassword,
                      textInputAction: TextInputAction.done,
                      onChanged: (_) {
                        if (passwordError != null) {
                          setState(() => passwordError = null);
                        }
                      },
                      onSubmitted: (_) {
                        if (!isLoading) register();
                      },
                      decoration: inputStyle(
                        hint: "Masukkan password",
                        prefix: Icons.lock_outline,
                        suffix: IconButton(
                          onPressed: () {
                            setState(() {
                              obscurePassword = !obscurePassword;
                            });
                          },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ).copyWith(
                        errorText: passwordError,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: passwordError != null
                                ? Colors.red
                                : Colors.grey.shade200,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: passwordError != null
                                ? Colors.red
                                : Colors.orange,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ROLE
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: inputStyle(
                        hint: "Pilih role",
                        prefix: Icons.badge_outlined,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'owner',
                          child: Text('Owner'),
                        ),
                        DropdownMenuItem(
                          value: 'rider',
                          child: Text('Rider'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedRole = value);
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    AppButton(
                      text: "Register",
                      onPressed: register,
                      isLoading: isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}