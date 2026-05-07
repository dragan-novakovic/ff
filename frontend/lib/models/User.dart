class User {
  final String uid;
  final String email;
  String? first_name;
  String? last_name;
  List<String>? contacts;
  List<String>? groups;
  final bool emailVerified;
  final List<String> roles;
  final String username;
  final String createdOnTimestamp;

  User(
    this.uid,
    this.email,
    this.username,
    this.createdOnTimestamp, {
    this.emailVerified = false,
    List<String>? roles,
  }) : roles = roles ?? const ['player'];

  User.fromJson(Map<String, dynamic> json)
      : uid = _requiredString(json, 'uid'),
        email = _requiredString(json, 'email'),
        username = _requiredString(json, 'username'),
        emailVerified = _bool(json['email_verified'] ?? json['emailVerified']),
        roles = _stringList(json['roles']) ?? const ['player'],
        first_name = json['first_name'] ?? json['firstName'],
        last_name = json['last_name'] ?? json['lastName'],
        contacts = _stringList(json['contacts']),
        groups = _stringList(json['groups']),
        createdOnTimestamp =
            (json['created_on'] ?? json['createdOn'] ?? "").toString();

  static Map<String, Object?> toJson(User user) {
    return {
      'uid': user.uid,
      'email': user.email,
      'username': user.username,
      'email_verified': user.emailVerified,
      'roles': user.roles,
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

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.isNotEmpty) {
    return value;
  }

  throw FormatException('Missing required user field "$field".');
}

List<String>? _stringList(Object? value) {
  if (value == null) {
    return null;
  }

  if (value is List<dynamic>) {
    return value.map((item) => item.toString()).toList();
  }

  throw const FormatException('Expected a list of strings.');
}

bool _bool(Object? value) {
  if (value is bool) {
    return value;
  }

  if (value is String) {
    return value.toLowerCase() == 'true';
  }

  return false;
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
