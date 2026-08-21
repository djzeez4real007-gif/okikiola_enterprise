/// Access control tuned for a single sales staff + owner,
/// while ready for manager / storekeeper later.
class Permissions {
  static const dashboard = 'dashboard';
  static const products = 'products';
  static const sales = 'sales';
  static const expenses = 'expenses';
  static const shifts = 'shifts';
  static const stockAdjust = 'stock_adjust';
  static const stockCount = 'stock_count';
  static const reports = 'reports';
  static const users = 'users';
  static const audit = 'audit';
  static const settings = 'settings';

  /// Owner: full control.
  /// Sales (the sales boy): sell, view products, record simple expenses,
  /// open/close his shift — cannot delete history, change cost price,
  /// manage users, or see full profit/audit.
  static bool canAccess(String role, String feature) {
    switch (role) {
      case 'owner':
        return true;
      case 'manager':
        return feature != users; // manager almost full, no user admin
      case 'sales':
        return {
          dashboard,
          products, // view / sell from catalogue (edit limited in UI)
          sales,
          expenses, // log daily expenses (owner reviews)
          shifts,
        }.contains(feature);
      case 'storekeeper':
        return {
          dashboard,
          products,
          stockAdjust,
          stockCount,
          shifts,
        }.contains(feature);
      default:
        return feature == dashboard;
    }
  }

  static bool canEditProduct(String role) =>
      role == 'owner' || role == 'manager' || role == 'storekeeper';

  static bool canEditCostPrice(String role) => role == 'owner';

  static bool canDeleteSale(String role) => role == 'owner' || role == 'manager';

  static bool canGiveDiscount(String role) =>
      role == 'owner' || role == 'manager' || role == 'sales';

  /// Sales boy can discount only up to this % without owner.
  static double maxSelfDiscountPercent(String role) {
    if (role == 'owner' || role == 'manager') return 100;
    if (role == 'sales') return 5; // small goodwill only
    return 0;
  }

  static bool canVoidSale(String role) => role == 'owner' || role == 'manager';

  static bool canAdjustStock(String role) =>
      role == 'owner' || role == 'manager' || role == 'storekeeper';

  static bool canViewProfit(String role) => role == 'owner' || role == 'manager';

  static bool canViewAudit(String role) => role == 'owner';

  static bool canManageUsers(String role) => role == 'owner';
}
