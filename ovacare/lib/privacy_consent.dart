import 'package:flutter/material.dart';

class PrivacyConsentScreen extends StatelessWidget {
  const PrivacyConsentScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Data Privacy Consent')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Data Privacy Act of 2012 (RA 10173)', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('By using this app, you consent to the collection and processing of your health data for the purpose of PCOS management and research. Your data will be kept confidential and used only for health improvement and analytics.'),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I Consent'),
            ),
          ],
        ),
      ),
    );
  }
}
