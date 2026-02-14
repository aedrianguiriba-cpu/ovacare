import 'package:flutter/material.dart';
import 'disclaimer_widget.dart';

class PCOSScreeningQuiz extends StatefulWidget {
  final VoidCallback onComplete;

  const PCOSScreeningQuiz({super.key, required this.onComplete});

  @override
  State<PCOSScreeningQuiz> createState() => _PCOSScreeningQuizState();
}

class _PCOSScreeningQuizState extends State<PCOSScreeningQuiz> {
  int currentQuestion = 0;
  int riskScore = 0;
  bool showResults = false;

  final List<Map<String, dynamic>> questions = [
    {
      'question': 'Do you have irregular menstrual cycles?',
      'subtext': '(Cycles longer than 35 days or less than 21 days, or skipping periods)',
      'options': ['Yes', 'No', 'Not Sure'],
      'points': [3, 0, 1],
    },
    {
      'question': 'Do you experience excessive acne or oily skin?',
      'subtext': '(Persistent acne especially on face, chest, or back)',
      'options': ['Yes', 'No', 'Not Sure'],
      'points': [2, 0, 1],
    },
    {
      'question': 'Do you notice unwanted hair growth or hair loss?',
      'subtext': '(Excess hair on face, chest, back OR hair thinning/baldness)',
      'options': ['Yes', 'No', 'Not Sure'],
      'points': [3, 0, 1],
    },
    {
      'question': 'Have you had difficulty getting pregnant or maintaining a pregnancy?',
      'subtext': '(Infertility or recurrent miscarriages)',
      'options': ['Yes', 'No', 'Not Sure'],
      'points': [2, 0, 1],
    },
  ];

  void selectAnswer(int points) {
    setState(() {
      riskScore += points;
      if (currentQuestion < questions.length - 1) {
        currentQuestion++;
      } else {
        showResults = true;
      }
    });
  }

  String getRiskAssessment() {
    if (riskScore <= 2) {
      return 'Low Risk';
    } else if (riskScore <= 5) {
      return 'Moderate Risk';
    } else {
      return 'High Risk';
    }
  }

  Color getRiskColor() {
    if (riskScore <= 2) {
      return Colors.green;
    } else if (riskScore <= 5) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }

  String getRiskMessage() {
    if (riskScore <= 2) {
      return 'Based on your responses, you appear to have low PCOS risk indicators. However, if you have any concerns, please consult a healthcare provider.';
    } else if (riskScore <= 5) {
      return 'Based on your responses, you may have some PCOS-related symptoms. It\'s recommended to consult with a healthcare provider for proper evaluation and diagnosis.';
    } else {
      return 'Based on your responses, you show several PCOS-related symptoms. Please schedule a consultation with a healthcare provider for professional evaluation and diagnosis.';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (showResults) {
      return _buildResultsScreen();
    }

    final question = questions[currentQuestion];
    final progress = (currentQuestion + 1) / questions.length;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: currentQuestion > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.pink),
                onPressed: () {
                  setState(() {
                    currentQuestion--;
                    // Subtract the points from the previous answer
                    List<int> prevPoints = questions[currentQuestion]['points'] as List<int>;
                    for (int point in prevPoints) {
                      riskScore -= point;
                    }
                  });
                },
              )
            : null,
        title: const Text(
          'PCOS Screening Quiz',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress Bar
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${currentQuestion + 1} of ${questions.length}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.pink,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.pink[400]!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),

              // Question
              Text(
                question['question'] as String,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                question['subtext'] as String,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 40),

              // Options
              Expanded(
                child: ListView.separated(
                  itemCount: (question['options'] as List<String>).length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final option = (question['options'] as List<String>)[index];
                    final points = (question['points'] as List<int>)[index];

                    return _buildOptionButton(
                      option: option,
                      points: points,
                      onTap: () => selectAnswer(points),
                    );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // Skip button
              if (currentQuestion == questions.length - 1)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      foregroundColor: Colors.grey[700],
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () {
                      setState(() => showResults = true);
                    },
                    child: const Text(
                      'Skip & Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String option,
    required int points,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.pink[200]!, width: 2),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.pink[50],
                border: Border.all(color: Colors.pink[300]!, width: 2),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward,
              color: Colors.pink[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final riskLevel = getRiskAssessment();
    final riskColor = getRiskColor();
    final riskMessage = getRiskMessage();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Your Results',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 20),

                      // Risk Level Card
                      Container(
                        width: double.infinity,
                  decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [riskColor.withOpacity(0.8), riskColor.withOpacity(0.5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: riskColor.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  children: [
                    Icon(
                      riskColor == Colors.green
                          ? Icons.check_circle_outline
                          : riskColor == Colors.orange
                              ? Icons.warning_amber_outlined
                              : Icons.error_outline,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      riskLevel,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Risk Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Message Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: riskColor.withOpacity(0.08),
                  border: Border.all(color: riskColor.withOpacity(0.3), width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Assessment Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: riskColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      riskMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Medical Disclaimer Widget
              const DisclaimerWidget(),

              const SizedBox(height: 32),

              // Info Card
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  border: Border.all(color: Colors.blue[200]!, width: 1.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[700]),
                        const SizedBox(width: 12),
                        Text(
                          'Important Note',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This screening is for informational purposes only and does not replace professional medical diagnosis. Please consult a healthcare provider for proper evaluation and diagnosis.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[700],
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Continue Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pink[400],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  onPressed: () => widget.onComplete(),
                  child: const Text(
                    'Continue to App',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
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
}
