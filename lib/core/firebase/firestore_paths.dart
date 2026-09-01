class FirestoreCollections {
  const FirestoreCollections._();

  static const companies = 'companies';
  static const users = 'users';
  static const members = 'members';
  static const products = 'products';
  static const categories = 'categories';
  static const movements = 'movements';
  static const stockCounts = 'stockCounts';
  static const sales = 'sales';
  static const salesChannels = 'salesChannels';
  static const pricingPlatforms = 'pricingPlatforms';
}

class FirestorePaths {
  const FirestorePaths._();

  static String user(String userId) => '${FirestoreCollections.users}/$userId';

  static String company(String companyId) {
    return '${FirestoreCollections.companies}/$companyId';
  }

  static String companyMembers(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.members}';
  }

  static String products(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.products}';
  }

  static String product(String companyId, String productId) {
    return '${products(companyId)}/$productId';
  }

  static String categories(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.categories}';
  }

  static String category(String companyId, String categoryId) {
    return '${categories(companyId)}/$categoryId';
  }

  static String movements(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.movements}';
  }

  static String movement(String companyId, String movementId) {
    return '${movements(companyId)}/$movementId';
  }

  static String stockCounts(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.stockCounts}';
  }

  static String sales(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.sales}';
  }

  static String salesChannels(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.salesChannels}';
  }

  static String pricingPlatforms(String companyId) {
    return '${company(companyId)}/${FirestoreCollections.pricingPlatforms}';
  }
}
