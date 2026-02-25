import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:fl_chart/fl_chart.dart';

import 'models/user_model.dart';
import 'login_page.dart';
import 'add_patient_page.dart';
import 'dashboards/doctor_dashboard.dart';
import 'edit_patient_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LoginPage(),
    );
  }
}

/* ===========================
   DASHBOARD (Medication Adherence)
=========================== */

class DashboardPage extends StatefulWidget {
  final UserModel user;

  const DashboardPage({super.key, required this.user});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final String baseUrl = "http://127.0.0.1:5000";

  late int patientId;

  List patients = [];
  List medications = [];

  int taken = 0;
  int missed = 0;
  double adherenceRate = 0;

  Map<String, dynamic> todayStatus = {};
  Map<String, dynamic> trendData = {};
  @override
  void initState() {
    super.initState();

    if (widget.user.role == "patient" && widget.user.patientId != null) {
      patientId = widget.user.patientId!;
    } else {
      patientId = 1; // default fallback (caregiver/doctor)
    }

    refreshAll();
  }

  Future<void> refreshAll() async {
    if (widget.user.role != "patient") {
      await fetchPatients();
      // اگر لیست بیماران تازه اومد و patientId روی چیزی بود که دیگه وجود نداره
      if (patients.isNotEmpty) {
        final ids = patients.map((p) => p["id"]).toList();
        if (!ids.contains(patientId)) {
          setState(() => patientId = patients.first["id"]);
        }
      }
    }

    await fetchMedications();
    await fetchSummary();
    await fetchTrend();
  }

  /* ================= PATIENTS ================= */

  Future<void> fetchPatients() async {
    final res = await http.get(
      Uri.parse("$baseUrl/patients"),
      headers: {"X-Role": widget.user.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        patients = jsonDecode(res.body);
      });
    } else {
      setState(() {
        patients = [];
      });
    }
  }

  Future<void> deletePatient(int id) async {
    final res = await http.delete(
      Uri.parse("$baseUrl/patients/$id"),
      headers: {"X-Role": widget.user.role},
    );

    if (res.statusCode == 200 || res.statusCode == 204) {
      await refreshAll();
    } else if (res.statusCode == 403) {
      _snack("Access restricted for your role.");
    } else {
      try {
        final data = jsonDecode(res.body);
        _snack(data["error"] ?? "Failed to delete patient");
      } catch (_) {
        _snack("Failed to delete patient");
      }
    }
  }

  void confirmDeletePatient() {
    if (patients.isEmpty) return;

    final current = patients.firstWhere(
      (p) => p["id"] == patientId,
      orElse: () => patients.first,
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Patient"),
        content: Text(
          "Are you sure you want to delete '${current["name"]}'?\n\n"
          "This may also affect medications/logs depending on backend rules.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await deletePatient(current["id"]);
            },
            child: const Text("Delete"),
          ),
        ],
      ),
    );
  }

  Future<void> showAddPatientDialog() async {
    // تو import داری add_patient_page.dart
    // اینجا هیچ چیزی حذف نشده؛ فقط flow حرفه‌ای شد: بعد از برگشت refresh می‌کنه
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddPatientPage(user: widget.user)),
    );

    // اگر صفحه‌ی AddPatientPage چیزی برگردوند (true/anything)، باز refresh می‌کنیم
    if (result != null) {
      await refreshAll();
    } else {
      // حتی اگر null هم بود، برای اینکه دیتا عقب نمونده باشه
      await refreshAll();
    }
  }

  /* ================= MEDICATIONS ================= */

  Future<void> fetchMedications() async {
    final res = await http.get(
      Uri.parse("$baseUrl/medications/$patientId"),
      headers: {"X-Role": widget.user.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        medications = jsonDecode(res.body);
      });
    } else {
      setState(() {
        medications = [];
      });
    }
  }

  Future<void> addMedication(
    String name,
    String dosage,
    String time,
    int interval,
  ) async {
    final res = await http.post(
      Uri.parse("$baseUrl/medications"),
      headers: {"Content-Type": "application/json", "X-Role": widget.user.role},
      body: jsonEncode({
        "patient_id": patientId,
        "name": name,
        "dosage": dosage,
        "time": time,
        "interval_hours": interval,
      }),
    );

    if (res.statusCode == 201) {
      await refreshAll();
    } else if (res.statusCode == 403) {
      _snack("Access restricted for your role.");
    } else {
      try {
        final data = jsonDecode(res.body);
        _snack(data["error"] ?? "Failed to add medication");
      } catch (_) {
        _snack("Failed to add medication");
      }
    }
  }

  void showAddMedicationDialog() {
    final nameController = TextEditingController();
    final dosageController = TextEditingController();
    final timeController = TextEditingController();
    final intervalController = TextEditingController(text: "8");

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Medication"),
        content: SingleChildScrollView(
          child: Column(
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
                decoration: const InputDecoration(labelText: "Time (HH:MM)"),
              ),
              TextField(
                controller: intervalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: "Interval (hours)",
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final interval = int.tryParse(intervalController.text) ?? 8;
              Navigator.pop(context);
              await addMedication(
                nameController.text,
                dosageController.text,
                timeController.text,
                interval,
              );
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  /* ================= SUMMARY ================= */

  Future<void> fetchSummary() async {
    final res = await http.get(
      Uri.parse("$baseUrl/adherence/summary/$patientId"),
      headers: {"X-Role": widget.user.role},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        taken = data["overall_taken"] ?? 0;
        missed = data["overall_missed"] ?? 0;
        adherenceRate = (data["overall_rate"] ?? 0).toDouble();
        todayStatus = (data["today_status"] ?? {}).cast<String, dynamic>();
      });
    } else {
      setState(() {
        taken = 0;
        missed = 0;
        adherenceRate = 0;
        todayStatus = {};
      });
    }
  }

  /* ================= TREND ================= */

  Future<void> fetchTrend() async {
    final res = await http.get(
      Uri.parse("$baseUrl/adherence/trend/$patientId"),
      headers: {"X-Role": widget.user.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        trendData = jsonDecode(res.body) is List ? jsonDecode(res.body) : [];
      });
    } else {
      setState(() {
        trendData = {};
      });
    }
  }

  Widget buildTrendChart() {
    if (trendData.isEmpty) return const SizedBox();

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(trendData.length, (i) {
                final point = trendData[i];
                final rate = (point["rate"] ?? 0);

                return FlSpot(
                  i.toDouble(),
                  (rate is num ? rate : 0).toDouble(),
                );
              }),
              isCurved: true,
              barWidth: 4,
              dotData: FlDotData(show: true),
            ),
          ],
        ),
      ),
    );
  }

  /* ================= LOG ================= */

