class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.companyIds,
    this.displayName,
    this.activeCompanyId,
  });

  final String id;
  final String email;
  final String? displayName;
  final List<String> companyIds;
  final String? activeCompanyId;

  bool get hasCompany => activeCompanyId != null && activeCompanyId!.isNotEmpty;
}
