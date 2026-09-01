class Company {
  const Company({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    this.tradeName = '',
    this.documentNumber = '',
    this.isActive = true,
    this.settings = const {},
  });

  final String id;
  final String name;
  final String tradeName;
  final String documentNumber;
  final String createdBy;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, Object?> settings;
}
