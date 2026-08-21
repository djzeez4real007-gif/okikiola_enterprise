class AppUser {
  final String id;
  final String name;
  final String username;
  final String password;
  /// owner | manager | sales | storekeeper
  final String role;
  final bool active;

  AppUser({
    required this.id,
    required this.name,
    required this.username,
    required this.password,
    required this.role,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'username': username,
        'password': password,
        'role': role,
        'active': active,
      };

  factory AppUser.fromMap(Map map) => AppUser(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        username: map['username']?.toString() ?? '',
        password: map['password']?.toString() ?? '',
        role: map['role']?.toString() ?? 'sales',
        active: map['active'] != false,
      );

  static String roleLabel(String role) {
    switch (role) {
      case 'owner':
        return 'Owner';
      case 'manager':
        return 'Manager';
      case 'sales':
        return 'Sales Staff';
      case 'storekeeper':
        return 'Storekeeper';
      default:
        return role;
    }
  }
}
