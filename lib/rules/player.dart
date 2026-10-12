class Player {
  final String id;
  final String name;

  const Player({required this.id, required this.name});

  @override
  bool operator ==(Object other) => other is Player && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
