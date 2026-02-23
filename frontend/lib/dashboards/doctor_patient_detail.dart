import 'package:flutter/material.dart';
import 'dart:convert';
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

class _DoctorPatientDetailPageState extends State<DoctorPatientDetailPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final String baseUrl = "http://127.0.0.1:5000";

  List medications = [];
  bool isMedLoading = true;
  Map<String, dynamic> todayStatus = {};
  Map<String, dynamic> summaryData = {};
  bool isSummaryLoading = true;
  Map<String, dynamic> trendData = {};
  bool isTrendLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    fetchMedications();
    fetchTodayStatus();
    fetchSummary();
    fetchTrend();
  }

  Future<void> fetchMedications() async {
    final res = await http.get(
      Uri.parse("$baseUrl/medications/${widget.patientId}"),
      headers: {"X-Role": widget.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        medications = jsonDecode(res.body);
        isMedLoading = false;
      });
    } else {
      setState(() => isMedLoading = false);
    }
  }

  Future<void> fetchTodayStatus() async {
    final res = await http.get(
      Uri.parse("$baseUrl/adherence/summary/${widget.patientId}"),
      headers: {"X-Role": widget.role},
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      setState(() {
        todayStatus = data["today_status"] ?? {};
      });
    }
  }

  Future<void> fetchSummary() async {
    final res = await http.get(
      Uri.parse("$baseUrl/adherence/summary/${widget.patientId}"),
      headers: {"X-Role": widget.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        summaryData = jsonDecode(res.body);
        isSummaryLoading = false;
      });
    } else {
      setState(() => isSummaryLoading = false);
    }
  }
  Future<void> fetchTrend() async {
    final res = await http.get(
      Uri.parse("$baseUrl/adherence/trend/${widget.patientId}"),
      headers: {"X-Role": widget.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        trendData = jsonDecode(res.body);
        isTrendLoading = false;
      });
    } else {
      setState(() => isTrendLoading = false);
    }
  }

  Future<void> logMedication(int medId, String status) async {
    final res = await http.post(
      Uri.parse("$baseUrl/adherence/log"),
      headers: {"Content-Type": "application/json", "X-Role": widget.role},
      body: jsonEncode({
        "patient_id": widget.patientId,
        "medication_id": medId,
        "status": status,
      }),
    );

    if (res.statusCode == 201) {
      await fetchTodayStatus();
      await fetchSummary();
      await fetchTrend();
    } else {
      final data = jsonDecode(res.body);
      showErrorDialog(data["error"] ?? "Error logging");
    }
  }

  Future<void> resetTodayStatus(int medId) async {
    final res = await http.post(
      Uri.parse("$baseUrl/adherence/reset"),
      headers: {"Content-Type": "application/json", "X-Role": widget.role},
      body: jsonEncode({
        "patient_id": widget.patientId,
        "medication_id": medId,
      }),
    );

    if (res.statusCode == 200) {
      await fetchTodayStatus();
      await fetchSummary();
      await fetchTrend();
    } else {
      final data = jsonDecode(res.body);
      showErrorDialog(data["error"] ?? "Reset failed");
    }
  }

  Future<void> deleteMedication(int medId) async {
    await http.delete(
      Uri.parse("$baseUrl/medications/$medId"),
      headers: {"X-Role": widget.role},
    );
    await fetchMedications();
  }

  void showErrorDialog(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  void showMedicationDialog({dynamic med}) {
    final name = TextEditingController(text: med?["name"] ?? "");
    final dosage = TextEditingController(text: med?["dosage"] ?? "");
    final time = TextEditingController(text: med?["time"] ?? "");
    final interval = TextEditingController(
      text: med?["interval_hours"]?.toString() ?? "8",
    );

    final bool isEdit = med != null;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isEdit ? "Edit Medication" : "Add Medication"),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: dosage,
                decoration: const InputDecoration(labelText: "Dosage"),
              ),
              TextField(
                controller: time,
                decoration: const InputDecoration(labelText: "Time (HH:MM)"),
              ),
              TextField(
                controller: interval,
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
              if (isEdit) {
                await http.put(
                  Uri.parse("$baseUrl/medications/${med["medication_id"]}"),
                  headers: {
                    "Content-Type": "application/json",
                    "X-Role": widget.role,
                  },
                  body: jsonEncode({
                    "name": name.text,
                    "dosage": dosage.text,
                    "time": time.text,
                    "interval_hours": int.tryParse(interval.text) ?? 8,
                  }),
                );
              } else {
                await http.post(
                  Uri.parse("$baseUrl/medications"),
                  headers: {
                    "Content-Type": "application/json",
                    "X-Role": widget.role,
                  },
                  body: jsonEncode({
                    "patient_id": widget.patientId,
                    "name": name.text,
                    "dosage": dosage.text,
                    "time": time.text,
                    "interval_hours": int.tryParse(interval.text) ?? 8,
                  }),
                );
              }

              Navigator.pop(context);
              await fetchMedications();
            },
            child: Text(isEdit ? "Save" : "Add"),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.patientName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Medications"),
            Tab(text: "Summary"),
            Tab(text: "Trend"),
            Tab(text: "Logs"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          buildMedicationsTab(),
          buildSummaryTab(),
          buildTrendTab(),
          const Center(child: Text("Logs coming next")),
        ],
      ),
    );
  }

  Widget buildSummaryTab() {
    if (isSummaryLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (summaryData.isEmpty) {
      return const Center(child: Text("No summary data available"));
    }

    final overallRate = summaryData["overall_rate"] ?? 0;
    final overallTaken = summaryData["overall_taken"] ?? 0;
    final overallMissed = summaryData["overall_missed"] ?? 0;
    final breakdown = summaryData["breakdown"] as List;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Overall Card
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Overall Patient Summary",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text("Adherence Rate: $overallRate%"),
                Text("Taken: $overallTaken"),
                Text("Missed: $overallMissed"),
              ],
            ),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          "Medication Breakdown",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),

        const SizedBox(height: 10),

        ...breakdown.map((med) {
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    med["name"],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Taken: ${med["taken"]}"),
                  Text("Missed: ${med["missed"]}"),
                  Text("Adherence Rate: ${med["adherence_rate"]}%"),
                ],
              ),
            ),
          );
        }).toList(),
      ],
    );
  }
  Widget buildOverallSection() {
    if (trendData["overall"] == null) return SizedBox();

    final overall = trendData["overall"];

    return Card(
      elevation: 3,
      margin: EdgeInsets.all(12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Overall Adherence",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text("Adherence Rate: ${overall["adherence_rate"]}%"),
            Text("Risk Level: ${overall["risk_level"]}"),
            Text("Total Logs: ${overall["total_logs"]}"),
          ],
        ),
      ),
    );
  }
  Widget buildMedicationCards() {
    if (trendData["medications"] == null) return SizedBox();

    final meds = trendData["medications"] as List;

    return Column(
      children: meds.map((med) {
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: ListTile(
            title: Text(med["name"]),
            subtitle: Text(
              "Adherence: ${med["adherence_rate"]}% | Missed: ${med["missed"]}",
            ),
            trailing: Icon(Icons.show_chart),
            onTap: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text("${med["name"]} Trend"),
                  content: Text(med["trend"].toString()),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }

  Widget buildTrendTab() {
  if (trendData.isEmpty) return Center(child: CircularProgressIndicator());

  return SingleChildScrollView(
    child: Column(
      children: [
        buildOverallSection(),   // Option A
        buildMedicationCards(),  // Option B
      ],
    ),
  );
}
    
  Widget buildMedicationsTab() {
    if (isMedLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (widget.role == "doctor")
          Padding(
            padding: const EdgeInsets.all(16),
            child: Align(
              alignment: Alignment.centerRight,
              child: Tooltip(
                message: "Add new medication",
                child: ElevatedButton.icon(
                  onPressed: () => showMedicationDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add Medication"),
                ),
              ),
            ),
          ),
        Expanded(
          child: medications.isEmpty
              ? const Center(child: Text("No medications assigned"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: medications.length,
                  itemBuilder: (context, index) {
                    final med = medications[index];
                    final int medId =
                        (med["medication_id"] ?? med["id"]) as int;
                    final status = todayStatus[medId.toString()];

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  med["name"],
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (widget.role == "doctor")
                                  Row(
                                    children: [
                                      Tooltip(
                                        message: "Edit medication",
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.edit,
                                            color: Colors.blue,
                                          ),
                                          onPressed: () =>
                                              showMedicationDialog(med: med),
                                        ),
                                      ),
                                      Tooltip(
                                        message: "Remove medication",
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          onPressed: () =>
                                              deleteMedication(medId),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                            Text("${med["dosage"]} • ${med["time"]}"),
                            Text("Every ${med["interval_hours"]} hours"),
                            const SizedBox(height: 8),
                            Text(
                              status == null
                                  ? "Today: NOT LOGGED"
                                  : "Today: ${status.toUpperCase()}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: status == "taken"
                                    ? Colors.green
                                    : status == "missed"
                                    ? Colors.red
                                    : Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: Tooltip(
                                    message: "Mark as taken",
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                      ),
                                      onPressed: () =>
                                          logMedication(medId, "taken"),
                                      child: const Text("Taken"),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Tooltip(
                                    message: "Mark as missed",
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                      ),
                                      onPressed: () =>
                                          logMedication(medId, "missed"),
                                      child: const Text("Missed"),
                                    ),
                                  ),
                                ),
                                if (widget.role == "doctor")
                                  Tooltip(
                                    message: "Reset today's status",
                                    child: IconButton(
                                      icon: const Icon(Icons.refresh),
                                      onPressed: () => resetTodayStatus(medId),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
