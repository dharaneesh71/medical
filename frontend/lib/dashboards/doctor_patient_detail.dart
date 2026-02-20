import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class DoctorPatientDetailPage extends StatefulWidget {
  final int patientId;
  final String patientName;
  final String role;

  const DoctorPatientDetailPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.role,
  });

  @override
  State<DoctorPatientDetailPage> createState() =>
      _DoctorPatientDetailPageState();
}

class _DoctorPatientDetailPageState extends State<DoctorPatientDetailPage> {
  final String baseUrl = "http://127.0.0.1:5000";

  Map<String, String> get authHeaders => {
    "X-Role": widget.role,
    "Content-Type": "application/json",
  };

  bool isLoading = true;
  double adherenceRate = 0;
  String riskLevel = "low";

  List medications = [];
  List logs = [];

  @override
  void initState() {
    super.initState();
    fetchAll();
  }

  Future<void> fetchAll() async {
    setState(() => isLoading = true);

    try {
      final summaryRes = await http.get(
        Uri.parse("$baseUrl/adherence/summary/${widget.patientId}"),
        headers: authHeaders,
      );

      final medRes = await http.get(
        Uri.parse("$baseUrl/medications/${widget.patientId}"),
        headers: authHeaders,
      );

      final logRes = await http.get(
        Uri.parse("$baseUrl/adherence/logs/${widget.patientId}"),
        headers: authHeaders,
      );

      if (summaryRes.statusCode == 200 &&
          medRes.statusCode == 200 &&
          logRes.statusCode == 200) {
        final summaryData = jsonDecode(summaryRes.body);
        final medData = jsonDecode(medRes.body);
        final logData = jsonDecode(logRes.body);

        final rate = (summaryData["adherence_rate"] ?? 0).toDouble();

        String calculatedRisk;
        if (rate >= 90) {
          calculatedRisk = "low";
        } else if (rate >= 70) {
          calculatedRisk = "moderate";
        } else {
          calculatedRisk = "high";
        }

        setState(() {
          adherenceRate = rate;
          riskLevel = calculatedRisk;
          medications = medData;
          logs = logData;
        });
      }
    } catch (e) {
      debugPrint("Error: $e");
    }

    setState(() => isLoading = false);
  }

  Future<void> addMedication(
    String name,
    String dosage,
    String time,
    int interval,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/medications"),
      headers: authHeaders,
      body: jsonEncode({
        "patient_id": widget.patientId,
        "name": name,
        "dosage": dosage,
        "time": time,
        "interval_hours": interval,
      }),
    );

    if (res.statusCode == 201) {
      await fetchAll();
    }
  }

  Future<void> deleteMedication(int medicationId) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/medications/$medicationId"),
      headers: authHeaders,
    );

    if (res.statusCode == 200) {
      await fetchAll();
    }
  }

  void confirmDeleteMedication(int medicationId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Medication"),
        content: const Text("Are you sure you want to delete this medication?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await deleteMedication(medicationId);
              Navigator.pop(context);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> updateMedication(
    int id,
    String name,
    String dosage,
    String time,
    int interval,
  ) async {
    final res = await http.put(
      Uri.parse("$baseUrl/medications/$id"),
      headers: authHeaders,
      body: jsonEncode({
        "name": name,
        "dosage": dosage,
        "time": time,
        "interval_hours": interval,
      }),
    );

    if (res.statusCode == 200) {
      await fetchAll();
    }
  }

  void showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final timeController = TextEditingController();
    final intervalController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Medication"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(labelText: "Dosage"),
            ),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(labelText: "Time"),
            ),
            TextField(
              controller: intervalController,
              decoration: const InputDecoration(labelText: "Interval Hours"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await addMedication(
                nameController.text,
                dosageController.text,
                timeController.text,
                int.tryParse(intervalController.text) ?? 8,
              );
              Navigator.pop(context);
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void showEditMedicationDialog(Map med) {
    final nameController = TextEditingController(text: med["name"]);
    final dosageController = TextEditingController(text: med["dosage"]);
    final timeController = TextEditingController(text: med["time"]);
    final intervalController = TextEditingController(
      text: med["interval_hours"].toString(),
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Medication"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: dosageController,
              decoration: const InputDecoration(labelText: "Dosage"),
            ),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(labelText: "Time"),
            ),
            TextField(
              controller: intervalController,
              decoration: const InputDecoration(labelText: "Interval Hours"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              await updateMedication(
                med["medication_id"],
                nameController.text,
                dosageController.text,
                timeController.text,
                int.tryParse(intervalController.text) ?? 8,
              );
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Color riskColor(String risk) {
    if (risk == "high") return Colors.red;
    if (risk == "moderate") return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.patientName)),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: fetchAll,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    "Adherence: ${adherenceRate.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Risk: ${riskLevel.toUpperCase()}",
                    style: TextStyle(
                      color: riskColor(riskLevel),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: adherenceRate / 100,
                    color: riskColor(riskLevel),
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Medications",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...medications.map(
                    (med) => Card(
                      child: ListTile(
                        title: Text(med["name"]),
                        subtitle: Text("${med["dosage"]} - ${med["time"]}"),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => showEditMedicationDialog(med),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () =>
                                  confirmDeleteMedication(med["medication_id"]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showAddMedicationDialog,
        icon: const Icon(Icons.medication),
        label: const Text("Add Medication"),
      ),
    );
  }
}
