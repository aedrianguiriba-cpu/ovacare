import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _loadEnv();
  await _initializeSupabase();

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();
  
  runApp(
    ChangeNotifierProvider.value(
      value: settingsProvider,
      child: const OvaCareAdminApp(),
    ),
  );
}

Future<void> _loadEnv() async {
  bool envLoaded = false;
  final possiblePaths = [
    "ovacare_admin/.env",
  ];

  for (final path in possiblePaths) {
    try {
      await dotenv.load(fileName: path);
      envLoaded = true;
      break;
    } catch (_) {
      // Try next path
    }
  }

  if (!envLoaded) {
    print('⚠️ Warning: Could not load .env file for admin app.');
  }
}

Future<void> _initializeSupabase() async {
  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  if (supabaseUrl == null ||
      supabaseUrl.isEmpty ||
      supabaseAnonKey == null ||
      supabaseAnonKey.isEmpty) {
    print('⚠️ Supabase not initialized. Missing SUPABASE_URL or SUPABASE_ANON_KEY.');
    return;
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  print('✅ Supabase initialized');
}

class OvaCareAdminApp extends StatelessWidget {
  const OvaCareAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OvaCare Admin Panel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const AdminLoginScreen(),
    );
  }
}

// Admin Login Screen
class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  void _handleLogin() async {
    setState(() => _isLoading = true);

    final email = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter email and password'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AdminDashboard(adminName: email),
          ),
        );
      }
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed. ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter your email to receive password reset instructions.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                prefixIcon: const Icon(Icons.email_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter your email'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              try {
                await Supabase.instance.client.auth.resetPasswordForEmail(email);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset instructions sent to $email'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on AuthException catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(e.message),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Reset failed. ${e.toString()}'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Admin Portal',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'OvaCare Management System',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _usernameController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400], size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[400],
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _showForgotPasswordDialog(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                      ),
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleLogin,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Demo Credentials',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'admin / admin123',
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'monospace',
                            color: Colors.grey[700],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Don\'t have an account? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminSignUpScreen()),
                          );
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Admin Sign Up Screen
class AdminSignUpScreen extends StatefulWidget {
  const AdminSignUpScreen({super.key});

  @override
  State<AdminSignUpScreen> createState() => _AdminSignUpScreenState();
}

class _AdminSignUpScreenState extends State<AdminSignUpScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  void _handleSignUp() async {
    // Validate fields
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _usernameController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All fields are required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Passwords do not match'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_passwordController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password must be at least 6 characters'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    await Future.delayed(const Duration(seconds: 1));

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account created successfully! Please sign in with username: ${_usernameController.text}',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 450),
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 24,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.person_add_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Create Admin Account',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill in your details to get started',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),
                  TextField(
                    controller: _firstNameController,
                    decoration: InputDecoration(
                      labelText: 'First Name',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400], size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lastNameController,
                    decoration: InputDecoration(
                      labelText: 'Last Name',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400], size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'Email Address',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.email_outlined, color: Colors.grey[400], size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.account_circle_outlined, color: Colors.grey[400], size: 20),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[400],
                        ),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPasswordController,
                    obscureText: _obscureConfirmPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirm Password',
                      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400], size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirmPassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: Colors.grey[400],
                        ),
                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Colors.black, width: 1.5),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleSignUp,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Main Admin Dashboard
