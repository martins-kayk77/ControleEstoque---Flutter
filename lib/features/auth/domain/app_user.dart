class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.companyIds,
    this.displayName,
    this.cpf,
    this.birthDate,
    this.activeCompanyId,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? cpf;
  final DateTime? birthDate;
  final List<String> companyIds;
  final String? activeCompanyId;

  bool get hasCompany => activeCompanyId != null && activeCompanyId!.isNotEmpty;
}
