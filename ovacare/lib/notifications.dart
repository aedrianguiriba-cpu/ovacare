
class NotificationService {
  // Hardcoded reminders for demo
  static List<Map<String, String>> getReminders() => [
    {'type': 'Medication', 'message': 'Take Metformin at 8:00 AM'},
    {'type': 'Menstrual', 'message': 'Next period expected on 2025-11-15'},
    {'type': 'Appointment', 'message': 'OB-GYN checkup on 2025-11-20'},
  ];
}
