import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jaiva/ui/screens/home_screen.dart'; // Or your Main Home Nav

class ProfileSyncScreen extends StatefulWidget {
  const ProfileSyncScreen({super.key});

  @override
  State<ProfileSyncScreen> createState() => _ProfileSyncScreenState();
}

class _ProfileSyncScreenState extends State<ProfileSyncScreen> {
  bool _isLoading = false;
  final _supabase = Supabase.instance.client;

  Future<void> _syncProfile() async {
    setState(() => _isLoading = true);

    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception("No user logged in.");

      // 1. Ghost Sync: Copy the email from the Auth Vault to the public Profiles table
      await _supabase.from('profiles').upsert({
        'id': user.id,
        'email': user.email,
      });

      // 2. Route them to the main app! Their Hive data is completely untouched.
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomeScreen()), // Update to your main screen
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Grab the email they already signed up with
    final userEmail = _supabase.auth.currentUser?.email ?? "your email";

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.security, size: 80, color: Color(0xFF00E676)),
              const SizedBox(height: 32),
              Text(
                "JAIVA V5 IS HERE",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const SizedBox(height: 16),
              Text(
                "We've unlocked Cloud Drops. To secure your local playlists and connect with friends, we need to sync your vault to the cloud.",
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              
              // Show them the email we are syncing
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, color: Colors.white54),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        userEmail,
                        style: GoogleFonts.outfit(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                    ),
                    const Icon(Icons.check_circle, color: Color(0xFF00E676)),
                  ],
                ),
              ),
              
              const SizedBox(height: 48),
              
              _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
                : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E676),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _syncProfile,
                    child: Text("SECURE MY VAULT", style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}