import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'models/user_model.dart';

class AddPatientPage extends StatefulWidget {
  final UserModel user; // ✅ اضافه شد

  const AddPatientPage({super.key, required this.user});

  @override
  State<AddPatientPage> createState() => _AddPatientPageState();
}

class _AddPatientPageState extends State<AddPatientPage> {
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController dobController = TextEditingController();
  final TextEditingController sexController = TextEditingController();
  final TextEditingController noteController = TextEditingController();

  Future<void> addPatient() async {
    final response = await http.post(
      Uri.parse("http://127.0.0.1:5000/patients"),
      headers: {"Content-Type": "application/json", "X-Role": widget.user.role},
      body: jsonEncode({
        "first_name": firstNameController.text,
        "last_name": lastNameController.text,
        "date_of_birth": dobController.text,
        "sex": sexController.text,
        "note": noteController.text,
      }),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: ${response.statusCode}")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Patient")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
              decoration: const InputDecoration(
                labelText: "Date of Birth (YYYY-MM-DD)",
              ),
            ),
            TextField(
              controller: sexController,
              decoration: const InputDecoration(labelText: "Sex"),
            ),
            TextField(
              controller: noteController,
              decoration: const InputDecoration(labelText: "Short Note"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: addPatient, child: const Text("Add")),
          ],
        ),
      ),
    );
  }
}
