class Branch {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final bool isActive;
  final DateTime createdAt;

  const Branch({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.isActive,
    required this.createdAt,
  });
}
