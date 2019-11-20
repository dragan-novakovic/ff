class User {
  final String id;
  final String email;
  final String username;
  final String password;
  final String createdOnTimestamp;
  final PlayerData playerData;

  User(this.id, this.email, this.username, this.password,
      this.createdOnTimestamp, this.playerData);

  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        username = json['username'],
        password = json['password'],
        createdOnTimestamp = json['created_on'],
        playerData = PlayerData.fromJson(json['player_data']);

  @override
  String toString() {
    return '''USER {
      id: ${this.id},
      email: ${this.email},
      username: ${this.username}
      playerData: ${this.playerData}
      }''';
  }
}

class PlayerData {
  final String id;
  final int energy;
  final int gold;
  final int exp;

  PlayerData(this.id, this.energy, this.exp, this.gold);

  PlayerData.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        energy = json['energy'],
        gold = json['gold'],
        exp = json['exp'];

  @override
  String toString() {
    return '''PlayerData {
      id: ${this.id},
      energy: ${this.energy},
      gold: ${this.gold},
      exp: ${this.exp}
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
