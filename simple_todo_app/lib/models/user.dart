class User {
  final String id;
  final String username;
  final String email;
  final String passwordHash;
  final DateTime createdAt;
  final String? displayName;
  final String? avatar;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    this.displayName,
    this.avatar,
  });

  // Map変換（DB保存用）
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
      'displayName': displayName,
      'avatar': avatar,
    };
  }

  // MapからUser生成
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      passwordHash: map['passwordHash'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      displayName: map['displayName'] as String?,
      avatar: map['avatar'] as String?,
    );
  }

  // コピーコンストラクタ
  User copyWith({
    String? id,
    String? username,
    String? email,
    String? passwordHash,
    DateTime? createdAt,
    String? displayName,
    String? avatar,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      createdAt: createdAt ?? this.createdAt,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, username: $username, email: $email, displayName: $displayName)';
  }
}
