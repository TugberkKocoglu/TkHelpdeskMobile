import 'package:flutter_test/flutter_test.dart';
import 'package:tkhelpdesk_mobile/features/auth/models/auth_tokens.dart';
import 'package:tkhelpdesk_mobile/features/auth/models/auth_user.dart';

void main() {
  test('AuthUser API yanıtından oluşturulur', () {
    final user = AuthUser.fromJson({
      'id': 1,
      'firstName': 'Test',
      'lastName': 'Kullanıcı',
      'email': 'test@example.com',
      'role': 'Helpdesk',
      'departmentId': 1,
    });

    expect(user.fullName, 'Test Kullanıcı');
    expect(user.isHelpdesk, isTrue);
    expect(user.departmentId, 1);
  });

  test('AuthTokens mobil yanıtını okur', () {
    final tokens = AuthTokens.fromJson({
      'accessToken': 'access-example',
      'refreshToken': 'refresh-example',
      'tokenType': 'Bearer',
      'expiresIn': 900,
    });

    expect(tokens.accessToken, 'access-example');
    expect(tokens.refreshToken, 'refresh-example');
    expect(tokens.expiresIn, 900);
  });
}
