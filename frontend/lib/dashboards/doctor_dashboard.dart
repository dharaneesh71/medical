import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../login_page.dart';
import '../models/user_model.dart';
import '../add_patient_page.dart';
import 'doctor_patient_detail.dart';

class DoctorDashboardPage extends StatefulWidget {
  final UserModel user;

  const DoctorDashboardPage({super.key, required this.user});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final String baseUrl = "http://127.0.0.1:5000";

  List patients = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchRanking();
  }

  Future<void> fetchRanking() async {
    final res = await http.get(
      Uri.parse("$baseUrl/ai/risk-ranking"),
      headers: {"X-Role": widget.user.role},
    );

    if (res.statusCode == 200) {
      setState(() {
        patients = jsonDecode(res.body);
        isLoading = false;
      });
    } else {
      setState(() {
        isLoading = false;
      });
    }
  }

  Color riskColor(String risk) {
    if (risk == "high") return Colors.red;
    if (risk == "moderate") return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Doctor Dashboard"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        actions: [
          IconButton(
            tooltip: "Logout",
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : patients.isEmpty
              ? const Center(child: Text("No data available"))
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AddPatientPage(user: widget.user),
                              ),
                            ).then((_) {
                              setState(() {
                                isLoading = true;
                              });
                              fetchRanking();
                            });
                          },
                          icon: const Icon(Icons.person_add),
                          label: const Text("Add Patient"),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        children: patients.map((p) {
                          final first =
                              (p["first_name"] ?? "").toString();
                          final last =
                              (p["last_name"] ?? "").toString();
                          final adherence =
                              (p["adherence_rate"] ?? 0).toString();
                          final severity =
                              (p["severity_score"] ?? 0)
                                  .toDouble();
                          final risk =
                              (p["risk_level"] ?? "low")
                                  .toString();

                          return GestureDetector(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      DoctorPatientDetailPage(
                                    patientId: p["id"],
                                    patientName:
                                        "$first $last",
                                    role: widget.user.role,
                                  ),
                                ),
                              );

                              setState(() {
                                isLoading = true;
                              });

                              await fetchRanking();
                            },
                            child: Card(
                              margin: const EdgeInsets.symmetric(
                                  vertical: 8),
                              child: Padding(
                                padding:
                                    const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "$first $last",
                                      style:
                                          const TextStyle(
                                        fontSize: 18,
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                        "Adherence: $adherence%"),
                                    const SizedBox(height: 6),
                                    Text(
                                      "Risk: ${risk.toUpperCase()}",
                                      style: TextStyle(
                                        color:
                                            riskColor(risk),
                                        fontWeight:
                                            FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    LinearProgressIndicator(
                                      value: (severity / 100)
                                          .clamp(0.0, 1.0),
                                      color:
                                          riskColor(risk),
                                      backgroundColor:
                                          Colors.grey.shade300,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
    );
  }
}