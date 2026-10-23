import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:record/record.dart';

class MLAudioService {
  Interpreter? _interpreter;
  final AudioRecorder _audioRecorder = AudioRecorder();
  StreamSubscription? _audioSubscription;

  List<String> _labels = [];
  bool isMonitoring = false;

  // NEW: The "Audio Bucket" to collect the tiny microphone pieces
  List<double> _audioBuffer = [];

  // Callback to update UI with detected sound
  Function(String event, double score)? onDetection;

  // Target classes we care about for emergencies
  final List<String> targetClasses = ['Screaming', 'Yell', 'Siren', 'Glass', 'Alarm'];

  Future<void> initModel() async {
    // Prevent the Windows test runner from crashing looking for an Android ML file
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    // Load local YAMNet model
    _interpreter = await Interpreter.fromAsset('assets/models/yamnet.tflite');

    // Load labels
    final labelData = await rootBundle.loadString('assets/models/yamnet_classes.txt');
    _labels = labelData.split('\n').map((e) {
      var parts = e.split(',');
      return parts.length > 2 ? parts[2].trim() : '';
    }).toList();
  }

  Future<void> startMonitoring() async {
    if (await _audioRecorder.hasPermission()) {
      isMonitoring = true;
      _audioBuffer.clear(); // Empty the bucket when we start

      // YAMNet requires 16kHz, mono audio
      const recordConfig = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );

      final stream = await _audioRecorder.startStream(recordConfig);

      _audioSubscription = stream.listen((Uint8List data) {
        _processAudioChunk(data);
      });
    }
  }

  void _processAudioChunk(Uint8List rawAudio) {
    if (_interpreter == null) return;

    // 1. BULLETPROOF AUDIO CONVERSION (Fixes the "Environmental Noise" loop)
    ByteData byteData = ByteData.sublistView(rawAudio);
    List<double> floatAudio = [];
    double maxAmp = 0.0; // Track the volume for debugging

    // Read 2 bytes at a time (16-bit PCM, Little Endian)
    for (int i = 0; i < byteData.lengthInBytes; i += 2) {
      int sample = byteData.getInt16(i, Endian.little);
      double floatSample = sample / 32768.0; // Normalize to [-1.0 to 1.0]
      floatAudio.add(floatSample);

      if (floatSample.abs() > maxAmp) maxAmp = floatSample.abs();
    }

    // Print the volume level to the terminal to prove the mic isn't muted
    if (maxAmp > 0.05) {
      print("🔊 Mic picked up volume peak: ${(maxAmp * 100).toStringAsFixed(1)}%");
    }

    // 2. Pour the properly formatted audio into our bucket
    _audioBuffer.addAll(floatAudio);

    // 3. Once the bucket is full (15,600 samples = ~0.975 seconds)
    if (_audioBuffer.length >= 15600) {

      // Scoop out exactly 15,600 samples for the model
      var input = [_audioBuffer.sublist(0, 15600)];
      var output = List.filled(1 * 521, 0.0).reshape([1, 521]);

      // Run local inference
      _interpreter!.run(input, output);

      _analyzeResults(output[0] as List<double>);

      // Leave any leftover audio for the next round to prevent skipping
      _audioBuffer.removeRange(0, 15600);
    }
  }

  void _analyzeResults(List<double> scores) {
    double maxScore = 0;
    int maxIndex = -1;

    for (int i = 0; i < scores.length; i++) {
      if (scores[i] > maxScore) {
        maxScore = scores[i];
        maxIndex = i;
      }
    }

    if (maxIndex != -1 && maxScore > 0.4) { // 40% confidence threshold
      String detected = _labels[maxIndex];

      // ADD THIS LINE to see everything the microphone hears in your terminal:
      print("Model heard: $detected with score $maxScore");

      // Check if it's a dangerous sound
      bool isEmergency = targetClasses.any((t) => detected.contains(t));

      if (isEmergency && onDetection != null) {
        onDetection!(detected, maxScore);
      }
    }
  }

  Future<void> stopMonitoring() async {
    isMonitoring = false;
    await _audioSubscription?.cancel();
    await _audioRecorder.stop();
    _audioBuffer.clear(); // Empty the bucket
  }
}