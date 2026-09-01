class Category {
  const Category({
    required this.id,
    required this.companyId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description = '',
    this.isActive = true,
  });

  final String id;
  final String companyId;
  final String name;
  final String description;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
}
