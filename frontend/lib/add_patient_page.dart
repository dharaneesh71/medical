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
  final TextEditingController _controller = TextEditingController();

  Future<void> addPatient() async {
    final response = await http.post(
      Uri.parse("http://localhost:5000/patients"),
      headers: {
        "Content-Type": "application/json",
        "X-Role": widget.user.role, // ✅ دیگه هاردکد نیست
      },
      body: jsonEncode({"name": _controller.text}),
    );

    if (response.statusCode == 201) {
      Navigator.pop(context, true); // ✅ باعث refresh صفحه قبلی میشه
    } else if (response.statusCode == 403) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Access restricted for your role.")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to add patient")),
      );
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
              controller: _controller,
              decoration: const InputDecoration(labelText: "Patient Name"),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: addPatient,
              child: const Text("Add"),
            ),
          ],
        ),
      ),
    );
  }
}
