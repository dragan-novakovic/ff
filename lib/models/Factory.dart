class Factories {
  final List<Factory> factories;

  Factories(this.factories);

  Factories.fromJson(List<dynamic> json)
      : factories = (json).map((fc) => Factory.fromJson((fc))).toList();

  @override
  String toString() {
    return '''FACTORY List {
      factories: ${this.factories},
      }''';
  }
}

class Factory {
  final String id;
  final int level;
  final int goldPerDay;
  final int price;
  final String name;

  Factory(this.id, this.level, this.goldPerDay, this.price, this.name);

  Factory.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        level = json['level'],
        goldPerDay = json['gold_per_day'],
        price = json['price'],
        name = json['name'];

  @override
  String toString() {
    return '''FACTORY {
      id: ${this.id},
      name: ${this.name},
      price: ${this.price}
      }''';
  }
}
