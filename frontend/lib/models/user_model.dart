class UserModel {
  final int id;
  final String username;
  final String role;
  final int? patientId;

  UserModel({
    required this.id,
    required this.username,
    required this.role,
    this.patientId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json["id"],
      username: json["username"],
      role: json["role"],
      patientId: json["patient_id"],
    );
  }
}