Future<void> logStatus(int medId, String status) async {
    final now = DateTime.now();

    // گرفتن لاگ‌های قبلی
    final logsRes = await http.get(
      Uri.parse("$baseUrl/adherence/logs/$patientId"),
      headers: {"X-Role": widget.user.role},
    );

    if (logsRes.statusCode != 200) {
      _snack("Error checking previous logs");
      return;
    }

    final logs = jsonDecode(logsRes.body);

    final med = medications.firstWhere(
      (m) => (m["medication_id"] ?? m["id"]) == medId,
    );

    final int intervalHours = med["interval_hours"] ?? 8;

    // پیدا کردن آخرین لاگ همین دارو
    final lastLog = logs.firstWhere(
      (l) => l["medication_name"] == med["name"],
      orElse: () => null,
    );

    if (lastLog != null) {
      final lastTimestamp = DateTime.parse(lastLog["timestamp"]);
      final nextAllowed = lastTimestamp.add(Duration(hours: intervalHours));

      if (now.isBefore(nextAllowed)) {
        final diff = nextAllowed.difference(now);
        final hrs = diff.inHours;
        final mins = diff.inMinutes % 60;

        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Too Early"),
            content: Text(
              "Last logged at: "
              "${TimeOfDay.fromDateTime(lastTimestamp).format(context)}\n\n"
              "Next dose available in:\n"
              "${hrs} hr ${mins} min",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              ),
            ],
          ),
        );

        return; // ❌ اجازه لاگ نمی‌ده
      }
    }

    // اگر رسید به اینجا یعنی مجازه

    final res = await http.post(
      Uri.parse("$baseUrl/adherence/log"),
      headers: {"Content-Type": "application/json", "X-Role": widget.user.role},
      body: jsonEncode({
        "patient_id": patientId,
        "medication_id": medId,
        "status": status,
      }),
    );

    if (res.statusCode != 201) {
      _snack("Error logging dose");
      return;
    }

    await refreshAll();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Dose Logged"),
        content: Text(
          "Status: ${status.toUpperCase()}\n"
          "Logged at: ${TimeOfDay.fromDateTime(now).format(context)}",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

Future<void> resetAll() async {
    for (var med in medications) {
      final int medId = (med["medication_id"] ?? med["id"]) as int;

      await http.post(
        Uri.parse("$baseUrl/adherence/reset"),
        headers: {
          "Content-Type": "application/json",
          "X-Role": widget.user.role,
        },
        body: jsonEncode({"patient_id": patientId, "medication_id": medId}),
      );
    }

    await refreshAll();
  }

  void confirmReset() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Confirm Reset"),
        content: const Text("Delete all adherence logs?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await resetAll();
            },
            child: const Text("Confirm"),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Widget buildMedicationCard(dynamic med) {
    // بعضی backendها medication_id می‌دن، بعضی id
    final int medId = (med["medication_id"] ?? med["id"]) as int;
    final status = todayStatus[medId.toString()];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              med["name"],
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text("${med["dosage"]} - ${med["time"]}"),
            Text("Interval: ${med["interval_hours"] ?? 8} hours"),
            const SizedBox(height: 8),
            Text(
              status == null
                  ? "Today: NOT LOGGED"
                  : "Today: ${status.toUpperCase()}",
              style: TextStyle(
                color: status == "taken"
                    ? Colors.green
                    : status == "missed"
                    ? Colors.red
                    : Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () => logStatus(medId, "taken"),
                  child: const Text("TAKEN"),
                ),
                ElevatedButton(
                  onPressed: () => logStatus(medId, "missed"),
                  child: const Text("MISSED"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ✅ Doctor Dashboard guard dialog
  Future<void> _doctorAccessPressed() async {
    if (widget.user.role != "doctor") {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Access Not Available"),
          content: const Text(
            "This section is only available to doctors.\n\n"
            "Do you want to log out and sign in with a different account?",
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text("No"),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              child: const Text("Yes"),
            ),
          ],
        ),
      );
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DoctorDashboardPage(user: widget.user)),
    );

    if (result != null) {
      await refreshAll();
    } else {
      await refreshAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasPatients = widget.user.role == "patient"
        ? true
        : patients.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Medication Adherence"),
            Text(widget.user.username, style: const TextStyle(fontSize: 14)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: "Doctor Dashboard",
            icon: const Icon(Icons.local_hospital),
            onPressed: _doctorAccessPressed,
          ),
          IconButton(
            tooltip: "Add Patient",
            icon: const Icon(Icons.person_add),
            onPressed: widget.user.role == "patient"
                ? null
                : showAddPatientDialog,
          ),
          IconButton(
            tooltip: "Delete Patient",
            icon: const Icon(Icons.delete),
            onPressed: (widget.user.role == "patient" || !hasPatients)
                ? null
                : confirmDeletePatient,
          ),
          IconButton(
            tooltip: "Add Medication",
            icon: const Icon(Icons.medication),
            onPressed: hasPatients ? showAddMedicationDialog : null,
          ),
        ],
      ),
      body: hasPatients
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  if (widget.user.role != "patient")
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButton<int>(
                            value: patientId,
                            isExpanded: true,
                            items: patients.map<DropdownMenuItem<int>>((p) {
                              return DropdownMenuItem<int>(
                                value: p["id"],
                                child: Text(
                                  "${p["first_name"] ?? ""} ${p["last_name"] ?? ""}",
                                ),
                              );
                            }).toList(),
                            onChanged: (value) async {
                              if (value == null) return;
                              setState(() => patientId = value);
                              await refreshAll();
                            },
                          ),
                        ),
                        if (widget.user.role == "doctor" ||
                            widget.user.role == "caregiver")
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            tooltip: "Edit Patient",
                            onPressed: () async {
                              final current = patients.firstWhere(
                                (p) => p["id"] == patientId,
                              );
                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => EditPatientPage(
                                    user: widget.user,
                                    patient: current,
                                  ),
                                ),
                              );
                              if (updated == true) {
                                await refreshAll();
                              }
                            },
                          ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  Text(
                    "${adherenceRate.toStringAsFixed(1)}%",
                    style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  LinearProgressIndicator(value: adherenceRate / 100),
                  const SizedBox(height: 20),
                  buildTrendChart(),
                  const SizedBox(height: 20),
                  ...medications.map(buildMedicationCard).toList(),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: confirmReset,
                    child: const Text("RESET ALL"),
                  ),
                ],
              ),
            )
          : const Center(child: Text("No patients yet.")),
    );
  }
}
