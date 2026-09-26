import 'package:fin_track/providers/friend_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FriendProvider Unit Tests', () {
    late FriendProvider provider;

    setUp(() {
      provider = FriendProvider();
    });

    tearDown(() {
      provider.dispose();
    });

    test('addFriend validates non-empty phone and name and sets lastError', () async {
      final res = await provider.addFriend(
        userPhone: '',
        friendName: 'Aman',
        friendNumber: '9876543210',
        date: '26/09/2026',
      );

      expect(res, equals(AddFriendResult.failed));
      expect(provider.lastError, isNotNull);
      expect(provider.lastError, contains('cannot be empty'));
    });

    test('clearFriends clears friends state and resets lastError', () {
      provider.setFriendsForTesting([
        {'friend_name': 'Rahul', 'friend_number': '9876500000', 'total_get': 100, 'total_give': 0}
      ], totalGet: 100, totalGive: 0);

      expect(provider.friends.length, equals(1));
      expect(provider.totalGet, equals(100));

      provider.clearFriends();

      expect(provider.friends, isEmpty);
      expect(provider.totalGet, equals(0));
      expect(provider.totalGive, equals(0));
      expect(provider.lastError, isNull);
    });
  });
}
