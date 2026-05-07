import 'package:ff/models/AuthSecurity.dart';
import 'package:ff/models/User.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('auth security models', () {
    test('parse user roles and email verification claims', () {
      final user = User.fromJson({
        'uid': 'player-1',
        'email': 'player@example.com',
        'username': 'player',
        'created_on': '2025-01-01T00:00:00Z',
        'email_verified': true,
        'roles': ['player', 'moderator'],
      });

      expect(user.emailVerified, isTrue);
      expect(user.roles, containsAll(['player', 'moderator']));
      expect(User.toJson(user)['email_verified'], isTrue);
    });

    test('parse security profile sessions and dev token response', () {
      final profile = AccountSecurityProfile.fromJson({
        'user': {
          'uid': 'player-1',
          'email': 'player@example.com',
          'username': 'player',
          'created_on': '2025-01-01T00:00:00Z',
          'email_verified': false,
          'roles': ['player'],
        },
        'sessions': [
          {
            'sessionId': 'session-1',
            'created_at': '2025-01-01T00:00:00Z',
            'expires_at': '2099-01-01T00:00:00Z',
            'last_seen_at': '2025-01-01T00:01:00Z',
          }
        ],
      });
      final result = AuthActionResult.fromJson({
        'message': 'Token issued.',
        'dev_token': 'fft_dev',
        'expires_at': '2025-01-01T00:30:00Z',
      });

      expect(profile.sessions, hasLength(1));
      expect(profile.sessions.single.isActive, isTrue);
      expect(result.devToken, 'fft_dev');
      expect(result.expiresAt, isNotNull);
    });
  });
}
