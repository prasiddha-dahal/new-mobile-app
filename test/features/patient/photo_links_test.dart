import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/care_models.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/session_models.dart';
import 'package:sahayatri_care_connect/features/patient/data/models/therapist_models.dart';
import 'package:sahayatri_care_connect/features/therapist/data/models/therapist_models.dart'
    as therapist_side;

/// Photos were only ever on the owner's own profile, so nobody else could see
/// them. The API now sends a photo and a 256px thumbnail on the therapist list
/// and detail, on a patient's session list and next-session card, and -- for a
/// therapist's own views only -- on their patients. These pin that the app
/// reads them from where they are sent.
void main() {
  const photo = '/api/v1/uploads/therapists/t1/photo-ab12.jpg?name=a&size=9';
  const thumb = '/api/v1/uploads/therapists/t1/thumb-ab12.jpg';

  group('a therapist', () {
    Map<String, dynamic> json({String? photoField, String? thumbField}) => {
      'id': 't1',
      'userId': 'u1',
      'name': 'Dr. Anil Shakya',
      'specialty': 'Sports',
      'city': 'Lalitpur',
      'gender': 'Male',
      'rating': 4.9,
      'reviews': 110,
      'price': 1700,
      'experience': 11,
      'bio': '',
      'photo': photoField,
      'photoThumb': thumbField,
    };

    test('carries both links from the list', () {
      final t = TherapistDto.fromJson(json(photoField: photo, thumbField: thumb)).toEntity();

      expect(t.photoUrl, photo);
      expect(t.photoThumbUrl, thumb);
    });

    test('without a photo has none, rather than an empty string', () {
      final t = TherapistDto.fromJson(json()).toEntity();

      expect(t.photoUrl, isNull);
      expect(t.photoThumbUrl, isNull);
    });

    test('an older server that sends neither still parses', () {
      final raw = json()..remove('photo')..remove('photoThumb');

      expect(TherapistDto.fromJson(raw).toEntity().photoThumbUrl, isNull);
    });
  });

  group('a session', () {
    Map<String, dynamic> json(Map<String, dynamic> extra) => {
      'id': 's1',
      'therapistId': 't1',
      'patientId': 'p1',
      'date': '2026-10-10T00:00:00',
      'time': '10:00',
      'type': 'HOME_VISIT',
      'status': 'SCHEDULED',
      'fee': 1500,
      ...extra,
    };

    test("shows the therapist's photo to the patient", () {
      final s = SessionDto.fromJson(json({
        'therapistPhoto': photo,
        'therapistPhotoThumb': thumb,
      })).toEntity();

      expect(s.therapistPhotoUrl, photo);
      expect(s.therapistPhotoThumbUrl, thumb);
      expect(s.patientPhotoThumbUrl, isNull);
    });

    test("shows the patient's photo on a therapist's view", () {
      final s = SessionDto.fromJson(json({
        'patientPhoto': '/api/v1/uploads/patients/p/photo-cd34.jpg',
        'patientPhotoThumb': '/api/v1/uploads/patients/p/thumb-cd34.jpg',
      })).toEntity();

      expect(s.patientPhotoUrl, contains('photo-cd34'));
      expect(s.patientPhotoThumbUrl, contains('thumb-cd34'));
    });

    test('a session with neither is unchanged', () {
      final s = SessionDto.fromJson(json({})).toEntity();

      expect(s.therapistPhotoUrl, isNull);
      expect(s.patientPhotoUrl, isNull);
    });
  });

  test("the home screen's next-session card carries the therapist's photo", () {
    final next = NextSessionDto.fromJson({
      'id': 's1',
      'therapistName': 'Dr. Anil Shakya',
      'therapistPhoto': photo,
      'therapistPhotoThumb': thumb,
    }).toEntity();

    expect(next.therapistPhotoThumbUrl, thumb);
    expect(next.therapistPhotoUrl, photo);
  });

  test("a therapist's patient list carries each patient's thumbnail", () {
    final patient = therapist_side.MyPatientDto.fromJson({
      'id': 'p1',
      'name': 'Asha Rai',
      'photo': '/api/v1/uploads/patients/p/photo-cd34.jpg',
      'photoThumb': '/api/v1/uploads/patients/p/thumb-cd34.jpg',
    });

    expect(patient.photoThumb, contains('thumb-cd34'));
  });

  test("a patient's own profile carries a thumbnail as well", () {
    final profile = PatientProfileDto.fromJson({
      'name': 'Asha',
      'photo': '/api/v1/uploads/patients/p/photo-cd34.jpg',
      'photoThumb': '/api/v1/uploads/patients/p/thumb-cd34.jpg',
    });

    expect(profile.photoThumb, contains('thumb-cd34'));
  });

  test("a therapist's own profile carries one too", () {
    final profile = therapist_side.TherapistProfileDto.fromJson({
      'id': 't1',
      'userId': 'u1',
      'photo': photo,
      'photoThumb': thumb,
    });

    expect(profile.photoThumb, thumb);
  });
}
