class UserModel {
  const UserModel({
    this.id,
    required this.name,
    required this.username,
  });

  final int? id;
  final String name;
  final String username;

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] as int?,
      name: (map['name'] as String?) ?? '',
      username: (map['username'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'username': username,
    };
  }
}
