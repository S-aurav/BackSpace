import 'dart:developer';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../api/apis.dart';
import '../../helper/dialogs.dart';
import '../../helper/theme_controller.dart';
import '../../main.dart';
import '../../widgets/adaptive_blur.dart';
import '../home_screen.dart';

// Authentic iOS iMessage-styled Welcome & Sign In Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  bool _isLoading = false;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '760012649488-6tjoq9sbhbh76698hlmbejtdsq81b02c.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  // Handles Google sign-in flow
  Future<void> _handleGoogleBtnClick() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final user = await _signInWithGoogle();
      if (user != null && mounted) {
        log('Signed in user: ${user.user?.uid}');
        if (await APIs.userExists()) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          await APIs.createUser();
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const HomeScreen()),
            );
          }
        }
      }
    } catch (e) {
      log('Sign-in error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<UserCredential?> _signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final googleProvider = GoogleAuthProvider();
        return await APIs.auth.signInWithPopup(googleProvider);
      }

      final result = await InternetAddress.lookup('google.com');
      if (result.isEmpty) {
        throw Exception('No internet response from google.com');
      }

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw Exception('Google auth tokens were not returned');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await APIs.auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      log('_signInWithGoogle FirebaseAuthException: ${e.code} - ${e.message}');
      if (mounted) {
        String msg = 'Google sign-in failed. Please try again.';
        if (e.code == 'unauthorized-domain') {
          msg = 'Domain not authorized! Add your custom domain to Firebase Console > Authentication > Settings > Authorized domains.';
        } else if (e.code == 'popup-closed-by-user') {
          msg = 'Sign-in window was closed.';
        } else if (e.message != null && e.message!.isNotEmpty) {
          msg = e.message!;
        }
        Dialogs.showSnackbar(context, msg);
      }
      return null;
    } catch (e, stackTrace) {
      log('_signInWithGoogle error: $e\n$stackTrace');
      if (mounted) {
        Dialogs.showSnackbar(context, 'Google sign-in failed. Please try again.');
      }
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    mq = MediaQuery.of(context).size;

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, child) {
        final isDark = mode == ThemeMode.dark;

        return Scaffold(
          backgroundColor: ThemeController.bgColor,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28.0),
                  child: Column(
                    children: [
                      const Spacer(flex: 3),

                      // Large App Icon with squircle corners & ambient glow
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(32),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007AFF).withValues(alpha: isDark ? 0.35 : 0.2),
                              blurRadius: 36,
                              offset: const Offset(0, 14),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(32),
                          child: Image.asset(
                            'images/icon.png',
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // App Name
                      RichText(
                        text: TextSpan(
                          children: [
                            TextSpan(
                              text: 'Back',
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                                color: ThemeController.textColor,
                              ),
                            ),
                            const TextSpan(
                              text: 'Space',
                              style: TextStyle(
                                fontSize: 38,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.0,
                                color: Color(0xFF007AFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Subtitle
                      Text(
                        'Simple. Private. High Quality.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                          color: ThemeController.subtextColor,
                        ),
                      ),

                      const Spacer(flex: 4),

                      // Frosted Glass "Sign in with Google" Pill Button
                      AdaptiveBlur(
                        borderRadius: BorderRadius.circular(28),
                        sigmaX: 25,
                        sigmaY: 25,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _isLoading ? null : _handleGoogleBtnClick,
                            borderRadius: BorderRadius.circular(28),
                            child: Container(
                              width: double.infinity,
                              height: 56,
                              decoration: BoxDecoration(
                                color: ThemeController.cardColor.withValues(alpha: ThemeController.cardAlpha),
                                borderRadius: BorderRadius.circular(28),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.15)
                                      : Colors.black.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: _isLoading
                                  ? const Center(
                                      child: SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF007AFF)),
                                        ),
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Image.asset(
                                          'images/google.png',
                                          height: 22,
                                          width: 22,
                                        ),
                                        const SizedBox(width: 12),
                                        Text(
                                          'Sign in with Google',
                                          style: TextStyle(
                                            color: ThemeController.textColor,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: -0.2,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}