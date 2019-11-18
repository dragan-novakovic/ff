class User {
  final String id;
  final String email;
  final String username;
  final String password;
  final String createdOnTimestamp;

  User(this.id, this.email, this.username, this.password,
      this.createdOnTimestamp);

  User.fromJson(Map<String, dynamic> json)
      : id = json['id'],
        email = json['email'],
        username = json['username'],
        password = json['password'],
        createdOnTimestamp = json['created_on'];

  @override
  String toString() {
    return '''USER {
      id: ${this.id},
      email: ${this.email},
      username: ${this.username}
      }''';
  }
}
