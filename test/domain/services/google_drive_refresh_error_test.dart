import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis_auth/googleapis_auth.dart'
    show ServerRequestFailedException;
import 'package:nexapos_mobile/domain/services/google_drive_backup_service_native.dart';

ServerRequestFailedException _refreshFailure(int? status, Object? content) =>
    ServerRequestFailedException(
      'Failed to obtain access credentials.',
      statusCode: status,
      responseContent: content,
    );

void main() {
  group('googleRefreshTokenRejected', () {
    test(
      'an expired or revoked sign-in (invalid_grant) means connect again',
      () {
        expect(
          googleRefreshTokenRejected(
            _refreshFailure(400, {'error': 'invalid_grant'}),
          ),
          isTrue,
        );
      },
    );

    test(
      'a missing client secret is a broken build, not an expired sign-in',
      () {
        expect(
          googleRefreshTokenRejected(
            _refreshFailure(400, {
              'error': 'invalid_request',
              'error_description': 'client_secret is missing.',
            }),
          ),
          isFalse,
        );
      },
    );

    test('other failures are not mistaken for it', () {
      expect(
        googleRefreshTokenRejected(
          _refreshFailure(500, {'error': 'invalid_grant'}),
        ),
        isFalse,
      );
      expect(
        googleRefreshTokenRejected(_refreshFailure(400, 'invalid_grant')),
        isFalse,
      );
      expect(googleRefreshTokenRejected(_refreshFailure(400, null)), isFalse);
      expect(
        googleRefreshTokenRejected(
          _refreshFailure(null, {'error': 'invalid_grant'}),
        ),
        isFalse,
      );
    });
  });
}
