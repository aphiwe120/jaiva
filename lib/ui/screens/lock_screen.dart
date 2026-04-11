import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  // 📱 Helper function to get the unique hardware ID of the phone
  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'unknown_ios';
    } else if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id; // Unique ID for this specific Android device
    }
    return 'unknown_device';
  }

  // 🔐 The core locking logic
  Future<void> _verifyCode() async {
    final inputCode = _codeController.text.trim().toUpperCase();

    if (inputCode.isEmpty) {
      setState(() => _errorMessage = "Please enter a VIP code.");
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final supabase = Supabase.instance.client;
      final deviceId = await _getDeviceId();

      // 1. Check if the code exists in our database
      final response = await supabase
          .from('access_codes')
          .select()
          .eq('code', inputCode)
          .maybeSingle(); // Returns null if no code is found

      if (response == null) {
        setState(() => _errorMessage = "Invalid VIP code.");
        return;
      }

      final isActive = response['is_active'] as bool;
      final registeredDeviceId = response['device_id'] as String?;

      // 2. Is the code deactivated by Sizwe?
      if (!isActive) {
        setState(() => _errorMessage = "This code has been revoked.");
        return;
      }

      // 3. Scenario A: Brand new code, nobody has claimed it yet
      if (registeredDeviceId == null) {
        // Claim the code for this phone!
        await supabase
            .from('access_codes')
            .update({'device_id': deviceId})
            .eq('code', inputCode);
        
        _grantAccess(inputCode);
      } 
      // 4. Scenario B: The code is claimed, but is it THIS phone?
      else if (registeredDeviceId == deviceId) {
        _grantAccess(inputCode); // Welcome back!
      } 
      // 5. Scenario C: The code belongs to someone else! (The Cousin)
      else {
        setState(() => _errorMessage = "Code is already in use on another device.");
      }

    } catch (e) {
      setState(() => _errorMessage = "Network error. Please check your connection.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🎉 Success! Let them in.
  Future<void> _grantAccess(String code) async {
    // Save the code so they don't have to type it tomorrow
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vip_code', code);

    if (mounted) {
      // Destroy the lock screen and push the home screen so they can't hit "Back"
      Navigator.pushReplacementNamed(context, '/home'); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cool logo placeholder
              const Icon(Icons.music_note, size: 80, color: Colors.deepPurpleAccent),
              const SizedBox(height: 24),
              const Text(
                "JAIVA VIP",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
              const SizedBox(height: 8),
              const Text(
                "Enter your exclusive access code to continue.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 16),
              ),
              const SizedBox(height: 48),

              // The Text Field
              TextField(
                controller: _codeController,
                style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 2),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: "e.g. JAIVA-VIP-001",
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Error Message Text
              if (_errorMessage.isNotEmpty)
                Text(
                  _errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              const SizedBox(height: 24),

              // The Verify Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1DB954), // Spotify Green
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _isLoading ? null : _verifyCode,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("UNLOCK", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}