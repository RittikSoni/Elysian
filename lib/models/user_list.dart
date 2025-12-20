class UserList {
  final String id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final int itemCount;

  UserList({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    this.itemCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'itemCount': itemCount,
  };

  factory UserList.fromJson(Map<String, dynamic> json) => UserList(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    itemCount: json['itemCount'] as int? ?? 0,
  );

  UserList copyWith({
    String? id,
    String? name,
    String? description,
    DateTime? createdAt,
    int? itemCount,
  }) => UserList(
    id: id ?? this.id,
    name: name ?? this.name,
    description: description ?? this.description,
    createdAt: createdAt ?? this.createdAt,
    itemCount: itemCount ?? this.itemCount,
  );
}
