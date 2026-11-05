import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/auth/data/models/auth_models.dart';

void main() {
  group('TokenResponseDto', () {
    test('accepts a therapist signup response with no token', () {
      // The backend returns access_token: null for therapists, whose account
      // cannot sign in until an admin approves it.
      final dto = TokenResponseDto.fromJson({
        'access_token': null,
        'token_type': 'bearer',
        'user': {
          'id': 'u1',
          'name': 'Dr. Anisha Shrestha',
          'email': 'anisha@example.com',
          'role': 'THERAPIST',
          'status': 'PENDING',
        },
      });

      expect(dto.accessToken, isNull);
      expect(dto.user.toEntity().isTherapist, isTrue);
      expect(dto.user.toEntity().isApproved, isFalse);
    });

    test('reads a patient login response', () {
      final dto = TokenResponseDto.fromJson({
        'access_token': 'jwt-token',
        'token_type': 'bearer',
        'user': {
          'id': 'u2',
          'name': 'Aakar Sharma',
          'email': 'patient@test.com',
          'role': 'PATIENT',
          'status': 'APPROVED',
          'mustChangePassword': false,
        },
      });

      expect(dto.accessToken, 'jwt-token');
      expect(dto.user.toEntity().homeRoute, '/patient/home');
    });
  });

  group('camelCase keys survive the global snake_case rename', () {
    test('UserResponseDto reads mustChangePassword', () {
      final dto = UserResponseDto.fromJson({
        'id': 'u3',
        'name': 'Temp User',
        'email': 't@example.com',
        'role': 'THERAPIST',
        'status': 'APPROVED',
        'mustChangePassword': true,
      });

      expect(dto.mustChangePassword, isTrue);
    });

    test('VerificationDocDto serialises camelCase keys', () {
      final json = const VerificationDocDto(
        documentType: 'NMC_LICENSE',
        url: 'https://example.com/a.pdf',
        fileName: 'a.pdf',
        fileSize: 1024,
      ).toJson();

      expect(json.containsKey('documentType'), isTrue);
      expect(json.containsKey('fileName'), isTrue);
      expect(json.containsKey('fileSize'), isTrue);
      expect(json.containsKey('document_type'), isFalse);
    });
  });

  group('SignupRequestDto', () {
    test('omits null fields so the therapist flow can skip the password', () {
      final json = const SignupRequestDto(
        name: 'Dr. Anisha',
        email: 'anisha@example.com',
        role: 'THERAPIST',
      ).toJson();

      expect(json.containsKey('password'), isFalse);
      expect(json['role'], 'THERAPIST');
    });
  });
}
