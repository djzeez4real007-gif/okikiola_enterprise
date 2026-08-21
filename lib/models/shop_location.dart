class ShopLocation {
  final String id;
  final String name;
  final String address;
  final String phone;
  final bool active;
  final bool isDefault;
  final String createdAt;

  ShopLocation({
    required this.id,
    required this.name,
    this.address = '',
    this.phone = '',
    this.active = true,
    this.isDefault = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'phone': phone,
        'active': active,
        'isDefault': isDefault,
        'createdAt': createdAt,
      };

  factory ShopLocation.fromMap(Map map) => ShopLocation(
        id: map['id']?.toString() ?? '',
        name: map['name']?.toString() ?? '',
        address: map['address']?.toString() ?? '',
        phone: map['phone']?.toString() ?? '',
        active: map['active'] != false,
        isDefault: map['isDefault'] == true,
        createdAt: map['createdAt']?.toString() ?? '',
      );
}
