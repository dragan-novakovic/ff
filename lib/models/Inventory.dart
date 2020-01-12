class UserInventory {
  final String id;
  final int capacity;
  final int specialCurrency;
  final int foodQ1;
  final int weaponQ1;

  UserInventory(
      this.id, this.capacity, this.specialCurrency, this.foodQ1, this.weaponQ1);

  UserInventory.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        capacity = json['capacity'],
        specialCurrency = json['special_currency'],
        foodQ1 = json['food_q1'],
        weaponQ1 = json['weapon_q1'];

  @override
  String toString() {
    return '''INVENTORY {
      id: ${this.id},
      capacity: ${this.capacity},
      }''';
  }
}
