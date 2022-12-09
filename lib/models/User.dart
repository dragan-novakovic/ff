class User {
  final String uid;
  final String email;
  String? first_name;
  String? last_name;
  List<String>? contacts;
  List<String>? groups;
  final String username;
  final String createdOnTimestamp;

  User(this.uid, this.email, this.username, this.createdOnTimestamp);

  User.fromJson(Map<String, dynamic> json)
      : uid = json['uid'],
        email = json['email'],
        username = json['username'],
        first_name = json['first_name'],
        last_name = json['last_name'],
        contacts = json['contracts'],
        groups = json['groups'],
        createdOnTimestamp = json['created_on'];

  static Map<String, Object?> toJson(User user) {
    return {
      'uid': user.uid,
      'email': user.email,
      'username': user.username,
      'first_name': user.first_name,
      'last_name': user.last_name,
      'contacts': user.contacts,
      'groups': user.groups,
      'created_on': user.createdOnTimestamp
    };
  }

  @override
  String toString() {
    return '''USER {
      uid: ${this.uid},
      email: ${this.email},
      username: ${this.username}
      }''';
  }
}

class PlayerData {
  final String id;
  final int energy;
  final int gold;
  final int exp;
  final String inventoryId;
  final String statsId;

  PlayerData(this.id, this.energy, this.exp, this.gold, this.inventoryId,
      this.statsId);

  PlayerData.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        energy = json['energy'],
        gold = json['gold'],
        inventoryId = json["player_inventory_id"],
        statsId = json['player_stats_id'],
        exp = json['exp'];

  @override
  String toString() {
    return '''PlayerData {
      id: ${this.id},
      energy: ${this.energy},
      gold: ${this.gold},
      exp: ${this.exp}
      inventoryId: ${this.inventoryId},
      statsId: ${this.statsId}
      }''';
  }
}

class PlayerFactories {
  final List<PlayerFactory> playerFactories;

  PlayerFactories(this.playerFactories);

  PlayerFactories.fromJson(List<dynamic> json)
      : playerFactories = json.map((pf) => PlayerFactory.fromJson(pf)).toList();

  @override
  String toString() {
    return '''PlayerFactories {
      len: ${playerFactories.length}
      }''';
  }
}

class PlayerFactory {
  final String id;
  final String userId;
  final String factoryId;
  final int amount;

  PlayerFactory(this.id, this.userId, this.factoryId, this.amount);

  PlayerFactory.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        userId = json['user_id'],
        factoryId = json['factory_id'],
        amount = json['amount'];

  @override
  String toString() {
    return '''PlayerFactory {
      id: ${this.id},
      userId: ${this.userId},
      factoryId: ${this.factoryId},
      amount: ${this.amount}
      }''';
  }
}
