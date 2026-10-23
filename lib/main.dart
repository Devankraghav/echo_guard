import 'dart:async';
import 'package:flutter/material.dart';
import 'services/ml_audio_service.dart';
import 'services/alert_service.dart';
import 'services/database_helper.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const EchoGuardApp());
}

class EchoGuardApp extends StatelessWidget {
  const EchoGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'EchoGuard',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF090D16),
        primaryColor: const Color(0xFF00F0FF),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00F0FF),
          secondary: Color(0xFFFF2A55),
          surface: Color(0xFF121826),
          onSurface: Color(0xFFF1F5F9),
          surfaceContainerHighest: Color(0xFF1E293B),
        ),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final MLAudioService _audioService = MLAudioService();
  String _latestEvent = "None";
  double _latestScore = 0.0;
  bool _isAlerting = false;
  int _countdown = 15;
  Timer? _alertTimer;

  String _emergencyContact = "";
  final TextEditingController _contactController = TextEditingController();

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _loadContact();
    _audioService.initModel();
    _audioService.onDetection = _handleDetection;

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _alertTimer?.cancel();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.microphone,
      Permission.location,
      Permission.notification,
      Permission.ignoreBatteryOptimizations,
    ].request();
  }

  Future<void> _loadContact() async {
    final contacts = await DatabaseHelper.instance.getContacts();
    if (contacts.isNotEmpty) {
      setState(() {
        _emergencyContact = contacts.first['phone'];
        _contactController.text = _emergencyContact;
      });
    }
  }

  Future<void> _saveContact(String phone) async {
    final existing = await DatabaseHelper.instance.getContacts();
    for (var c in existing) {
      await DatabaseHelper.instance.deleteContact(c['id']);
    }
    await DatabaseHelper.instance.addContact("Primary", phone);
    setState(() {
      _emergencyContact = phone;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Emergency contact saved permanently.',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  void _handleDetection(String event, double score) {
    if (_isAlerting) return;

    DatabaseHelper.instance.logEvent(event, "Location Pending");

    setState(() {
      _latestEvent = event;
      _latestScore = score;
      _isAlerting = true;
      _countdown = 15;
    });

    _alertTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_countdown > 0) {
          _countdown--;
        } else {
          _executeEmergency();
        }
      });
    });
  }

  void _cancelAlert() {
    _alertTimer?.cancel();
    setState(() {
      _isAlerting = false;
      _latestEvent = "None";
      _latestScore = 0.0;
    });
  }

  void _executeEmergency() {
    _alertTimer?.cancel();
    setState(() {
      _isAlerting = false;
      _latestEvent = "None";
      _latestScore = 0.0;
    });

    if (_emergencyContact.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFFFF2A55),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          content: const Row(
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.white),
              SizedBox(width: 12),
              Text('No emergency contact set! Tap the gear icon.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
      return;
    }

    AlertService.triggerEmergencyWorkflow(_latestEvent, _emergencyContact);
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF121826),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: Color(0xFF1E293B), width: 1.5),
          ),
          title: const Row(
            children: [
              Icon(Icons.shield_outlined, color: Color(0xFF00F0FF)),
              SizedBox(width: 10),
              Text("Recipient Settings", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Enter the primary contact number to receive your automatic emergency SMS with your live GPS location.",
                style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _contactController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  labelText: "Emergency Phone Number",
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  prefixIcon: const Icon(Icons.phone_rounded, color: Color(0xFF00F0FF)),
                  filled: true,
                  fillColor: const Color(0xFF090D16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1E293B)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("CANCEL", style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00F0FF),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: () {
                _saveContact(_contactController.text.trim());
                Navigator.pop(context);
              },
              child: const Text("SAVE CONTACT", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.security_rounded, color: Color(0xFF00F0FF), size: 22),
            ),
            const SizedBox(width: 12),
            const Text(
              'ECHOGUARD',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded, color: Color(0xFF94A3B8)),
            tooltip: "Alert History",
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryScreen()));
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFF94A3B8)),
            tooltip: "Settings",
            onPressed: _showSettingsDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          child: _isAlerting ? _buildAlertView() : _buildDashboardView(),
        ),
      ),
    );
  }

  Widget _buildDashboardView() {
    final bool isMonitoring = _audioService.isMonitoring;

    if (isMonitoring && !_pulseController.isAnimating) {
      _pulseController.repeat(reverse: true);
    } else if (!isMonitoring && _pulseController.isAnimating) {
      _pulseController.stop();
      _pulseController.reset();
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Status Header Badge
          // Status Header Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isMonitoring ? const Color(0xFF10B981) : const Color(0xFF64748B),
                    boxShadow: isMonitoring
                        ? [BoxShadow(color: const Color(0xFF10B981).withValues(alpha: 0.6), blurRadius: 8, spreadRadius: 2)]
                        : [],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isMonitoring ? "SYSTEM ACTIVE — LISTENING" : "SYSTEM IDLE — STANDBY",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: isMonitoring ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "16kHz PCM",
                  style: TextStyle(
                    fontSize: 11,
                    color: const Color(0xFF64748B).withValues(alpha: 0.8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Central Pulse Microphone Visualizer Hub
          Center(
            child: GestureDetector(
              onTap: () async {
                if (_audioService.isMonitoring) {
                  await _audioService.stopMonitoring();
                  _latestEvent = "None";
                  _latestScore = 0.0;
                } else {
                  await _audioService.startMonitoring();
                }
                setState(() {});
              },
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      if (isMonitoring) ...[
                        Transform.scale(
                          scale: _pulseAnimation.value * 1.15,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.05),
                              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.15), width: 1.5),
                            ),
                          ),
                        ),
                        Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.10),
                              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3), width: 2),
                            ),
                          ),
                        ),
                      ],
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isMonitoring
                                ? [const Color(0xFF00F0FF), const Color(0xFF0082FF)]
                                : [const Color(0xFF1E293B), const Color(0xFF0F172A)],
                          ),
                          boxShadow: isMonitoring
                              ? [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.4),
                              blurRadius: 25,
                              spreadRadius: 4,
                            )
                          ]
                              : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        child: Icon(
                          isMonitoring ? Icons.mic_rounded : Icons.mic_none_rounded,
                          size: 52,
                          color: isMonitoring ? Colors.black : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 28),

          // Main Action Control Button
          Center(
            child: Column(
              children: [
                Text(
                  isMonitoring ? "Tap hub or button below to disarm" : "Tap button to activate threat detection",
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_audioService.isMonitoring) {
                        await _audioService.stopMonitoring();
                        _latestEvent = "None";
                        _latestScore = 0.0;
                      } else {
                        await _audioService.startMonitoring();
                      }
                      setState(() {});
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMonitoring ? const Color(0xFF1E293B) : const Color(0xFF00F0FF),
                      foregroundColor: isMonitoring ? const Color(0xFFF1F5F9) : Colors.black,
                      elevation: isMonitoring ? 0 : 8,
                      shadowColor: const Color(0xFF00F0FF).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: isMonitoring ? const Color(0xFF334155) : const Color(0xFF00F0FF),
                          width: 1.5,
                        ),
                      ),
                    ),
                    child: Text(
                      isMonitoring ? "DISARM MONITORING" : "START MONITORING",
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Live Sound Intelligence Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "SOUND INTELLIGENCE",
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF94A3B8)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: const Text("YAMNet TFLite", style: TextStyle(fontSize: 10, color: Color(0xFF00F0FF), fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF090D16),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF1E293B)),
                      ),
                      child: const Icon(Icons.graphic_eq_rounded, color: Color(0xFF00F0FF), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Latest Inference Classification", style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          const SizedBox(height: 4),
                          Text(
                            _latestEvent,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Confidence Level", style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                        Text(
                          "${(_latestScore * 100).toStringAsFixed(1)}%",
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: _latestScore.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: const Color(0xFF090D16),
                        color: _latestScore > 0.4 ? const Color(0xFFFF2A55) : const Color(0xFF00F0FF),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Protection Contact Chip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: Row(
              children: [
                Icon(
                  _emergencyContact.isEmpty ? Icons.contact_phone_outlined : Icons.verified_user_rounded,
                  color: _emergencyContact.isEmpty ? const Color(0xFFFF2A55) : const Color(0xFF10B981),
                  size: 24,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("EMERGENCY RECIPIENT", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF64748B), letterSpacing: 1.0)),
                      const SizedBox(height: 2),
                      Text(
                        _emergencyContact.isEmpty ? "No contact configured" : _emergencyContact,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: _emergencyContact.isEmpty ? const Color(0xFFFF2A55) : Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _showSettingsDialog,
                  child: Text(
                    _emergencyContact.isEmpty ? "SET NOW" : "CHANGE",
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF00F0FF)),
                  ),
                )
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Diagnostic Test Section
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _handleDetection("Test Mode (Scream)", 0.99),
              icon: const Icon(Icons.bug_report_outlined, size: 18, color: Color(0xFF94A3B8)),
              label: const Text("RUN DIAGNOSTIC SIMULATION", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0, color: Color(0xFF94A3B8))),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF1E293B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4C0519),
            Color(0xFF881337),
            Color(0xFF090D16),
          ],
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A55).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFF2A55), width: 2),
                ),
                child: const Icon(Icons.warning_amber_rounded, size: 64, color: Colors.white),
              ),
              const SizedBox(height: 16),
              const Text(
                "THREAT DETECTED",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 2.0, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Text(
                  "Suspected: $_latestEvent (${(_latestScore * 100).toStringAsFixed(0)}% Match)",
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFF1F5F9)),
                ),
              ),
            ],
          ),

          // Circular Digital Countdown Hub
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 180,
                height: 180,
                child: CircularProgressIndicator(
                  value: _countdown / 15.0,
                  strokeWidth: 10,
                  backgroundColor: Colors.black.withValues(alpha: 0.3),
                  color: const Color(0xFFFF2A55),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$_countdown",
                    style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white),
                  ),
                  const Text(
                    "SECONDS",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5, color: Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ],
          ),

          // Action Controls
          Column(
            children: [
              SizedBox(
                width: double.infinity,
                height: 58,
                child: ElevatedButton.icon(
                  onPressed: _cancelAlert,
                  icon: const Icon(Icons.shield_rounded, color: Colors.black),
                  label: const Text(
                    "I AM SAFE — CANCEL ALERT",
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.0, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 10,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: _executeEmergency,
                style: TextButton.styleFrom(foregroundColor: const Color(0xFFF1F5F9)),
                child: const Text(
                  "SEND EMERGENCY MESSAGE NOW",
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==========================================
// REDESIGNED ALERT HISTORY SCREEN
// ==========================================
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final db = await DatabaseHelper.instance.database;
    final logs = await db.query('history', orderBy: 'id DESC');
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF090D16),
      appBar: AppBar(
        backgroundColor: const Color(0xFF090D16),
        elevation: 0,
        title: const Text(
          "DETECTION HISTORY",
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5, fontSize: 16),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00F0FF)))
          : _logs.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF121826),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Icon(Icons.verified_user_outlined, size: 48, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 18),
            const Text(
              "No Danger Events Logged",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 6),
            const Text(
              "Your safety logs will appear here automatically.",
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(18),
        physics: const BouncingScrollPhysics(),
        itemCount: _logs.length,
        itemBuilder: (context, index) {
          final log = _logs[index];
          String time = log['timestamp'].toString().split('.')[0].replaceFirst('T', ' at ');

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF121826),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF1E293B)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF2A55).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFF2A55).withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF2A55), size: 22),
              ),
              title: Text(
                log['event_type'],
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  time,
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF090D16),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF1E293B)),
                ),
                child: const Text(
                  "Logged",
                  style: TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}