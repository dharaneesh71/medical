class Medication {
  final int medicationId;
  final String name;
  final String dosage;
  final String time;

  int taken;
  int missed;
  double adherenceRate;

  Medication({
    required this.medicationId,
    required this.name,
    required this.dosage,
    required this.time,
    this.taken = 0,
    this.missed = 0,
    this.adherenceRate = 0,
  });

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      medicationId: json['medication_id'],
      name: json['name'],
      dosage: json['dosage'],
      time: json['time'],
    );
  }
}
