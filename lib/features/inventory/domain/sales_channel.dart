class SalesChannel {
  const SalesChannel({
    required this.id,
    required this.companyId,
    required this.name,
    this.description = '',
    this.isActive = true,
  });

  final String id;
  final String companyId;
  final String name;
  final String description;
  final bool isActive;
}
