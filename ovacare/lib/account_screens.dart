import 'package:flutter/material.dart';

// Registration Screen
class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});
  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}
class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _menstrualController = TextEditingController();
  bool _privacyConsent = false;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register')), 
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: ListView(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: _ageController, decoration: const InputDecoration(labelText: 'Age'), keyboardType: TextInputType.number),
            TextField(controller: _heightController, decoration: const InputDecoration(labelText: 'Height (cm)'), keyboardType: TextInputType.number),
            TextField(controller: _weightController, decoration: const InputDecoration(labelText: 'Weight (kg)'), keyboardType: TextInputType.number),
            TextField(controller: _menstrualController, decoration: const InputDecoration(labelText: 'Last Menstrual Date (YYYY-MM-DD)')),
            Row(
              children: [
                Checkbox(value: _privacyConsent, onChanged: (v) => setState(() => _privacyConsent = v ?? false)),
                const Expanded(child: Text('I consent to data privacy (RA 10173)')),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Save registration info to provider (hardcoded)
                Navigator.pop(context);
              },
              child: const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}

// Password Recovery Screen
class PasswordRecoveryScreen extends StatelessWidget {
  const PasswordRecoveryScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Password Recovery')),
      body: const Center(child: Text('Password recovery is not available in demo.')),
    );
  }
}
