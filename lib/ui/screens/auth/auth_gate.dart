import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_screen.dart';
import 'package:jaiva/ui/screens/home_screen.dart'; 
import 'package:jaiva/ui/screens/profile_sync_screen.dart'; // 👈 Import the new sync screen

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      // Listen to Supabase auth changes
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F0F),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
          );
        }

        final session = snapshot.hasData ? snapshot.data!.session : null;

        // 🚦 PATH 1: Not logged in. Show the login screen.
        if (session == null) {
          return const AuthScreen();
        }

        // 🚦 PATH 2: They are logged in. Let's check the Ghost Sync!
        return _ProfileCheckGate(userId: session.user.id);
      },
    );
  }
}
// ------------------------------------------------------------------
// 🛡️ THE REAL-TIME BOUNCER (Stateful Upgrade)
// ------------------------------------------------------------------
class _ProfileCheckGate extends StatefulWidget {
  final String userId;
  
  const _ProfileCheckGate({required this.userId});

  @override
  State<_ProfileCheckGate> createState() => _ProfileCheckGateState();
}

class _ProfileCheckGateState extends State<_ProfileCheckGate> {
  // 1. Declare the stream variable
  late final Stream<List<Map<String, dynamic>>> _profileStream;

  @override
  void initState() {
    super.initState();
    // 2. Lock the stream in exactly ONCE when the screen first loads.
    // This stops Flutter from accidentally disconnecting and reconnecting!
    _profileStream = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      // 3. Listen to the locked-in stream variable
      stream: _profileStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0F0F0F),
            body: Center(child: CircularProgressIndicator(color: Color(0xFF00E676))),
          );
        }

        final profiles = snapshot.data;

        // If they don't exist in the database yet -> Ghost Sync
        if (profiles == null || profiles.isEmpty) {
          return const ProfileSyncScreen(); 
        }

        final profile = profiles.first;

        // 🚨 THE INSTANT BAN HAMMER TRAP
        if (profile['is_banned'] == true) {
          return Scaffold(
            backgroundColor: const Color(0xFF0A0A0A),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 80),
                  const SizedBox(height: 24),
                  const Text(
                    "ACCOUNT SUSPENDED",
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 24, 
                      fontWeight: FontWeight.bold, 
                      letterSpacing: 2
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "You have been banned from the Kinetic Vault.",
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                  const SizedBox(height: 48),
                  
                  // The Escape Hatch
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white54,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    onPressed: () {
                      Supabase.instance.client.auth.signOut();
                    },
                    child: const Text("Log Out"),
                  )
                ],
              ),
            ),
          );
        }

        // They exist and are clean! Welcome to the Vault.
        return const HomeScreen(); 
      },
    );
  }
}