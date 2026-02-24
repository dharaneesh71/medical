import 'package:flutter/material.dart';

class MedicationTrendPage extends StatelessWidget {
  final int patientId;
  final int medicationId;
  final String medicationName;
  final String role;

  const MedicationTrendPage({
    super.key,
    required this.patientId,
    required this.medicationId,
    required this.medicationName,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(medicationName)),
      body: Center(
        child: Text(
          "Trend details for medication ID: $medicationId",
          style: TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
