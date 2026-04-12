import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class EQMixer extends StatelessWidget {
  final AndroidEqualizer equalizer;

  const EQMixer({Key? key, required this.equalizer}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 450,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFF121212), // Deep premium dark mode
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const Text(
            'HEAVY BASS MIXER 🎛️',
            style: TextStyle(
              color: Colors.white, 
              fontSize: 22, 
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 10),
          
          // 🚨 THE MASTER SWITCH
          StreamBuilder<bool>(
            stream: equalizer.enabledStream,
            builder: (context, snapshot) {
              final isEnabled = snapshot.data ?? false;
              return SwitchListTile(
                title: const Text('Enable Hardware EQ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                activeColor: Colors.deepPurpleAccent,
                value: isEnabled,
                onChanged: (val) => equalizer.setEnabled(val),
              );
            },
          ),
          const Divider(color: Colors.grey),
          
          // 🚨 THE SLIDER BOARD
          Expanded(
            child: FutureBuilder<AndroidEqualizerParameters>(
              future: equalizer.parameters,
              builder: (context, snapshot) {
                // If it's still asking the hardware, show a spinner
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Colors.deepPurpleAccent));
                }
                
                final parameters = snapshot.data!;
                
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: parameters.bands.map((band) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: StreamBuilder<double>(
                            stream: band.gainStream,
                            builder: (context, snapshot) {
                              return RotatedBox(
                                quarterTurns: 3, // Turns the horizontal slider vertical!
                                child: Slider(
                                  activeColor: _getBandColor(band.centerFrequency),
                                  inactiveColor: Colors.white24,
                                  min: parameters.minDecibels,
                                  max: parameters.maxDecibels,
                                  value: band.gain,
                                  onChanged: (val) => band.setGain(val),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Shows the frequency (e.g., 60Hz, 230Hz, 14000Hz)
                        Text(
                          _formatFrequency(band.centerFrequency),
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🎨 Color codes the sliders: Red for Bass, Orange for Mids, Blue for Treble
  Color _getBandColor(double freq) {
    if (freq < 200000) return Colors.redAccent; 
    if (freq < 2000000) return Colors.orangeAccent; 
    return Colors.cyanAccent; 
  }

  // 📝 Cleans up the hardware frequency numbers so they look pretty (e.g. "60Hz" or "14k")
  String _formatFrequency(double freq) {
    final hertz = freq / 1000;
    if (hertz >= 1000) {
      return '${(hertz / 1000).toStringAsFixed(1)}k';
    } else {
      return '${hertz.round()}Hz';
    }
  }
}