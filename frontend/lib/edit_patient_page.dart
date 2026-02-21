import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models/user_model.dart';

class EditPatientPage extends StatefulWidget {
  final UserModel user;
  final Map patient; // patient object از لیست

  const EditPatientPage({super.key, required this.user, required this.patient});

  @override
  State<EditPatientPage> createState() => _EditPatientPageState();
}

class _EditPatientPageState extends State<EditPatientPage> {
  final String baseUrl = "http://127.0.0.1:5000";

  late TextEditingController firstNameController;
  late TextEditingController lastNameController;
  late TextEditingController dobController;
  late TextEditingController sexController;
  late TextEditingController noteController;

  @override
  void initState() {
    super.initState();
    firstNameController = TextEditingController(text: (widget.patient["first_name"] ?? "").toString());
    lastNameController  = TextEditingController(text: (widget.patient["last_name"] ?? "").toString());
    dobController       = TextEditingController(text: (widget.patient["date_of_birth"] ?? "").toString());
    sexController       = TextEditingController(text: (widget.patient["sex"] ?? "").toString());
    noteController      = TextEditingController(text: (widget.patient["note"] ?? "").toString());
  }

  Future<void> save() async {
    final id = widget.patient["id"];
    final res = await http.put(
      Uri.parse("$baseUrl/patients/$id"),
      headers: {
        "Content-Type": "application/json",
        "X-Role": widget.user.role,
      },
      body: jsonEncode({
        "first_name": firstNameController.text.trim(),
        "last_name": lastNameController.text.trim(),
        "date_of_birth": dobController.text.trim(),
        "sex": sexController.text.trim(),
        "note": noteController.text.trim(),
      }),
    );

    if (res.statusCode == 200) {
      Navigator.pop(context, true); // ✅ برگرد و بگو موفق بود
    } else if (res.statusCode == 403) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Access restricted for your role.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update patient (${res.statusCode})")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Patient")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            TextField(
              controller: firstNameController,
              decoration: const InputDecoration(labelText: "First Name"),
            ),
            TextField(
              controller: lastNameController,
              decoration: const InputDecoration(labelText: "Last Name"),
            ),
            TextField(
              controller: dobController,
              decoration: const InputDecoration(labelText: "Date of Birth (YYYY-MM-DD)"),
            ),
            TextField(
              controller: sexController,
              decoration: const InputDecoration(labelText: "Sex"),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Patient's Note"),
              maxLines: 3,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: save,
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}