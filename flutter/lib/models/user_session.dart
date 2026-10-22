import 'dart:convert';

class UserSession {
  const UserSession({
    required this.id,
    required this.name,
    required this.number,
    this.role = 'Citizen',
  });

  final String id;
  final String name;
  final String number;
  final String role;

  bool get isAuthority => role == 'Authority' || role == 'Admin';

  static UserSession? fromJsonString(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return UserSession.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  factory UserSession.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final number = json['number'];
    if (id is! String || name is! String || number is! String) {
      throw const FormatException('Invalid user session shape');
    }
    if (id.isEmpty || name.isEmpty || number.isEmpty) {
      throw const FormatException('User session fields cannot be empty');
    }
    final role = json['role']?.toString() ?? 'Citizen';
    return UserSession(id: id, name: name, number: number, role: role);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'number': number,
        'role': role,
      };

  String toJsonString() => jsonEncode(toJson());
}