class AdminDashboard extends StatefulWidget {
  final String adminName;
  const AdminDashboard({super.key, required this.adminName});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.dashboard, 'title': 'Dashboard', 'color': Colors.blue},
    {'icon': Icons.people, 'title': 'Users', 'color': Colors.green},
    {'icon': Icons.article, 'title': 'Content', 'color': Colors.orange},
    {'icon': Icons.notifications, 'title': 'Notifications', 'color': Colors.purple},
    {'icon': Icons.local_hospital, 'title': 'Doctors', 'color': Colors.red},
    {'icon': Icons.analytics, 'title': 'Logs', 'color': Colors.indigo},
    {'icon': Icons.feedback, 'title': 'Feedback', 'color': Colors.teal},
    {'icon': Icons.person, 'title': 'Profile', 'color': Colors.blueGrey},
  ];

  Widget _getSelectedScreen() {
    switch (_selectedIndex) {
      case 0:
        return const DashboardOverview();
      case 1:
        return const UserManagementScreen();
      case 2:
        return const ContentManagementScreen();
      case 3:
        return const NotificationManagementScreen();
      case 4:
        return const DoctorManagementScreen();
      case 5:
        return const SystemLogsScreen();
      case 6:
        return const FeedbackSupportScreen();
      case 7:
        return ProfileScreen(adminName: widget.adminName);
      default:
        return const DashboardOverview();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 64,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'OvaCare Admin',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: Text(
                widget.adminName,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: IconButton(
              icon: Icon(Icons.logout, color: Colors.grey[700], size: 20),
              onPressed: () async {
                try {
                  await Supabase.instance.client.auth.signOut();
                } catch (_) {
                  // Continue to logout UI even if sign out fails.
                }
                if (!context.mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                );
              },
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: Colors.grey[200],
            height: 1,
          ),
        ),
      ),
      body: _getSelectedScreen(),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: Colors.grey[200]!, width: 1),
          ),
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _menuItems.length,
              itemBuilder: (context, index) {
                final item = _menuItems[index];
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIndex = index),
                  child: Container(
                    width: 80,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isSelected ? item['color'].withOpacity(0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isSelected ? Border.all(color: item['color'].withOpacity(0.3), width: 1) : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item['icon'],
                          color: isSelected ? item['color'] : Colors.grey[500],
                          size: 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item['title'],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                            color: isSelected ? item['color'] : Colors.grey[600],
                            fontSize: 9.5,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// Dashboard Overview Screen
class DashboardOverview extends StatefulWidget {
  const DashboardOverview({super.key});

  @override
  State<DashboardOverview> createState() => _DashboardOverviewState();
}

class _DashboardOverviewState extends State<DashboardOverview> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  final List<Map<String, dynamic>> _recentActivity = [
    {'text': 'New user registered from Floridablanca', 'time': '5 min ago', 'icon': Icons.person_add, 'color': Colors.green, 'type': 'user'},
    {'text': 'PCOS article published', 'time': '32 min ago', 'icon': Icons.article, 'color': Colors.blue, 'type': 'content'},
    {'text': 'Health alert sent to 234 users', 'time': '1 hour ago', 'icon': Icons.notifications_active, 'color': Colors.orange, 'type': 'alert'},
    {'text': 'New forum post flagged for review', 'time': '2 hours ago', 'icon': Icons.flag, 'color': Colors.red, 'type': 'moderation'},
    {'text': 'Weekly analytics report generated', 'time': '3 hours ago', 'icon': Icons.analytics, 'color': Colors.purple, 'type': 'report'},
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.grey[50]!,
              Colors.pink[50]!.withOpacity(0.3),
              Colors.purple[50]!.withOpacity(0.2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header with Gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink[400]!, Colors.purple[500]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.pink.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Welcome back, Admin! 👋',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Here\'s what\'s happening with your platform today.',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.calendar_today, color: Colors.white, size: 14),
                                const SizedBox(width: 6),
                                Text(
                                  _getFormattedDate(),
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 40),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats Row
              Row(
                children: [
                  Expanded(child: _buildModernStatCard(
                    'Total Users',
                    '1,247',
                    Icons.people_alt_rounded,
                    [Colors.blue[400]!, Colors.blue[600]!],
                    '+12%',
                    true,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernStatCard(
                    'Active Today',
                    '342',
                    Icons.trending_up_rounded,
                    [Colors.green[400]!, Colors.green[600]!],
                    '+8%',
                    true,
                  )),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _buildModernStatCard(
                    'Forum Posts',
                    '856',
                    Icons.forum_rounded,
                    [Colors.pink[400]!, Colors.pink[600]!],
                    '+18%',
                    true,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _buildModernStatCard(
                    'Articles',
                    '124',
                    Icons.article_rounded,
                    [Colors.purple[400]!, Colors.purple[600]!],
                    '+5%',
                    true,
                  )),
                ],
              ),
              const SizedBox(height: 24),

              // Recent Activity Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.history_rounded, color: Colors.blue[600], size: 22),
                          ),
                          const SizedBox(width: 14),
                          const Text(
                            'Recent Activity',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          TextButton(
                            onPressed: () {},
                            child: Text('View All', style: TextStyle(color: Colors.blue[600], fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    ..._recentActivity.map((activity) => _buildModernActivityItem(activity)),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _getFormattedDate() {
    final now = DateTime.now();
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    return '${days[now.weekday % 7]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  Widget _buildModernStatCard(String title, String value, IconData icon, List<Color> gradient, String growth, bool showGrowth) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: gradient[0].withOpacity(0.15),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: gradient),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              if (showGrowth && growth.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.trending_up_rounded, size: 12, color: Colors.green[600]),
                      const SizedBox(width: 2),
                      Text(growth, style: TextStyle(fontSize: 11, color: Colors.green[600], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: gradient[1],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernActivityItem(Map<String, dynamic> activity) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (activity['color'] as Color).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(activity['icon'] as IconData, color: activity['color'] as Color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['text'] as String,
                  style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  activity['time'] as String,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
        ],
      ),
    );
  }
}

// User Management Screen
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _searchQuery = '';
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Active', 'Inactive'];

  final List<Map<String, dynamic>> _users = [
    {
      'name': 'Sarah Johnson',
      'email': 'sarah@example.com',
      'status': 'Active',
      'joined': 'Jan 15, 2025',
      'city': 'Floridablanca',
      'avatar': 'S',
      'lastActive': '2 hours ago',
    },
    {
      'name': 'Maria Santos',
      'email': 'maria@example.com',
      'status': 'Active',
      'joined': 'Feb 20, 2025',
      'city': 'San Fernando',
      'avatar': 'M',
      'lastActive': '5 mins ago',
    },
    {
      'name': 'Anna Garcia',
      'email': 'anna@example.com',
      'status': 'Inactive',
      'joined': 'Dec 10, 2024',
      'city': 'Angeles City',
      'avatar': 'A',
      'lastActive': '3 days ago',
    },
    {
      'name': 'Jane Doe',
      'email': 'jane@example.com',
      'status': 'Active',
      'joined': 'Mar 05, 2025',
      'city': 'Guagua',
      'avatar': 'J',
      'lastActive': '1 hour ago',
    },
    {
      'name': 'Emily Chen',
      'email': 'emily@example.com',
      'status': 'Active',
      'joined': 'Feb 14, 2025',
      'city': 'Lubao',
      'avatar': 'E',
      'lastActive': 'Just now',
    },
    {
      'name': 'Sofia Rivera',
      'email': 'sofia@example.com',
      'status': 'Inactive',
      'joined': 'Nov 22, 2024',
      'city': 'Porac',
      'avatar': 'S',
      'lastActive': '1 week ago',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredUsers {
    var users = _users;
    if (_selectedFilter != 'All') {
      users = users.where((user) => user['status'] == _selectedFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      users = users.where((user) {
        return user['name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
               user['email'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
               user['city'].toString().toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    return users;
  }

  int get _activeCount => _users.where((u) => u['status'] == 'Active').length;
  int get _inactiveCount => _users.where((u) => u['status'] == 'Inactive').length;

  Color _getAvatarColor(String initial) {
    final colors = [Colors.pink, Colors.purple, Colors.indigo, Colors.blue, Colors.teal, Colors.orange];
    return colors[initial.codeUnitAt(0) % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[400]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.people_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'User Management',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'View and manage registered users',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard('Total Users', _users.length.toString(), Icons.group_rounded, Colors.indigo, 'All registered'),
                    const SizedBox(width: 12),
                    _buildStatCard('Active', _activeCount.toString(), Icons.check_circle_rounded, Colors.green, 'Currently active'),
                    const SizedBox(width: 12),
                    _buildStatCard('Inactive', _inactiveCount.toString(), Icons.cancel_rounded, Colors.grey, 'Not active'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Search and Filter Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with search
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.indigo[50]!, Colors.purple[50]!],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.indigo[400]!, Colors.purple[400]!],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'All Users',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${_filteredUsers.length} users found',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Search field
                          TextField(
                            onChanged: (value) => setState(() => _searchQuery = value),
                            decoration: InputDecoration(
                              hintText: 'Search by name, email, or city...',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                              prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters.map((filter) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(filter),
                                  selected: _selectedFilter == filter,
                                  onSelected: (selected) {
                                    setState(() => _selectedFilter = filter);
                                  },
                                  selectedColor: Colors.indigo[100],
                                  checkmarkColor: Colors.indigo[700],
                                  labelStyle: TextStyle(
                                    color: _selectedFilter == filter ? Colors.indigo[700] : Colors.grey[600],
                                    fontWeight: _selectedFilter == filter ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Users list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredUsers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildUserCard(_filteredUsers[index]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final isActive = user['status'] == 'Active';
    final statusColor = isActive ? Colors.green : Colors.grey;
    final avatarColor = _getAvatarColor(user['avatar']);

    return InkWell(
      onTap: () => _showUserDetails(user),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Row(
          children: [
            // Avatar with status indicator
            Stack(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [avatarColor.withOpacity(0.8), avatarColor],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      user['avatar'],
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user['email'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          user['city'],
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          user['lastActive'],
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.more_vert_rounded, size: 18, color: Colors.grey[600]),
              ),
              onSelected: (value) => _handleUserAction(value, user),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'view',
                  child: Row(
                    children: [
                      Icon(Icons.visibility_rounded, size: 18, color: Colors.grey[600]),
                      const SizedBox(width: 10),
                      const Text('View Details'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        isActive ? Icons.block_rounded : Icons.check_circle_rounded,
                        size: 18,
                        color: isActive ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 10),
                      Text(isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'reset',
                  child: Row(
                    children: [
                      Icon(Icons.lock_reset_rounded, size: 18, color: Colors.blue[600]),
                      const SizedBox(width: 10),
                      const Text('Reset Password'),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_rounded, size: 18, color: Colors.red[600]),
                      const SizedBox(width: 10),
                      Text('Delete User', style: TextStyle(color: Colors.red[600])),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleUserAction(String action, Map<String, dynamic> user) {
    switch (action) {
      case 'view':
        _showUserDetails(user);
        break;
      case 'toggle':
        setState(() {
          user['status'] = user['status'] == 'Active' ? 'Inactive' : 'Active';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text('${user['name']} is now ${user['status']}')),
              ],
            ),
            backgroundColor: Colors.indigo,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        break;
      case 'reset':
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.email, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(child: Text('Password reset email sent to ${user['email']}')),
              ],
            ),
            backgroundColor: Colors.blue,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        break;
      case 'delete':
        _showDeleteConfirmation(user);
        break;
    }
  }

  void _showDeleteConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.red[600]),
            const SizedBox(width: 10),
            const Text('Delete User'),
          ],
        ),
        content: Text('Are you sure you want to delete ${user['name']}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _users.removeWhere((u) => u['email'] == user['email']);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.delete, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Flexible(child: Text('${user['name']} has been deleted')),
                    ],
                  ),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showUserDetails(Map<String, dynamic> user) {
    final isActive = user['status'] == 'Active';
    final statusColor = isActive ? Colors.green : Colors.grey;
    final avatarColor = _getAvatarColor(user['avatar']);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  // Avatar and basic info
                  Row(
                    children: [
                      Container(
                        width: 70,
                        height: 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [avatarColor.withOpacity(0.8), avatarColor],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Text(
                            user['avatar'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user['name'],
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                user['status'],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(Icons.email_rounded, 'Email', user['email']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.location_on_rounded, 'City', user['city']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today_rounded, 'Joined', user['joined']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.access_time_rounded, 'Last Active', user['lastActive']),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            setState(() {
                              user['status'] = user['status'] == 'Active' ? 'Inactive' : 'Active';
                            });
                          },
                          icon: Icon(isActive ? Icons.block_rounded : Icons.check_circle_rounded),
                          label: Text(isActive ? 'Deactivate' : 'Activate'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isActive ? Colors.orange : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.grey[800],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Content Management Screen
class ContentManagementScreen extends StatefulWidget {
  const ContentManagementScreen({super.key});

  @override
  State<ContentManagementScreen> createState() => _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen> {
  String _selectedCategory = 'All';
  String _selectedStatus = 'All';
  
  static const categories = ['All', 'PCOS Basics', 'Diet', 'Exercise', 'Mental Health', 'Fertility', 'Treatment'];
  
  // Article icons mapping
  static const Map<String, IconData> iconMap = {
    'medical_information': Icons.medical_information,
    'bloodtype': Icons.bloodtype,
    'restaurant_menu': Icons.restaurant_menu,
    'eco': Icons.eco,
    'medication': Icons.medication,
    'fitness_center': Icons.fitness_center,
    'self_improvement': Icons.self_improvement,
    'psychology': Icons.psychology,
    'favorite': Icons.favorite,
    'healing': Icons.healing,
    'science': Icons.science,
    'article': Icons.article,
  };
  
  // Articles data matching main app Learn section structure
  final List<Map<String, dynamic>> _articles = [
    {
      'id': '1',
      'title': 'PCOS Diagnostic Criteria: Rotterdam Consensus',
      'author': 'Rotterdam ESHRE/ASRM-Sponsored PCOS Consensus Workshop Group',
      'journal': 'Human Reproduction',
      'category': 'PCOS Basics',
      'content': '''The Rotterdam criteria (2003, published 2004) define PCOS by the presence of at least 2 of 3 features:

• Oligo/anovulation (irregular or absent periods)
• Clinical or biochemical signs of hyperandrogenism (excess male hormones)
• Polycystic ovaries on ultrasound (≥12 follicles 2-9mm or ovarian volume >10ml)

Key Statistics (WHO + OvaCare Dataset, n=15,000):
• Irregular Periods: 70% prevalence
• Insulin Resistance: 70% prevalence  
• Weight Gain: 80% prevalence
• Infertility/Subfertility: 40% prevalence
• Mood Changes/Depression: 50% prevalence

This consensus statement is the most widely used diagnostic criteria worldwide and has been cited over 10,000 times.''',
      'summary': 'Official Rotterdam diagnostic criteria - the international standard for PCOS diagnosis.',
      'icon': 'medical_information',
      'tags': ['Rotterdam', 'Diagnosis', 'Consensus'],
      'link': 'https://academic.oup.com/humrep/article/19/1/41/690226',
      'year': '2004',
      'keyFinding': 'Standard diagnostic criteria',
      'isFeatured': true,
      'status': 'Published',
    },
    {
      'id': '2',
      'title': 'Insulin Resistance in PCOS: Mechanisms Update',
      'author': 'Diamanti-Kandarakis E, Dunaif A',
      'journal': 'Endocrine Reviews',
      'category': 'PCOS Basics',
      'content': '''This comprehensive 2012 review established that insulin resistance (IR) affects 50-70% of women with PCOS, regardless of BMI.

OvaCare Dataset Findings (n=15,000):
• Insulin Resistance prevalence: 70%
• Weight Gain prevalence: 80%
• Impact rated: Critical - affects treatment decisions

How Insulin Resistance Affects PCOS:
• Elevated insulin stimulates ovarian androgen production
• Causes decreased SHBG (sex hormone binding globulin)
• Results in more free testosterone circulation
• Promotes weight gain, especially around the abdomen
• Disrupts ovulation leading to irregular cycles''',
      'summary': 'Landmark review: 50-70% of PCOS women have insulin resistance regardless of weight.',
      'icon': 'bloodtype',
      'tags': ['Insulin', 'Review', 'Metabolic'],
      'link': 'https://academic.oup.com/edrv/article/33/6/981/2354852',
      'year': '2012',
      'keyFinding': '70% have insulin resistance',
      'isFeatured': false,
      'status': 'Published',
    },
    {
      'id': '3',
      'title': 'Low Glycemic Index Diet for PCOS',
      'author': 'Marsh KA, Steinbeck KS, Atkinson FS, et al.',
      'journal': 'American Journal of Clinical Nutrition',
      'category': 'Diet',
      'content': '''Randomized controlled trial comparing low glycemic index (GI) diet versus conventional healthy diet in 96 women with PCOS.

Study Design:
• 12-week dietary intervention
• Matched for macronutrient intake and calories
• Published in Am J Clin Nutr 2010

Results:
• Menstrual regularity improved significantly with low-GI diet
• Greater reduction in fasting insulin with low-GI
• Better improvement in insulin sensitivity
• Similar weight loss between groups''',
      'summary': 'RCT: Low-GI diet improves menstrual regularity and insulin in PCOS.',
      'icon': 'restaurant_menu',
      'tags': ['Diet', 'RCT', 'Glycemic Index'],
      'link': 'https://academic.oup.com/ajcn/article/92/1/83/4597492',
      'year': '2010',
      'keyFinding': 'Improved cycle regularity',
      'isFeatured': true,
      'status': 'Published',
    },
    {
      'id': '4',
      'title': 'Exercise for PCOS: Systematic Review',
      'author': 'Harrison CL, Lombard CB, Moran LJ, Teede HJ',
      'journal': 'Human Reproduction Update',
      'category': 'Exercise',
      'content': '''Systematic review examining exercise effects on PCOS outcomes.

Key Findings:
• Exercise improved insulin resistance independent of weight loss
• Reduced androgen levels
• Improved ovulation rates
• Better cardiorespiratory fitness
• Reduced depression and anxiety symptoms

OvaCare Exercise Recommendations:
• 150 mins aerobic activity/week (High efficacy)
• Add strength training 2x/week (High efficacy)''',
      'summary': 'Exercise improves insulin resistance and ovulation independent of weight loss.',
      'icon': 'fitness_center',
      'tags': ['Exercise', 'Review', 'Lifestyle'],
      'link': 'https://academic.oup.com/humupd/article/17/2/171/760764',
      'year': '2011',
      'keyFinding': '70% efficacy rating',
      'isFeatured': true,
      'status': 'Published',
    },
    {
      'id': '5',
      'title': 'Mental Health and PCOS: Understanding the Connection',
      'author': 'Barry JA, Kuczmierczyk AR, Hardiman PJ',
      'journal': 'PLOS ONE',
      'category': 'Mental Health',
      'content': '''Meta-analysis examining psychological outcomes in PCOS.

Key Findings:
• Women with PCOS have higher rates of depression
• Anxiety is significantly elevated
• Body image concerns are common
• Quality of life may be reduced

OvaCare Mental Health Support:
• Stress management techniques (Medium efficacy)
• Mindfulness and meditation (Medium efficacy)
• Professional counseling when needed''',
      'summary': 'Meta-analysis: PCOS linked to higher rates of depression and anxiety.',
      'icon': 'psychology',
      'tags': ['Mental Health', 'Meta-analysis', 'Depression'],
      'link': 'https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0138793',
      'year': '2015',
      'keyFinding': 'Higher depression rates',
      'isFeatured': false,
      'status': 'Published',
    },
    {
      'id': '6',
      'title': 'Fertility Treatment Options for PCOS',
      'author': 'Teede HJ, Misso ML, et al.',
      'journal': 'Journal of Clinical Endocrinology',
      'category': 'Fertility',
      'content': '''Evidence-based guidelines for fertility in PCOS.

First-line treatments:
• Lifestyle modification
• Letrozole for ovulation induction
• Clomiphene citrate

Second-line treatments:
• Gonadotropins
• Laparoscopic ovarian surgery

Third-line:
• In vitro fertilization (IVF)''',
      'summary': 'Guidelines for evidence-based fertility treatment in PCOS.',
      'icon': 'favorite',
      'tags': ['Fertility', 'Guidelines', 'Treatment'],
      'link': 'https://academic.oup.com/jcem/article/100/12/4612/2536124',
      'year': '2018',
      'keyFinding': 'Letrozole first-line',
      'isFeatured': false,
      'status': 'Draft',
    },
    {
      'id': '7',
      'title': 'Metformin for PCOS: A Comprehensive Review',
      'author': 'Morley LC, Tang T, et al.',
      'journal': 'Human Reproduction',
      'category': 'Treatment',
      'content': '''Systematic review of metformin use in PCOS management.

Benefits:
• Improves insulin sensitivity
• May aid in weight management
• Can restore ovulation
• Reduces androgen levels

Side effects:
• GI symptoms (nausea, diarrhea)
• Usually improve over time
• Extended-release formulations better tolerated''',
      'summary': 'Comprehensive review of metformin efficacy and safety in PCOS.',
      'icon': 'medication',
      'tags': ['Treatment', 'Metformin', 'Review'],
      'link': 'https://academic.oup.com/jcem/article/98/12/4565/2833703',
      'year': '2017',
      'keyFinding': '90% efficacy rating',
      'isFeatured': false,
      'status': 'Pending',
    },
  ];

  List<Map<String, dynamic>> get filteredArticles {
    var articles = _articles;
    if (_selectedCategory != 'All') {
      articles = articles.where((a) => a['category'] == _selectedCategory).toList();
    }
    if (_selectedStatus != 'All') {
      articles = articles.where((a) => a['status'] == _selectedStatus).toList();
    }
    return articles;
  }

  List<Map<String, dynamic>> get featuredArticles {
    return _articles.where((a) => a['isFeatured'] == true && a['status'] == 'Published').toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.pink[400]!, Colors.purple[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.pink.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.school, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Content Management',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage Learn section articles and research content',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Article'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _showArticleEditor(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Stats Overview Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.pink[400]!, Colors.purple[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.pink.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.analytics, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      const Text(
                        'Content Statistics',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_articles.length} Total Articles',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildStatCard('Published', _articles.where((a) => a['status'] == 'Published').length.toString(), Colors.green),
                      const SizedBox(width: 12),
                      _buildStatCard('Pending', _articles.where((a) => a['status'] == 'Pending').length.toString(), Colors.orange),
                      const SizedBox(width: 12),
                      _buildStatCard('Draft', _articles.where((a) => a['status'] == 'Draft').length.toString(), Colors.grey),
                      const SizedBox(width: 12),
                      _buildStatCard('Featured', featuredArticles.length.toString(), Colors.amber),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Filters
            Row(
              children: [
                // Category Filter
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Category', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                selected: isSelected,
                                label: Text(cat),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.pink[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                                backgroundColor: Colors.pink[50],
                                selectedColor: Colors.pink[400],
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) => setState(() => _selectedCategory = cat),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Status Filter
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['All', 'Published', 'Pending', 'Draft'].map((status) {
                final isSelected = _selectedStatus == status;
                return FilterChip(
                  label: Text(status),
                  selected: isSelected,
                  onSelected: (_) => setState(() => _selectedStatus = status),
                  backgroundColor: Colors.white,
                  selectedColor: _getStatusColor(status),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w500,
                    fontSize: 12,
                  ),
                  side: BorderSide(color: isSelected ? _getStatusColor(status) : Colors.grey[300]!),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            
            // Featured Section
            if (_selectedCategory == 'All' && _selectedStatus == 'All' && featuredArticles.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.star, color: Colors.amber[600], size: 22),
                  const SizedBox(width: 8),
                  const Text('Featured Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  Text('${featuredArticles.length} featured', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 200,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: featuredArticles.map((article) => _buildFeaturedCard(article)).toList(),
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Articles List
            Row(
              children: [
                const Text('All Articles', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                Text('${filteredArticles.length} articles', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            
            ...filteredArticles.map((article) => _buildArticleCard(article)).toList(),
            
            if (filteredArticles.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.article_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No articles found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(Map<String, dynamic> article) {
    return Container(
      width: 300,
      margin: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.pink[50]!, Colors.purple[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.pink[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showArticleDetail(article),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.pink[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      iconMap[article['icon']] ?? Icons.article,
                      color: Colors.pink[700],
                      size: 22,
                    ),
                  ),
                  const Spacer(),
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.amber[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star, color: Colors.amber[700], size: 12),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              article['keyFinding'] as String,
                              style: TextStyle(color: Colors.amber[800], fontSize: 10, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                article['title'] as String,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                article['journal'] as String,
                style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const Spacer(),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.pink[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        article['category'] as String,
                        style: TextStyle(fontSize: 10, color: Colors.pink[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    article['year'] as String,
                    style: TextStyle(color: Colors.grey[500], fontSize: 11),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View →',
                    style: TextStyle(color: Colors.pink[600], fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArticleCard(Map<String, dynamic> article) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showArticleDetail(article),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.pink[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconMap[article['icon']] ?? Icons.article,
                  color: Colors.pink[600],
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            article['title'] as String,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (article['isFeatured'] == true)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(Icons.star, color: Colors.amber[600], size: 18),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      article['summary'] as String,
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.pink[50],
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            article['category'] as String,
                            style: TextStyle(fontSize: 10, color: Colors.pink[700], fontWeight: FontWeight.w500),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(article['status']).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            article['status'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(article['status']),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          '${article['journal']} (${article['year']})',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  PopupMenuButton<String>(
                    icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                    onSelected: (value) => _handleArticleAction(value, article),
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('View')])),
                      const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                      PopupMenuItem(
                        value: 'feature',
                        child: Row(children: [
                          Icon(article['isFeatured'] ? Icons.star_border : Icons.star, size: 18),
                          const SizedBox(width: 8),
                          Text(article['isFeatured'] ? 'Unfeature' : 'Feature'),
                        ]),
                      ),
                      if (article['status'] == 'Draft' || article['status'] == 'Pending')
                        const PopupMenuItem(value: 'publish', child: Row(children: [Icon(Icons.publish, size: 18), SizedBox(width: 8), Text('Publish')])),
                      if (article['status'] == 'Published')
                        const PopupMenuItem(value: 'unpublish', child: Row(children: [Icon(Icons.unpublished, size: 18), SizedBox(width: 8), Text('Unpublish')])),
                      const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleArticleAction(String action, Map<String, dynamic> article) {
    switch (action) {
      case 'view':
        _showArticleDetail(article);
        break;
      case 'edit':
        _showArticleEditor(article: article);
        break;
      case 'feature':
        setState(() => article['isFeatured'] = !article['isFeatured']);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(article['isFeatured'] ? 'Article featured' : 'Article unfeatured'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 'publish':
        setState(() => article['status'] = 'Published');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 12),
              Text('${article['title']} published'),
            ]),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
          ),
        );
        break;
      case 'unpublish':
        setState(() => article['status'] = 'Draft');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Article unpublished'), behavior: SnackBarBehavior.floating),
        );
        break;
      case 'delete':
        _showDeleteDialog(article);
        break;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Published':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Draft':
        return Colors.grey;
      case 'All':
        return Colors.black;
      default:
        return Colors.grey;
    }
  }

  void _showArticleDetail(Map<String, dynamic> article) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.pink[100]!, Colors.purple[100]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      iconMap[article['icon']] ?? Icons.article,
                      color: Colors.pink[600],
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusColor(article['status']).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                article['status'],
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _getStatusColor(article['status']),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            if (article['isFeatured'] == true) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.amber[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.star, color: Colors.amber[700], size: 12),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Featured',
                                      style: TextStyle(fontSize: 11, color: Colors.amber[700], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          article['category'],
                          style: TextStyle(color: Colors.pink[600], fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              // Title
              Text(
                article['title'],
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              
              // Meta Info
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildMetaRow(Icons.person, 'Author', article['author']),
                    const Divider(height: 20),
                    _buildMetaRow(Icons.book, 'Journal', article['journal']),
                    const Divider(height: 20),
                    _buildMetaRow(Icons.calendar_today, 'Year', article['year']),
                    const Divider(height: 20),
                    _buildMetaRow(Icons.lightbulb, 'Key Finding', article['keyFinding']),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Summary
              const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                article['summary'],
                style: TextStyle(fontSize: 14, color: Colors.grey[700], height: 1.5),
              ),
              const SizedBox(height: 20),
              
              // Full Content
              const Text('Full Content', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              Text(
                article['content'],
                style: TextStyle(fontSize: 14, color: Colors.grey[800], height: 1.6),
              ),
              const SizedBox(height: 20),
              
              // Tags
              if (article['tags'] != null && (article['tags'] as List).isNotEmpty) ...[
                const Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: (article['tags'] as List).map((tag) => Chip(
                    label: Text(tag, style: const TextStyle(fontSize: 12)),
                    backgroundColor: Colors.pink[50],
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              ],
              const SizedBox(height: 20),
              
              // Source Link
              if (article['link'] != null && article['link'].isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('View Original Source'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => _launchUrl(article['link']),
                ),
              const SizedBox(height: 16),
              
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Article'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showArticleEditor(article: article);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: Icon(article['status'] == 'Published' ? Icons.unpublished : Icons.publish, size: 18),
                      label: Text(article['status'] == 'Published' ? 'Unpublish' : 'Publish'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: article['status'] == 'Published' ? Colors.orange : Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          article['status'] = article['status'] == 'Published' ? 'Draft' : 'Published';
                        });
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Article ${article['status'] == 'Published' ? 'published' : 'unpublished'}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        const Spacer(),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showArticleEditor({Map<String, dynamic>? article}) {
    final isEditing = article != null;
    final titleController = TextEditingController(text: article?['title'] ?? '');
    final authorController = TextEditingController(text: article?['author'] ?? '');
    final journalController = TextEditingController(text: article?['journal'] ?? '');
    final yearController = TextEditingController(text: article?['year'] ?? '');
    final summaryController = TextEditingController(text: article?['summary'] ?? '');
    final contentController = TextEditingController(text: article?['content'] ?? '');
    final keyFindingController = TextEditingController(text: article?['keyFinding'] ?? '');
    final linkController = TextEditingController(text: article?['link'] ?? '');
    final tagsController = TextEditingController(text: (article?['tags'] as List?)?.join(', ') ?? '');
    
    String selectedCategory = article?['category'] ?? 'PCOS Basics';
    String selectedIcon = article?['icon'] ?? 'article';
    bool isFeatured = article?['isFeatured'] ?? false;
    String selectedStatus = article?['status'] ?? 'Draft';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.pink[400]!, Colors.purple[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.article, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Article' : 'Add New Article',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const Text(
                            'Fill in the article details',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Section
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 16),
                      _buildTextField(titleController, 'Title *', 'Enter article title'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(authorController, 'Author', 'Enter author name')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(journalController, 'Journal', 'Enter journal name')),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildTextField(yearController, 'Year', 'YYYY')),
                          const SizedBox(width: 12),
                          Expanded(child: _buildTextField(keyFindingController, 'Key Finding', 'Main takeaway')),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // Category & Status
                      _buildSectionHeader('Classification'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedCategory,
                              decoration: InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: categories.where((c) => c != 'All').map((c) => 
                                DropdownMenuItem(value: c, child: Text(c))
                              ).toList(),
                              onChanged: (v) => setModalState(() => selectedCategory = v!),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: selectedStatus,
                              decoration: InputDecoration(
                                labelText: 'Status',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ['Draft', 'Pending', 'Published'].map((s) => 
                                DropdownMenuItem(value: s, child: Text(s))
                              ).toList(),
                              onChanged: (v) => setModalState(() => selectedStatus = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Icon Selection
                      const Text('Icon', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: iconMap.entries.map((entry) {
                          final isSelected = selectedIcon == entry.key;
                          return GestureDetector(
                            onTap: () => setModalState(() => selectedIcon = entry.key),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.pink[100] : Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isSelected ? Colors.pink[400]! : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                entry.value,
                                color: isSelected ? Colors.pink[600] : Colors.grey[600],
                                size: 22,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      
                      // Featured Toggle
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isFeatured ? Colors.amber[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isFeatured ? Colors.amber[300]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isFeatured ? Icons.star : Icons.star_border,
                              color: isFeatured ? Colors.amber[600] : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Featured Article', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    'Display in featured section',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isFeatured,
                              onChanged: (v) => setModalState(() => isFeatured = v),
                              activeColor: Colors.amber[600],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Content Section
                      _buildSectionHeader('Content'),
                      const SizedBox(height: 16),
                      _buildTextField(summaryController, 'Summary', 'Brief summary of the article', maxLines: 2),
                      const SizedBox(height: 16),
                      _buildTextField(contentController, 'Full Content *', 'Enter the full article content...', maxLines: 8),
                      const SizedBox(height: 16),
                      _buildTextField(tagsController, 'Tags', 'Comma-separated tags (e.g., PCOS, Diet, Research)'),
                      const SizedBox(height: 16),
                      _buildTextField(linkController, 'Source Link', 'https://...'),
                      const SizedBox(height: 32),
                      
                      // Save Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (titleController.text.isEmpty || contentController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Title and content are required'), backgroundColor: Colors.red),
                              );
                              return;
                            }
                            
                            final tags = tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
                            
                            if (isEditing) {
                              setState(() {
                                article!['title'] = titleController.text;
                                article['author'] = authorController.text;
                                article['journal'] = journalController.text;
                                article['year'] = yearController.text;
                                article['category'] = selectedCategory;
                                article['summary'] = summaryController.text;
                                article['content'] = contentController.text;
                                article['keyFinding'] = keyFindingController.text;
                                article['link'] = linkController.text;
                                article['tags'] = tags;
                                article['icon'] = selectedIcon;
                                article['isFeatured'] = isFeatured;
                                article['status'] = selectedStatus;
                              });
                            } else {
                              setState(() {
                                _articles.add({
                                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                                  'title': titleController.text,
                                  'author': authorController.text.isEmpty ? 'Admin' : authorController.text,
                                  'journal': journalController.text.isEmpty ? 'OvaCare' : journalController.text,
                                  'year': yearController.text.isEmpty ? DateTime.now().year.toString() : yearController.text,
                                  'category': selectedCategory,
                                  'summary': summaryController.text,
                                  'content': contentController.text,
                                  'keyFinding': keyFindingController.text.isEmpty ? 'New research' : keyFindingController.text,
                                  'link': linkController.text,
                                  'tags': tags,
                                  'icon': selectedIcon,
                                  'isFeatured': isFeatured,
                                  'status': selectedStatus,
                                });
                              });
                            }
                            
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text(isEditing ? 'Article updated' : 'Article created'),
                                ]),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            isEditing ? 'Save Changes' : 'Create Article',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.pink[400],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.pink[400]!, width: 2),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> article) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Article'),
          ],
        ),
        content: Text('Are you sure you want to delete "${article['title']}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() => _articles.remove(article));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Article deleted'), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

// Notification Management Screen
class NotificationManagementScreen extends StatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  State<NotificationManagementScreen> createState() => _NotificationManagementScreenState();
}

class _NotificationManagementScreenState extends State<NotificationManagementScreen> {
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedAudience = 'All Users';
  String _selectedType = 'Announcement';
  
  final List<String> _audienceOptions = ['All Users', 'Active Users', 'New Users', 'Premium Users'];
  final List<String> _typeOptions = ['Announcement', 'Health Tip', 'Reminder', 'Alert', 'Update'];
  
  final List<Map<String, dynamic>> _notifications = [
    {
      'title': 'Women\'s Health Campaign',
      'message': 'Join our special campaign for women\'s health awareness this month.',
      'audience': 'All Users',
      'type': 'Announcement',
      'status': 'Sent',
      'recipients': 1247,
      'time': '2 hours ago',
      'icon': Icons.campaign_rounded,
      'color': Colors.pink,
    },
    {
      'title': 'System Maintenance Notice',
      'message': 'Scheduled maintenance on Sunday from 2-4 AM.',
      'audience': 'All Users',
      'type': 'Alert',
      'status': 'Sent',
      'recipients': 1247,
      'time': '1 day ago',
      'icon': Icons.build_rounded,
      'color': Colors.orange,
    },
    {
      'title': 'New PCOS Article Available',
      'message': 'Check out our latest article on managing PCOS symptoms.',
      'audience': 'Active Users',
      'type': 'Health Tip',
      'status': 'Sent',
      'recipients': 856,
      'time': '2 days ago',
      'icon': Icons.article_rounded,
      'color': Colors.blue,
    },
    {
      'title': 'Medication Reminder Feature',
      'message': 'We\'ve added new medication tracking features!',
      'audience': 'All Users',
      'type': 'Update',
      'status': 'Sent',
      'recipients': 1247,
      'time': '3 days ago',
      'icon': Icons.medication_rounded,
      'color': Colors.green,
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[50]!,
            Colors.purple[50]!.withOpacity(0.3),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.purple[400]!, Colors.pink[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Notification Center',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send announcements and health reminders to users',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Stats
            Row(
              children: [
                Expanded(child: _buildStatCard('Total Sent', '${_notifications.length}', Icons.send_rounded, Colors.blue)),
                const SizedBox(width: 12),
                Expanded(child: _buildStatCard('This Week', '12', Icons.calendar_today_rounded, Colors.green)),
              ],
            ),
            const SizedBox(height: 24),

            // Create Notification Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.purple[50]!, Colors.pink[50]!],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.purple[400]!, Colors.pink[400]!],
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.create_rounded, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Compose New Notification',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                'Create and send to your users',
                                style: TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title Field
                        TextField(
                          controller: _titleController,
                          decoration: InputDecoration(
                            labelText: 'Notification Title',
                            hintText: 'Enter a catchy title...',
                            prefixIcon: Icon(Icons.title_rounded, color: Colors.purple[400]),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Message Field
                        TextField(
                          controller: _messageController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Message Content',
                            hintText: 'Write your notification message here...',
                            alignLabelWithHint: true,
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 60),
                              child: Icon(Icons.message_rounded, color: Colors.purple[400]),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: BorderSide(color: Colors.purple[400]!, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Audience and Type Row
                        Row(
                          children: [
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedAudience,
                                    isExpanded: true,
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.purple[400]),
                                    items: _audienceOptions.map((option) => DropdownMenuItem(
                                      value: option,
                                      child: Row(
                                        children: [
                                          Icon(Icons.group_rounded, size: 18, color: Colors.purple[400]),
                                          const SizedBox(width: 10),
                                          Flexible(child: Text(option, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    )).toList(),
                                    onChanged: (value) => setState(() => _selectedAudience = value!),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    value: _selectedType,
                                    isExpanded: true,
                                    icon: Icon(Icons.keyboard_arrow_down_rounded, color: Colors.purple[400]),
                                    items: _typeOptions.map((option) => DropdownMenuItem(
                                      value: option,
                                      child: Row(
                                        children: [
                                          Icon(_getTypeIcon(option), size: 18, color: Colors.purple[400]),
                                          const SizedBox(width: 10),
                                          Flexible(child: Text(option, overflow: TextOverflow.ellipsis)),
                                        ],
                                      ),
                                    )).toList(),
                                    onChanged: (value) => setState(() => _selectedType = value!),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_titleController.text.isNotEmpty && _messageController.text.isNotEmpty) {
                                    setState(() {
                                      _notifications.insert(0, {
                                        'title': _titleController.text,
                                        'message': _messageController.text,
                                        'audience': _selectedAudience,
                                        'type': _selectedType,
                                        'status': 'Sent',
                                        'recipients': _selectedAudience == 'All Users' ? 1247 : 856,
                                        'time': 'Just now',
                                        'icon': _getTypeIcon(_selectedType),
                                        'color': _getTypeColor(_selectedType),
                                      });
                                    });
                                    _titleController.clear();
                                    _messageController.clear();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Row(
                                          children: const [
                                            Icon(Icons.check_circle_rounded, color: Colors.white),
                                            SizedBox(width: 12),
                                            Flexible(child: Text('Notification sent successfully!')),
                                          ],
                                        ),
                                        backgroundColor: Colors.green[600],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.send_rounded),
                                label: const Text('Send Now'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.purple[500],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Notification History
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.history_rounded, color: Colors.blue[600], size: 22),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Notification History',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.purple[50],
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_notifications.length} sent',
                            style: TextStyle(
                              color: Colors.purple[700],
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ..._notifications.map((notif) => _buildNotificationCard(notif)),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Announcement': return Icons.campaign_rounded;
      case 'Health Tip': return Icons.favorite_rounded;
      case 'Reminder': return Icons.alarm_rounded;
      case 'Alert': return Icons.warning_rounded;
      case 'Update': return Icons.system_update_rounded;
      default: return Icons.notifications_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Announcement': return Colors.pink;
      case 'Health Tip': return Colors.red;
      case 'Reminder': return Colors.blue;
      case 'Alert': return Colors.orange;
      case 'Update': return Colors.green;
      default: return Colors.purple;
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notif) {
    final color = notif['color'] as Color? ?? Colors.purple;
    final icon = notif['icon'] as IconData? ?? Icons.notifications_rounded;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        notif['title'] ?? '',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notif['status'] ?? 'Sent',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  notif['message'] ?? notif['subtitle'] ?? '',
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.group_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          '${notif['recipients'] ?? 0} recipients',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded, size: 14, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          notif['time'] ?? '',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notif['type'] ?? 'Notification',
                        style: TextStyle(
                          fontSize: 10,
                          color: color,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: Colors.grey[400], size: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'resend', child: Row(
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Resend'),
                ],
              )),
              const PopupMenuItem(value: 'view', child: Row(
                children: [
                  Icon(Icons.visibility_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('View Details'),
                ],
              )),
              const PopupMenuItem(value: 'delete', child: Row(
                children: [
                  Icon(Icons.delete_rounded, size: 18, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              )),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                setState(() {
                  _notifications.remove(notif);
                });
              }
            },
          ),
        ],
      ),
    );
  }
}

// System Logs Screen
class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'User', 'Content', 'System', 'Error'];
  
  final List<Map<String, dynamic>> _logs = [
    {
      'level': 'USER',
      'message': 'Sarah Johnson registered a new account',
      'details': 'Email: sarah@example.com | City: Floridablanca',
      'time': '10:24 AM',
      'date': 'Today',
      'icon': Icons.person_add_rounded,
      'color': Colors.blue,
    },
    {
      'level': 'CONTENT',
      'message': 'New article published: PCOS Management Guide',
      'details': 'Author: Admin | Category: Health',
      'time': '10:15 AM',
      'date': 'Today',
      'icon': Icons.article_rounded,
      'color': Colors.orange,
    },
    {
      'level': 'SYSTEM',
      'message': 'Health reminder sent to 856 users',
      'details': 'Notification type: Push | Success rate: 98.2%',
      'time': '09:47 AM',
      'date': 'Today',
      'icon': Icons.notifications_rounded,
      'color': Colors.purple,
    },
    {
      'level': 'USER',
      'message': 'Maria Santos logged in',
      'details': 'Device: Android | Location: San Fernando',
      'time': '09:32 AM',
      'date': 'Today',
      'icon': Icons.login_rounded,
      'color': Colors.green,
    },
    {
      'level': 'CONTENT',
      'message': 'Forum post approved by moderator',
      'details': 'Post ID: #4521 | Topic: Symptoms Discussion',
      'time': '09:18 AM',
      'date': 'Today',
      'icon': Icons.check_circle_rounded,
      'color': Colors.green,
    },
    {
      'level': 'ERROR',
      'message': 'Failed login attempt detected',
      'details': 'IP: 192.168.1.xxx | Attempts: 3',
      'time': '08:55 AM',
      'date': 'Today',
      'icon': Icons.error_rounded,
      'color': Colors.red,
    },
    {
      'level': 'SYSTEM',
      'message': 'Database backup completed',
      'details': 'Size: 245 MB | Duration: 2.3s',
      'time': '08:00 AM',
      'date': 'Today',
      'icon': Icons.backup_rounded,
      'color': Colors.teal,
    },
    {
      'level': 'USER',
      'message': 'Anna Garcia updated her profile',
      'details': 'Changed: Height, Weight, Age',
      'time': '11:45 PM',
      'date': 'Yesterday',
      'icon': Icons.edit_rounded,
      'color': Colors.blue,
    },
  ];

  List<Map<String, dynamic>> get _filteredLogs {
    if (_selectedFilter == 'All') return _logs;
    return _logs.where((log) => 
      log['level'].toString().toUpperCase() == _selectedFilter.toUpperCase()
    ).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.grey[50]!,
            Colors.blue[50]!.withOpacity(0.3),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue[500]!, Colors.indigo[500]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'System Logs',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Real-time activity and performance monitoring',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.analytics_rounded, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Stats Row
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SizedBox(width: 160, child: _buildStatCard('Active Now', '342', Icons.people_rounded, Colors.blue, '+12%')),
                  const SizedBox(width: 12),
                  SizedBox(width: 160, child: _buildStatCard('Today Visits', '1.2K', Icons.visibility_rounded, Colors.green, '+8%')),
                  const SizedBox(width: 12),
                  SizedBox(width: 160, child: _buildStatCard('Events', '${_logs.length}', Icons.event_note_rounded, Colors.purple, '')),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Activity Logs Section
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Header with filters
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue[50]!, Colors.indigo[50]!],
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[400]!, Colors.indigo[400]!],
                                ),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.history_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Activity Timeline',
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'All system events and user actions',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.blue[100],
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.circle, size: 8, color: Colors.green[600]),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Live',
                                    style: TextStyle(
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Filter chips
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: _filters.map((filter) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilterChip(
                                label: Text(filter),
                                selected: _selectedFilter == filter,
                                onSelected: (selected) {
                                  setState(() => _selectedFilter = filter);
                                },
                                selectedColor: Colors.blue[100],
                                checkmarkColor: Colors.blue[700],
                                labelStyle: TextStyle(
                                  color: _selectedFilter == filter ? Colors.blue[700] : Colors.grey[700],
                                  fontWeight: _selectedFilter == filter ? FontWeight.w600 : FontWeight.normal,
                                ),
                                backgroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  side: BorderSide(
                                    color: _selectedFilter == filter ? Colors.blue[300]! : Colors.grey[300]!,
                                  ),
                                ),
                              ),
                            )).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Logs list
                  ..._buildGroupedLogs(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedLogs() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final log in _filteredLogs) {
      final date = log['date'] as String;
      grouped.putIfAbsent(date, () => []);
      grouped[date]!.add(log);
    }

    final widgets = <Widget>[];
    grouped.forEach((date, logs) {
      widgets.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  date,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Divider(color: Colors.grey[200])),
            ],
          ),
        ),
      );
      for (final log in logs) {
        widgets.add(_buildLogCard(log));
      }
    });

    return widgets;
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String growth) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              if (growth.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.trending_up_rounded, size: 10, color: Colors.green[600]),
                      const SizedBox(width: 2),
                      Text(growth, style: TextStyle(fontSize: 9, color: Colors.green[600], fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(Map<String, dynamic> log) {
    final color = log['color'] as Color;
    final icon = log['icon'] as IconData;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => _showLogDetails(log),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              // Timeline indicator
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            log['level'] as String,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                        const SizedBox(width: 4),
                        Text(
                          log['time'] as String,
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      log['message'] as String,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log['details'] as String,
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogDetails(Map<String, dynamic> log) {
    final color = log['color'] as Color;
    final icon = log['icon'] as IconData;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withOpacity(0.2), color.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(icon, color: color, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                log['level'] as String,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: color,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              log['message'] as String,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailRow(Icons.info_outline_rounded, 'Details', log['details'] as String),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today_rounded, 'Date', log['date'] as String),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.access_time_rounded, 'Time', log['time'] as String),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        foregroundColor: Colors.grey[800],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Doctor Management Screen
class DoctorManagementScreen extends StatefulWidget {
  const DoctorManagementScreen({super.key});

  @override
  State<DoctorManagementScreen> createState() => _DoctorManagementScreenState();
}

class _DoctorManagementScreenState extends State<DoctorManagementScreen> {
  String _selectedSpecialty = 'All';
  String _searchQuery = '';
  
  static const List<String> specialties = ['All', 'Gynecologist', 'Endocrinologist', 'Dermatologist', 'Nutritionist'];
  
  final List<Doctor> _doctors = [
    Doctor(
      id: 1,
      name: 'Dr. Maria Santos',
      specialty: 'Gynecologist',
      hospital: 'Florida Blanca District Hospital',
      rating: 4.9,
      reviews: 156,
      experience: '18 years',
      phone: '+63-45-625-1234',
      email: 'maria.santos@fbdh.gov.ph',
      isPcosSpecialist: true,
      availability: 'Mon-Fri: 9AM-5PM',
      languages: ['Filipino', 'English'],
      education: 'UP College of Medicine',
    ),
    Doctor(
      id: 2,
      name: 'Dr. Jose Reyes',
      specialty: 'Endocrinologist',
      hospital: 'Pampanga Medical Specialists',
      rating: 4.8,
      reviews: 142,
      experience: '15 years',
      phone: '+63-45-625-5678',
      email: 'jose.reyes@pampangamed.com',
      isPcosSpecialist: true,
      availability: 'Mon, Wed, Fri: 8AM-4PM',
      languages: ['Filipino', 'English'],
      education: 'UST Faculty of Medicine',
    ),
  ];

  List<Doctor> get _filteredDoctors {
    return _doctors.where((d) {
      final matchesSearch = d.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.hospital.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesSpecialty = _selectedSpecialty == 'All' || d.specialty == _selectedSpecialty;
      return matchesSearch && matchesSpecialty;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[50],
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.red[400]!, Colors.pink[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Doctor Management',
                        style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Add, edit, and manage healthcare providers',
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Doctor'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _showDoctorEditor(),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Stats Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[400]!, Colors.pink[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.local_hospital, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        '${_doctors.length} Doctors',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.verified, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        '${_doctors.where((d) => d.isPcosSpecialist).length} PCOS Specialists',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.star, color: Colors.white, size: 24),
                      const SizedBox(height: 8),
                      Text(
                        'Avg Rating: ${(_doctors.isNotEmpty ? (_doctors.fold(0.0, (sum, d) => sum + d.rating) / _doctors.length).toStringAsFixed(1) : '0')}',
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Filters
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Specialty', style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: specialties.map((specialty) {
                            final isSelected = _selectedSpecialty == specialty;
                            return Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                selected: isSelected,
                                label: Text(specialty),
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : Colors.red[700],
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 11,
                                ),
                                backgroundColor: Colors.red[50],
                                selectedColor: Colors.red[400],
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                visualDensity: VisualDensity.compact,
                                onSelected: (_) => setState(() => _selectedSpecialty = specialty),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Search
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search doctors by name or hospital...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
            const SizedBox(height: 24),
            
            // Doctors List
            Row(
              children: [
                const Text('All Doctors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const Spacer(),
                Text('${_filteredDoctors.length} doctors', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
              ],
            ),
            const SizedBox(height: 16),
            
            ..._filteredDoctors.map((doctor) => _buildDoctorCard(doctor)).toList(),
            
            if (_filteredDoctors.isEmpty)
              Container(
                padding: const EdgeInsets.all(40),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.local_hospital_outlined, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No doctors found',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorCard(Doctor doctor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.local_hospital,
                color: Colors.red[600],
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doctor.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doctor.isPcosSpecialist)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.green[100],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'PCOS Specialist',
                              style: TextStyle(fontSize: 10, color: Colors.green[700], fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${doctor.specialty} • ${doctor.hospital}',
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.yellow[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star, color: Colors.amber[600], size: 12),
                            const SizedBox(width: 4),
                            Text(
                              '${doctor.rating} (${doctor.reviews} reviews)',
                              style: TextStyle(fontSize: 10, color: Colors.amber[800], fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${doctor.experience} exp',
                          style: TextStyle(fontSize: 10, color: Colors.blue[700]),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: Colors.grey[600], size: 20),
                  onSelected: (value) => _handleDoctorAction(value, doctor),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'view', child: Row(children: [Icon(Icons.visibility, size: 18), SizedBox(width: 8), Text('View')])),
                    const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit')])),
                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.red))])),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleDoctorAction(String action, Doctor doctor) {
    switch (action) {
      case 'view':
        _showDoctorDetail(doctor);
        break;
      case 'edit':
        _showDoctorEditor(doctor: doctor);
        break;
      case 'delete':
        _showDeleteDialog(doctor);
        break;
    }
  }

  void _showDoctorDetail(Doctor doctor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red[100]!, Colors.pink[100]!],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.local_hospital,
                      color: Colors.red[600],
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctor.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          doctor.specialty,
                          style: TextStyle(color: Colors.red[600], fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              
              _buildDetailSection('Contact Information', [
                _buildDetailRow(Icons.phone, 'Phone', doctor.phone),
                _buildDetailRow(Icons.email, 'Email', doctor.email),
                _buildDetailRow(Icons.location_on, 'Hospital', doctor.hospital),
              ]),
              const SizedBox(height: 16),
              
              _buildDetailSection('Professional Details', [
                _buildDetailRow(Icons.school, 'Education', doctor.education),
                _buildDetailRow(Icons.work, 'Experience', doctor.experience),
                _buildDetailRow(Icons.schedule, 'Availability', doctor.availability),
              ]),
              const SizedBox(height: 16),
              
              _buildDetailSection('Additional Information', [
                _buildDetailRow(Icons.star, 'Rating', '${doctor.rating} (${doctor.reviews} reviews)'),
                _buildDetailRow(Icons.language, 'Languages', doctor.languages.join(', ')),
              ]),
              const SizedBox(height: 16),
              
              if (doctor.isPcosSpecialist) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.green[600]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Certified PCOS Specialist',
                          style: TextStyle(color: Colors.green[700], fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit Doctor'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDoctorEditor(doctor: doctor);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showDeleteDialog(doctor);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const Spacer(),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  void _showDoctorEditor({Doctor? doctor}) {
    final isEditing = doctor != null;
    final nameController = TextEditingController(text: doctor?.name ?? '');
    final specialtyController = TextEditingController(text: doctor?.specialty ?? 'Gynecologist');
    final hospitalController = TextEditingController(text: doctor?.hospital ?? '');
    final phoneController = TextEditingController(text: doctor?.phone ?? '');
    final emailController = TextEditingController(text: doctor?.email ?? '');
    final experienceController = TextEditingController(text: doctor?.experience ?? '');
    final educationController = TextEditingController(text: doctor?.education ?? '');
    final availabilityController = TextEditingController(text: doctor?.availability ?? 'Mon-Fri: 9AM-5PM');
    final languagesController = TextEditingController(text: doctor?.languages.join(', ') ?? 'Filipino, English');
    late double ratingController;
    late int reviewsController;
    bool isPcosSpecialist = doctor?.isPcosSpecialist ?? false;
    
    if (doctor != null) {
      ratingController = doctor.rating;
      reviewsController = doctor.reviews;
    } else {
      ratingController = 4.5;
      reviewsController = 0;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          height: MediaQuery.of(context).size.height * 0.95,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red[400]!, Colors.pink[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.local_hospital, color: Colors.white, size: 28),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isEditing ? 'Edit Doctor' : 'Add New Doctor',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const Text(
                            'Fill in doctor details',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader('Basic Information'),
                      const SizedBox(height: 16),
                      _buildTextField(nameController, 'Name *', 'Dr. Full Name'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: specialtyController.text,
                              decoration: InputDecoration(
                                labelText: 'Specialty *',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: ['Gynecologist', 'Endocrinologist', 'Dermatologist', 'Nutritionist'].map((s) =>
                                DropdownMenuItem(value: s, child: Text(s))
                              ).toList(),
                              onChanged: (v) => setModalState(() => specialtyController.text = v!),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildTextField(hospitalController, 'Hospital *', 'Hospital name'),
                      const SizedBox(height: 24),
                      
                      _buildSectionHeader('Contact Information'),
                      const SizedBox(height: 16),
                      _buildTextField(phoneController, 'Phone *', '+63-...'),
                      const SizedBox(height: 16),
                      _buildTextField(emailController, 'Email *', 'doctor@email.com'),
                      const SizedBox(height: 24),
                      
                      _buildSectionHeader('Professional Details'),
                      const SizedBox(height: 16),
                      _buildTextField(educationController, 'Education', 'University name'),
                      const SizedBox(height: 16),
                      _buildTextField(experienceController, 'Experience', '15 years'),
                      const SizedBox(height: 16),
                      _buildTextField(availabilityController, 'Availability', 'Mon-Fri: 9AM-5PM'),
                      const SizedBox(height: 16),
                      _buildTextField(languagesController, 'Languages', 'Filipino, English'),
                      const SizedBox(height: 24),
                      
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isPcosSpecialist ? Colors.green[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isPcosSpecialist ? Colors.green[300]! : Colors.grey[200]!,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isPcosSpecialist ? Icons.verified_user : Icons.check_box_outline_blank,
                              color: isPcosSpecialist ? Colors.green[600] : Colors.grey[600],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('PCOS Specialist', style: TextStyle(fontWeight: FontWeight.w600)),
                                  Text(
                                    'Mark if this doctor specializes in PCOS treatment',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: isPcosSpecialist,
                              onChanged: (v) => setModalState(() => isPcosSpecialist = v),
                              activeColor: Colors.green[600],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          onPressed: () {
                            if (nameController.text.isEmpty || hospitalController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Name and hospital are required'), backgroundColor: Colors.red),
                              );
                              return;
                            }
                            
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 12),
                                  Text(isEditing ? 'Doctor updated' : 'Doctor added'),
                                ]),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          },
                          child: Text(
                            isEditing ? 'Save Changes' : 'Add Doctor',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.red[400],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, String hint, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red[400]!, width: 2),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }

  void _showDeleteDialog(Doctor doctor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 12),
            Text('Delete Doctor'),
          ],
        ),
        content: Text('Are you sure you want to delete ${doctor.name}? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              setState(() => _doctors.remove(doctor));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Doctor deleted'), behavior: SnackBarBehavior.floating),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Doctor Model
class Doctor {
  final int id;
  final String name;
  final String specialty;
  final String hospital;
  final double rating;
  final int reviews;
  final String experience;
  final String phone;
  final String email;
  final bool isPcosSpecialist;
  final String availability;
  final List<String> languages;
  final String education;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.hospital,
    required this.rating,
    required this.reviews,
    required this.experience,
    required this.phone,
    required this.email,
    this.isPcosSpecialist = false,
    this.availability = 'Mon-Fri: 9AM-5PM',
    this.languages = const ['Filipino', 'English'],
    this.education = '',
  });
}

// Feedback & Support Screen
class FeedbackSupportScreen extends StatefulWidget {
  const FeedbackSupportScreen({super.key});

  @override
  State<FeedbackSupportScreen> createState() => _FeedbackSupportScreenState();
}

class _FeedbackSupportScreenState extends State<FeedbackSupportScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _selectedFilter = 'All';
  final List<String> _filters = ['All', 'Open', 'In Progress', 'Resolved'];

  final List<Map<String, dynamic>> _feedback = [
    {
      'id': 1,
      'message': 'App is very helpful for tracking my cycle!',
      'type': 'User feedback',
      'status': 'Open',
      'user': 'Maria Santos',
      'email': 'maria@email.com',
      'date': 'Feb 15, 2026',
      'priority': 'Low',
    },
    {
      'id': 2,
      'message': 'Notification feature not working on Android',
      'type': 'Bug report',
      'status': 'In Progress',
      'user': 'Anna Cruz',
      'email': 'anna@email.com',
      'date': 'Feb 14, 2026',
      'priority': 'High',
    },
    {
      'id': 3,
      'message': 'Please add dark mode support',
      'type': 'Feature request',
      'status': 'Resolved',
      'user': 'Lisa Reyes',
      'email': 'lisa@email.com',
      'date': 'Feb 13, 2026',
      'priority': 'Medium',
    },
    {
      'id': 4,
      'message': 'Love the symptom tracking features!',
      'type': 'User feedback',
      'status': 'Open',
      'user': 'Sofia Garcia',
      'email': 'sofia@email.com',
      'date': 'Feb 12, 2026',
      'priority': 'Low',
    },
    {
      'id': 5,
      'message': 'App crashes when viewing recipes',
      'type': 'Bug report',
      'status': 'Open',
      'user': 'Carmen Lopez',
      'email': 'carmen@email.com',
      'date': 'Feb 11, 2026',
      'priority': 'High',
    },
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredFeedback {
    if (_selectedFilter == 'All') return _feedback;
    return _feedback.where((f) => f['status'] == _selectedFilter).toList();
  }

  int get _openCount => _feedback.where((f) => f['status'] == 'Open').length;
  int get _resolvedCount => _feedback.where((f) => f['status'] == 'Resolved').length;
  int get _pendingCount => _feedback.where((f) => f['status'] == 'In Progress').length;

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Bug report':
        return Icons.bug_report_rounded;
      case 'Feature request':
        return Icons.lightbulb_rounded;
      default:
        return Icons.chat_bubble_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Bug report':
        return Colors.red;
      case 'Feature request':
        return Colors.purple;
      default:
        return Colors.blue;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Open':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with gradient
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal[400]!, Colors.cyan[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 18),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Feedback & Support',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage user feedback and support requests',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Stats Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildStatCard('Open', _openCount.toString(), Icons.inbox_rounded, Colors.blue, 'Needs attention'),
                    const SizedBox(width: 12),
                    _buildStatCard('In Progress', _pendingCount.toString(), Icons.pending_rounded, Colors.orange, 'Being handled'),
                    const SizedBox(width: 12),
                    _buildStatCard('Resolved', _resolvedCount.toString(), Icons.check_circle_rounded, Colors.green, 'Completed'),
                    const SizedBox(width: 12),
                    _buildStatCard('Total', _feedback.length.toString(), Icons.folder_rounded, Colors.purple, 'All time'),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Feedback List Section
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Header with filters
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.teal[50]!, Colors.cyan[50]!],
                        ),
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.teal[400]!, Colors.cyan[400]!],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.feedback_rounded, color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'All Feedback',
                                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      '${_filteredFeedback.length} items',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Filter chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: _filters.map((filter) => Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: FilterChip(
                                  label: Text(filter),
                                  selected: _selectedFilter == filter,
                                  onSelected: (selected) {
                                    setState(() => _selectedFilter = filter);
                                  },
                                  selectedColor: Colors.teal[100],
                                  checkmarkColor: Colors.teal[700],
                                  labelStyle: TextStyle(
                                    color: _selectedFilter == filter ? Colors.teal[700] : Colors.grey[600],
                                    fontWeight: _selectedFilter == filter ? FontWeight.w600 : FontWeight.normal,
                                  ),
                                ),
                              )).toList(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Feedback list
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredFeedback.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) => _buildFeedbackCard(_filteredFeedback[index]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, String subtitle) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackCard(Map<String, dynamic> item) {
    final typeColor = _getTypeColor(item['type']);
    final statusColor = _getStatusColor(item['status']);
    final priorityColor = _getPriorityColor(item['priority']);
    final typeIcon = _getTypeIcon(item['type']);

    return InkWell(
      onTap: () => _showFeedbackDetails(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(typeIcon, color: typeColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item['user'],
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['type'],
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item['status'],
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.flag_rounded, size: 10, color: priorityColor),
                        const SizedBox(width: 4),
                        Text(
                          item['priority'],
                          style: TextStyle(fontSize: 10, color: priorityColor, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              item['message'],
              style: const TextStyle(fontSize: 13),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey[400]),
                const SizedBox(width: 6),
                Text(
                  item['date'],
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                const Spacer(),
                if (item['status'] != 'Resolved')
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        item['status'] = item['status'] == 'Open' ? 'In Progress' : 'Resolved';
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.white, size: 18),
                              const SizedBox(width: 8),
                              Flexible(child: Text('Status updated to ${item['status']}')),
                            ],
                          ),
                          backgroundColor: Colors.teal,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      );
                    },
                    icon: Icon(
                      item['status'] == 'Open' ? Icons.play_arrow_rounded : Icons.check_rounded,
                      size: 16,
                    ),
                    label: Text(item['status'] == 'Open' ? 'Start' : 'Resolve'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.teal,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFeedbackDetails(Map<String, dynamic> item) {
    final typeColor = _getTypeColor(item['type']);
    final statusColor = _getStatusColor(item['status']);
    final priorityColor = _getPriorityColor(item['priority']);
    final typeIcon = _getTypeIcon(item['type']);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(typeIcon, color: typeColor, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['type'],
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['user'],
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          item['status'],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      item['message'],
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildDetailRow(Icons.email_rounded, 'Email', item['email']),
                  const SizedBox(height: 12),
                  _buildDetailRow(Icons.calendar_today_rounded, 'Date', item['date']),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.flag_rounded, size: 20, color: priorityColor),
                        const SizedBox(width: 12),
                        Text(
                          'Priority',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: priorityColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['priority'],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (item['status'] != 'Resolved')
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                item['status'] = item['status'] == 'Open' ? 'In Progress' : 'Resolved';
                              });
                            },
                            icon: Icon(item['status'] == 'Open' ? Icons.play_arrow_rounded : Icons.check_rounded),
                            label: Text(item['status'] == 'Open' ? 'Start Working' : 'Mark Resolved'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.teal,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey[100],
                            foregroundColor: Colors.grey[800],
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Close'),
                        ),
                      ],
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                          foregroundColor: Colors.grey[800],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Close'),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// Profile Screen
class ProfileScreen extends StatefulWidget {
  final String adminName;
  const ProfileScreen({super.key, required this.adminName});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward();
    _nameController.text = 'System Administrator';
    _emailController.text = 'admin@ovacare.com';
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Container(
        color: Colors.grey[50],
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Modern Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple[400]!, Colors.pink[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.deepPurple.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              'SA',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.deepPurple,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.adminName,
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified, color: Colors.white, size: 14),
                                    SizedBox(width: 4),
                                    Text(
                                      'System Administrator',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.circle, size: 8, color: Colors.green[300]),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Online',
                                    style: TextStyle(fontSize: 12, color: Colors.white70),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Stats Row
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildProfileStat('Sessions', '248', Icons.login_rounded),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _buildProfileStat('Actions', '1.2K', Icons.touch_app_rounded),
                          Container(width: 1, height: 40, color: Colors.white24),
                          _buildProfileStat('Days', '142', Icons.calendar_today_rounded),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Quick Stats Cards
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickStatCard('Last Login', 'Today, 9:30 AM', Icons.access_time_rounded, Colors.blue),
                    const SizedBox(width: 12),
                    _buildQuickStatCard('Account Created', 'Jan 15, 2025', Icons.cake_rounded, Colors.orange),
                    const SizedBox(width: 12),
                    _buildQuickStatCard('Security', 'Strong', Icons.shield_rounded, Colors.green),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Account Section
            _buildSectionCard(
              title: 'Account Information',
              titleIcon: Icons.person_outline,
              trailing: TextButton.icon(
                icon: Icon(_isEditing ? Icons.close : Icons.edit, size: 16),
                label: Text(_isEditing ? 'Cancel' : 'Edit'),
                onPressed: () => setState(() => _isEditing = !_isEditing),
              ),
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'Full Name',
                  icon: Icons.person_outline,
                  enabled: _isEditing,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  enabled: _isEditing,
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  label: 'Username',
                  icon: Icons.account_circle_outlined,
                  hint: widget.adminName,
                  enabled: false,
                ),
                if (_isEditing) ...[
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() => _isEditing = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Profile updated successfully'),
                              ],
                            ),
                            backgroundColor: Colors.deepPurple,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        );
                      },
                      child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // Security Section
            _buildSectionCard(
              title: 'Security',
              titleIcon: Icons.shield_outlined,
              children: [
                _buildActionTile(
                  icon: Icons.lock_outline,
                  title: 'Change Password',
                  subtitle: 'Update your password regularly',
                  iconColor: Colors.orange,
                  bgColor: Colors.orange,
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preferences Section
            _buildSectionCard(
              title: 'Preferences',
              titleIcon: Icons.tune,
              children: [
                _buildActionTile(
                  icon: Icons.notifications_outlined,
                  title: 'Notification Settings',
                  subtitle: 'Manage alert preferences',
                  iconColor: Colors.purple,
                  bgColor: Colors.purple,
                  onTap: () => _showNotificationSettings(context),
                ),
                _buildActionTile(
                  icon: Icons.privacy_tip_outlined,
                  title: 'Privacy & Security',
                  subtitle: 'Data and session settings',
                  iconColor: Colors.teal,
                  bgColor: Colors.teal,
                  onTap: () => _showPrivacySettings(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Support Section
            _buildSectionCard(
              title: 'Support',
              titleIcon: Icons.help_outline,
              children: [
                _buildActionTile(
                  icon: Icons.support_agent,
                  title: 'Help & Support',
                  subtitle: 'Get help and documentation',
                  iconColor: Colors.green,
                  bgColor: Colors.green,
                  onTap: () => _showHelpDialog(context),
                ),
                _buildActionTile(
                  icon: Icons.info_outline,
                  title: 'About Admin Panel',
                  subtitle: 'Version and system info',
                  iconColor: Colors.grey,
                  bgColor: Colors.grey,
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    ));
  }

  Widget _buildProfileStat(String label, String value, IconData icon) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData titleIcon,
    Widget? trailing,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.deepPurple.withOpacity(0.1), Colors.pink.withOpacity(0.1)],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(titleIcon, size: 18, color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    TextEditingController? controller,
    required String label,
    required IconData icon,
    String? hint,
    bool enabled = true,
  }) {
    return TextField(
      controller: controller,
      enabled: enabled,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: enabled ? Colors.deepPurple : Colors.grey),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.deepPurple, width: 2),
        ),
        filled: !enabled,
        fillColor: Colors.grey[100],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            bgColor.withOpacity(0.05),
            bgColor.withOpacity(0.02),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withOpacity(0.1)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [iconColor, iconColor.withOpacity(0.8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: iconColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.chevron_right, color: Colors.grey[600], size: 20),
        ),
        onTap: onTap,
      ),
    );
  }

  // Change Password Dialog
  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    double passwordStrength = 0;
    String strengthText = '';
    Color strengthColor = Colors.grey;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          void updatePasswordStrength(String password) {
            double strength = 0;
            if (password.length >= 8) strength += 0.25;
            if (password.contains(RegExp(r'[A-Z]'))) strength += 0.25;
            if (password.contains(RegExp(r'[0-9]'))) strength += 0.25;
            if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength += 0.25;
            
            String text = '';
            Color color = Colors.grey;
            if (strength <= 0.25) {
              text = 'Weak';
              color = Colors.red;
            } else if (strength <= 0.5) {
              text = 'Fair';
              color = Colors.orange;
            } else if (strength <= 0.75) {
              text = 'Good';
              color = Colors.yellow[700]!;
            } else {
              text = 'Strong';
              color = Colors.green;
            }
            
            setModalState(() {
              passwordStrength = strength;
              strengthText = text;
              strengthColor = color;
            });
          }

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange, Colors.orange[700]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Change Password',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Use a strong password with at least 8 characters',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPasswordField(
                          controller: currentPasswordController,
                          label: 'Current Password',
                          obscure: obscureCurrent,
                          onToggle: () => setModalState(() => obscureCurrent = !obscureCurrent),
                        ),
                        const SizedBox(height: 20),
                        _buildPasswordField(
                          controller: newPasswordController,
                          label: 'New Password',
                          obscure: obscureNew,
                          onToggle: () => setModalState(() => obscureNew = !obscureNew),
                          onChanged: updatePasswordStrength,
                        ),
                        const SizedBox(height: 12),
                        
                        // Password Strength Indicator
                        if (newPasswordController.text.isNotEmpty) ...[
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: passwordStrength,
                                    backgroundColor: Colors.grey[200],
                                    valueColor: AlwaysStoppedAnimation<Color>(strengthColor),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                strengthText,
                                style: TextStyle(
                                  color: strengthColor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _buildRequirement('8+ chars', newPasswordController.text.length >= 8),
                              _buildRequirement('Uppercase', newPasswordController.text.contains(RegExp(r'[A-Z]'))),
                              _buildRequirement('Number', newPasswordController.text.contains(RegExp(r'[0-9]'))),
                              _buildRequirement('Symbol', newPasswordController.text.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))),
                            ],
                          ),
                        ],
                        
                        const SizedBox(height: 20),
                        _buildPasswordField(
                          controller: confirmPasswordController,
                          label: 'Confirm New Password',
                          obscure: obscureConfirm,
                          onToggle: () => setModalState(() => obscureConfirm = !obscureConfirm),
                        ),
                        const SizedBox(height: 32),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (newPasswordController.text != confirmPasswordController.text) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Passwords do not match'),
                                    backgroundColor: Colors.red[600],
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Row(
                                    children: [
                                      Icon(Icons.check_circle, color: Colors.white),
                                      SizedBox(width: 12),
                                      Text('Password changed successfully'),
                                    ],
                                  ),
                                  backgroundColor: Colors.green[600],
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              );
                            },
                            child: const Text(
                              'Update Password',
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
    Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.orange, width: 2),
        ),
      ),
    );
  }

  Widget _buildRequirement(String text, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green[700] : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.blue, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Notification Settings
  void _showNotificationSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<SettingsProvider>(
        builder: (context, settings, child) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.purple, Colors.purple[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notification Settings',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage your alert preferences',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Quick Toggle
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: settings.allNotificationsEnabled
                        ? [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)]
                        : [Colors.grey.withOpacity(0.1), Colors.grey.withOpacity(0.05)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: settings.allNotificationsEnabled
                        ? Colors.green.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: settings.allNotificationsEnabled ? Colors.green : Colors.grey,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        settings.allNotificationsEnabled
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'All Notifications',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          Text(
                            settings.allNotificationsEnabled ? 'Enabled' : 'Disabled',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: settings.allNotificationsEnabled,
                      onChanged: (value) => settings.setAllNotifications(value),
                      activeColor: Colors.green,
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Admin Alerts',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildNotificationTile(
                        icon: Icons.warning_amber,
                        title: 'System Notifications',
                        subtitle: 'Critical system alerts',
                        value: settings.systemNotifications,
                        onChanged: (v) => settings.setSystemNotifications(v),
                        color: Colors.red,
                      ),
                      _buildNotificationTile(
                        icon: Icons.flag,
                        title: 'User Reports',
                        subtitle: 'Content and user reports',
                        value: settings.userReportAlerts,
                        onChanged: (v) => settings.setUserReportAlerts(v),
                        color: Colors.orange,
                      ),
                      _buildNotificationTile(
                        icon: Icons.person_add,
                        title: 'New User Alerts',
                        subtitle: 'New user registrations',
                        value: settings.newUserAlerts,
                        onChanged: (v) => settings.setNewUserAlerts(v),
                        color: Colors.blue,
                      ),
                      _buildNotificationTile(
                        icon: Icons.article,
                        title: 'Content Alerts',
                        subtitle: 'New content requiring review',
                        value: settings.contentAlerts,
                        onChanged: (v) => settings.setContentAlerts(v),
                        color: Colors.purple,
                      ),
                      _buildNotificationTile(
                        icon: Icons.security,
                        title: 'Security Alerts',
                        subtitle: 'Login attempts and threats',
                        value: settings.securityAlerts,
                        onChanged: (v) => settings.setSecurityAlerts(v),
                        color: Colors.teal,
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Delivery',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildNotificationTile(
                        icon: Icons.email,
                        title: 'Email Notifications',
                        subtitle: 'Receive alerts via email',
                        value: settings.emailNotifications,
                        onChanged: (v) => settings.setEmailNotifications(v),
                        color: Colors.indigo,
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildNotificationTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? color.withOpacity(0.15) : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: value ? color : Colors.grey, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  // Privacy Settings
  void _showPrivacySettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Consumer<SettingsProvider>(
        builder: (context, settings, child) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.teal, Colors.teal[700]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Privacy & Security',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Manage data and session settings',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Security Status
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.withOpacity(0.1), Colors.green.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.verified_user, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Security Status: Good',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Your admin account is secure',
                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      const Text(
                        'Session',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildPrivacyTile(
                        icon: Icons.timer,
                        title: 'Session Timeout',
                        subtitle: 'Auto logout after inactivity',
                        value: settings.sessionTimeout,
                        onChanged: (v) => settings.setSessionTimeout(v),
                        color: Colors.blue,
                      ),
                      _buildPrivacyTile(
                        icon: Icons.history,
                        title: 'Activity Logging',
                        subtitle: 'Log admin actions',
                        value: settings.activityLogging,
                        onChanged: (v) => settings.setActivityLogging(v),
                        color: Colors.purple,
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Data',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildPrivacyTile(
                        icon: Icons.analytics_outlined,
                        title: 'Analytics',
                        subtitle: 'Usage analytics collection',
                        value: settings.analyticsEnabled,
                        onChanged: (v) => settings.setAnalyticsEnabled(v),
                        color: Colors.teal,
                      ),
                      
                      const SizedBox(height: 24),
                      const Text(
                        'Data Management',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 12),
                      _buildDataTile(
                        icon: Icons.download,
                        title: 'Export Activity Log',
                        subtitle: 'Download your admin activity',
                        color: Colors.indigo,
                        onTap: () async {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exporting activity log...')),
                          );
                          await settings.exportActivityLog();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Activity log exported'),
                                  ],
                                ),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      _buildDataTile(
                        icon: Icons.refresh,
                        title: 'Reset Settings',
                        subtitle: 'Reset to default preferences',
                        color: Colors.orange,
                        onTap: () async {
                          await settings.resetToDefaults();
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Row(
                                  children: [
                                    Icon(Icons.check_circle, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('Settings reset to defaults'),
                                  ],
                                ),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),
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

  Widget _buildPrivacyTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: value ? color.withOpacity(0.05) : Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: value ? color.withOpacity(0.2) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: value ? color.withOpacity(0.15) : Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: value ? color : Colors.grey, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildDataTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        trailing: Icon(Icons.chevron_right, color: Colors.grey[400]),
      ),
    );
  }

  // Help Dialog
  void _showHelpDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green, Colors.green[700]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help & Support',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Get help with admin panel',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
            ),
            
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Contact Cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildContactCard(
                            icon: Icons.email_outlined,
                            title: 'Email',
                            subtitle: 'support@ovacare.com',
                            color: Colors.blue,
                            onTap: () => _launchUrl('mailto:support@ovacare.com'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildContactCard(
                            icon: Icons.chat_bubble_outline,
                            title: 'Live Chat',
                            subtitle: 'Available 24/7',
                            color: Colors.green,
                            onTap: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Live chat opening...')),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Frequently Asked Questions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _buildFaqTile(
                      question: 'How do I manage user accounts?',
                      answer: 'Navigate to the Users section from the sidebar. You can view, edit, suspend, or delete user accounts from there.',
                    ),
                    _buildFaqTile(
                      question: 'How do I moderate content?',
                      answer: 'Go to the Forum section to view all posts. Use the moderation tools to approve, flag, or remove inappropriate content.',
                    ),
                    _buildFaqTile(
                      question: 'How do I view analytics?',
                      answer: 'The Dashboard shows key metrics. For detailed analytics, check the Analytics section in the sidebar.',
                    ),
                    _buildFaqTile(
                      question: 'How do I export data?',
                      answer: 'Use the Export feature in relevant sections. You can export user data, activity logs, and reports in CSV format.',
                    ),
                    const SizedBox(height: 24),
                    
                    const Text(
                      'Resources',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 12),
                    _buildResourceTile(
                      icon: Icons.menu_book,
                      title: 'Admin Documentation',
                      color: Colors.indigo,
                    ),
                    _buildResourceTile(
                      icon: Icons.play_circle_outline,
                      title: 'Video Tutorials',
                      color: Colors.red,
                    ),
                    _buildResourceTile(
                      icon: Icons.policy,
                      title: 'Admin Guidelines',
                      color: Colors.teal,
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildFaqTile({
    required String question,
    required String answer,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text(
          question,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
        children: [
          Text(
            answer,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceTile({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Icon(Icons.open_in_new, color: Colors.grey[400], size: 18),
        onTap: () {},
      ),
    );
  }

  // About Dialog
  void _showAboutDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.deepPurple[400]!, Colors.pink[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About Admin Panel',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'System information',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.deepPurple[400]!, Colors.pink[400]!],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.admin_panel_settings,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'OvaCare Admin Panel',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildInfoChip('Flutter', Icons.flutter_dash),
                        const SizedBox(width: 12),
                        _buildInfoChip('Dart', Icons.code),
                        const SizedBox(width: 12),
                        _buildInfoChip('Material 3', Icons.palette),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '© 2024 OvaCare. All rights reserved.',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.grey[700]),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
