import 'package:flutter/material.dart';

class DisclaimerWidget extends StatelessWidget {
  final bool isExpandable;
  final bool showIcon;

  const DisclaimerWidget({
    super.key,
    this.isExpandable = false,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.amber[300]!,
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showIcon) ...[
            Icon(
              Icons.info_outline,
              color: Colors.amber[700],
              size: 24,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical Disclaimer',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.amber[900],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'This information is not intended as a substitute for professional medical advice, diagnosis, or treatment. It is provided solely for general awareness, particularly for individuals with PCOS.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber[800],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Disclaimer Dialog to show on app startup
void showDisclaimerDialog(BuildContext context, {VoidCallback? onAccept}) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (BuildContext ctx) {
      // Auto-close dialog after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (ctx.mounted && Navigator.canPop(ctx)) {
          Navigator.pop(ctx);
        }
      });

      return AlertDialog(
        title: const Text('Medical Disclaimer'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber[300]!),
                ),
                child: Text(
                  'This information is not intended as a substitute for professional medical advice, diagnosis, or treatment. It is provided solely for general awareness, particularly for individuals with PCOS.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.amber[900],
                    height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Please consult with qualified healthcare professionals for any medical concerns or before making any health-related decisions.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'I Understand',
              style: TextStyle(
                color: Colors.pink[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      );
    },
  );
  
  if (onAccept != null) {
    Future.delayed(const Duration(milliseconds: 500), onAccept);
  }
}
