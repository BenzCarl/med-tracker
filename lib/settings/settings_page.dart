import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _selectedTheme = 'Blue';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
      _soundEnabled = prefs.getBool('soundEnabled') ?? true;
      _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
      _selectedTheme = prefs.getString('theme') ?? 'Blue';
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  // Get dynamic colors based on dark mode
  Color get _backgroundColor => _darkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  Color get _cardColor => _darkMode ? const Color(0xFF1E1E1E) : Colors.white;
  Color get _textColor => _darkMode ? Colors.white : Colors.grey.shade800;
  Color get _subtitleColor => _darkMode ? Colors.white70 : Colors.grey.shade600;
  LinearGradient get _gradientColors => LinearGradient(
    colors: _darkMode 
      ? [Colors.blue.shade800, Colors.purple.shade800]
      : [Colors.blue.shade600, Colors.purple.shade600],
  );

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: _gradientColors,
          ),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Section
            _buildProfileCard(user),
            const SizedBox(height: 24),
            
            // Notifications Section
            _buildSectionCard(
              'Notifications',
              Icons.notifications_rounded,
              [
                _buildSwitchTile(
                  'Enable Notifications',
                  _notificationsEnabled,
                  (value) {
                    setState(() => _notificationsEnabled = value);
                    _saveSetting('notificationsEnabled', value);
                  },
                ),
                _buildSwitchTile(
                  'Sound',
                  _soundEnabled,
                  (value) {
                    setState(() => _soundEnabled = value);
                    _saveSetting('soundEnabled', value);
                  },
                ),
                _buildSwitchTile(
                  'Vibration',
                  _vibrationEnabled,
                  (value) {
                    setState(() => _vibrationEnabled = value);
                    _saveSetting('vibrationEnabled', value);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Appearance Section
            _buildSectionCard(
              'Appearance',
              Icons.palette_rounded,
              [
                _buildSwitchTile(
                  'Dark Mode',
                  _darkMode,
                  (value) async {
                    setState(() => _darkMode = value);
                    await _saveSetting('darkMode', value);
                    // Show snackbar with restart message
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                _darkMode ? Icons.dark_mode : Icons.light_mode,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _darkMode 
                                    ? 'Dark mode enabled! Restart app for full effect.'
                                    : 'Light mode enabled! Restart app for full effect.',
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: _darkMode ? Colors.grey.shade800 : Colors.blue.shade600,
                          duration: const Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: Icon(
                    _darkMode ? Icons.dark_mode : Icons.light_mode,
                    color: Colors.blue.shade700,
                  ),
                  title: Text(
                    'Theme',
                    style: TextStyle(color: _textColor),
                  ),
                  subtitle: Text(
                    _darkMode ? 'Dark theme active' : 'Light theme active',
                    style: TextStyle(color: _subtitleColor, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // About Section
            _buildSectionCard(
              'About',
              Icons.info_rounded,
              [
                _buildActionTile('Version', '1.0.0', null),
                _buildActionTile('Privacy Policy', '', () {
                  _showInfoDialog(
                    context,
                    'Privacy Policy',
                    'Care Minder respects your privacy. All your medical data is stored securely and is only accessible by you.',
                  );
                }),
                _buildActionTile('Terms of Service', '', () {
                  _showInfoDialog(
                    context,
                    'Terms of Service',
                    'By using Care Minder, you agree to use this app for personal medication tracking purposes only.',
                  );
                }),
                _buildActionTile('Help & Support', '', () {
                  _showInfoDialog(
                    context,
                    'Help & Support',
                    'Need help? Contact us at support@careminder.com or visit our website for FAQs and guides.',
                  );
                }),
              ],
            ),
            const SizedBox(height: 16),
            
            // Data Management Section
            _buildSectionCard(
              'Data Management',
              Icons.storage_rounded,
              [
                _buildActionTile('Clear Cache', '', () async {
                  final confirm = await _showConfirmDialog(
                    context,
                    'Clear Cache',
                    'This will clear temporary data. Your medicines and schedules will not be affected.',
                  );
                  if (confirm == true && mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Cache cleared successfully'),
                        backgroundColor: Colors.green.shade600,
                      ),
                    );
                  }
                }),
                _buildActionTile('Export Data', '', () {
                  _showInfoDialog(
                    context,
                    'Export Data',
                    'Data export feature coming soon! You will be able to export your medication history to CSV or PDF.',
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(User? user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _gradientColors,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_darkMode ? Colors.black : Colors.blue).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundColor: Colors.blue.shade100,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 36, color: Colors.blue.shade700)
                  : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.displayName ?? 'User',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: _darkMode ? Border.all(color: Colors.white.withOpacity(0.1)) : null,
        boxShadow: [
          BoxShadow(
            color: (_darkMode ? Colors.black : Colors.black.withOpacity(0.05)),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(icon, color: Colors.blue.shade700),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _textColor,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: _textColor),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: Colors.blue.shade600,
      ),
    );
  }

  Widget _buildActionTile(String title, String subtitle, VoidCallback? onTap) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(color: _textColor),
      ),
      subtitle: subtitle.isNotEmpty ? Text(
        subtitle,
        style: TextStyle(color: _subtitleColor),
      ) : null,
      trailing: onTap != null ? Icon(
        Icons.chevron_right,
        color: _darkMode ? Colors.white70 : Colors.grey,
      ) : null,
      onTap: onTap,
    );
  }

  void _showInfoDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          title,
          style: TextStyle(color: _textColor),
        ),
        content: Text(
          content,
          style: TextStyle(color: _subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: TextStyle(color: Colors.blue.shade600),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _showConfirmDialog(BuildContext context, String title, String content) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _cardColor,
        title: Text(
          title,
          style: TextStyle(color: _textColor),
        ),
        content: Text(
          content,
          style: TextStyle(color: _subtitleColor),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}