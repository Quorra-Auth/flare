class AuthIdentity {
  final String id;
  final String name;
  final String mnemonic;
  final DateTime createdAt;

  AuthIdentity({
    required this.id,
    required this.name,
    required this.mnemonic,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mnemonic': mnemonic,
    'createdAt': createdAt.toIso8601String(),
  };

  factory AuthIdentity.fromJson(Map<String, dynamic> json) {
    return AuthIdentity(
      id: json['id'] as String,
      name: json['name'] as String,
      mnemonic: json['mnemonic'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}