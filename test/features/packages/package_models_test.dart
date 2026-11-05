import 'package:flutter_test/flutter_test.dart';
import 'package:sahayatri_care_connect/features/packages/data/models/package_models.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/package_purchase.dart';
import 'package:sahayatri_care_connect/features/packages/domain/entities/therapy_package.dart';

/// `GET /api/v1/packages` — the body asserted by `TestListPackages` in the API
/// branch's `test/test_packages.py`, built from the `MOCK_PACKAGE` fixture in
/// `test/conftest.py`. Note `price` arrives as `24000.0`: the fixture holds a
/// float even though the column is `Int`.
const _packageListJson = <String, dynamic>{
  'packages': [
    {
      'id': 'package-1',
      'name': 'Stroke & Neuro Recovery',
      'tag': 'Most requested',
      'icon': 'Brain',
      'price': 24000.0,
      'cadence': 'per month · 12 sessions',
      'blurb': 'Structured neuro-rehab at home.',
      'points': ['Same therapist for the whole plan'],
      'sessionCount': 12,
      'validityDays': 30,
      'featured': true,
      'sortOrder': 1,
      'isActive': true,
      'createdAt': '2024-06-15T10:30:00',
      'updatedAt': '2024-06-15T10:30:00',
    },
  ],
  'total': 1,
};

/// `POST /api/v1/packages/{id}/purchase` — `PackagePurchaseResponse` as
/// asserted by `test_purchase_as_patient`.
const _purchaseJson = <String, dynamic>{
  'id': 'purchase-1',
  'userId': 'patient-1',
  'packageId': 'package-1',
  'packageName': 'Stroke & Neuro Recovery',
  'packageTag': 'Most requested',
  'sessionsTotal': 12,
  'sessionsUsed': 2,
  'sessionsRemaining': 10,
  'status': 'ACTIVE',
  'purchasedAt': '2026-10-11T10:30:00+00:00',
  'expiresAt': '2026-11-10T10:30:00+00:00',
  'createdAt': '2024-06-15T10:30:00',
  'updatedAt': '2024-06-15T10:30:00',
};

/// `GET /api/v1/packages/my-purchases/active` — the detail response adds
/// `payment` (null, because the service never fills it) and `sessions`.
Map<String, dynamic> _activeJson({List<Map<String, dynamic>> sessions = const []}) => {
  ..._purchaseJson,
  'payment': null,
  'sessions': sessions,
};

TherapyPackage _package({
  String name = 'Stroke & Neuro Recovery',
  String tag = 'Most requested from abroad',
  String blurb = '',
  List<String> points = const [],
  int sortOrder = 0,
}) => TherapyPackage(
  id: name,
  name: name,
  tag: tag,
  price: 24000,
  blurb: blurb,
  points: points,
  sortOrder: sortOrder,
);

PackagePurchase _purchase({
  int total = 12,
  int used = 2,
  String status = 'ACTIVE',
  DateTime? expiresAt,
  List<PackageSessionRef> sessions = const [],
}) => PackagePurchase(
  id: 'purchase-1',
  packageId: 'package-1',
  packageName: 'Stroke & Neuro Recovery',
  sessionsTotal: total,
  sessionsUsed: used,
  status: status,
  expiresAt: expiresAt,
  sessions: sessions,
);

void main() {
  group('PackageDto', () {
    test('reads the catalogue body the API actually returns', () {
      final list = PackageListDto.fromJson(_packageListJson);

      expect(list.total, 1);
      final dto = list.packages.single;
      expect(dto.id, 'package-1');
      expect(dto.name, 'Stroke & Neuro Recovery');
      expect(dto.tag, 'Most requested');
      expect(dto.icon, 'Brain');
      // A float price on an Int column must not break the parse.
      expect(dto.price, 24000);
      expect(dto.cadence, 'per month · 12 sessions');
      expect(dto.sessionCount, 12);
      expect(dto.validityDays, 30);
      expect(dto.featured, isTrue);
      expect(dto.points, ['Same therapist for the whole plan']);
      expect(dto.createdAt, DateTime.parse('2024-06-15T10:30:00'));
    });

    test('survives a round-trip through toJson', () {
      final dto = PackageListDto.fromJson(_packageListJson).packages.single;
      final again = PackageDto.fromJson(dto.toJson());

      expect(again.id, dto.id);
      expect(again.price, dto.price);
      expect(again.points, dto.points);
      expect(again.sessionCount, dto.sessionCount);
      expect(again.validityDays, dto.validityDays);
      expect(again.isActive, dto.isActive);
    });

    test('fills in the optional strings the schema defaults', () {
      final dto = PackageDto.fromJson({
        'id': 'p1',
        'name': 'Bare minimum',
        'price': 5000,
      });

      expect(dto.tag, '');
      expect(dto.icon, 'Brain');
      expect(dto.cadence, '');
      expect(dto.points, isEmpty);
      expect(dto.isActive, isTrue);
      expect(dto.createdAt, isNull);
    });

    test('maps to a domain entity with every field carried over', () {
      final entity = PackageListDto.fromJson(
        _packageListJson,
      ).packages.single.toEntity();

      expect(entity.name, 'Stroke & Neuro Recovery');
      expect(entity.price, 24000);
      expect(entity.sessionCount, 12);
      expect(entity.validityDays, 30);
      expect(entity.featured, isTrue);
    });
  });

  group('PackagePurchaseDto', () {
    test('reads the 201 purchase response', () {
      final dto = PackagePurchaseDto.fromJson(_purchaseJson);

      expect(dto.id, 'purchase-1');
      expect(dto.packageName, 'Stroke & Neuro Recovery');
      expect(dto.sessionsTotal, 12);
      expect(dto.sessionsUsed, 2);
      expect(dto.sessionsRemaining, 10);
      expect(dto.status, 'ACTIVE');
      expect(dto.expiresAt, DateTime.parse('2026-11-10T10:30:00+00:00'));
      expect(dto.sessions, isEmpty);
    });

    test('reads the /active detail response, payment and sessions included', () {
      final dto = PackagePurchaseDto.fromJson(
        _activeJson(
          sessions: [
            {
              'id': 'session-1',
              'date': '2026-10-20',
              'time': '10:00',
              'therapistName': 'Test Therapist',
              'status': 'SCHEDULED',
            },
          ],
        ),
      );

      expect(dto.sessions, hasLength(1));
      final session = dto.sessions.single.toEntity();
      expect(session.id, 'session-1');
      expect(session.rawDate, '2026-10-20');
      expect(session.date, DateTime(2026, 10, 20));
      expect(session.time, '10:00');
      expect(session.therapistName, 'Test Therapist');
    });

    test('an empty session list is the list-row shape', () {
      final dto = PackagePurchaseListDto.fromJson({
        'purchases': [_purchaseJson],
        'total': 1,
      });

      expect(dto.total, 1);
      expect(dto.purchases.single.sessions, isEmpty);
    });

    test('survives a round-trip through toJson', () {
      final dto = PackagePurchaseDto.fromJson(_activeJson());
      final again = PackagePurchaseDto.fromJson(dto.toJson());

      expect(again.id, dto.id);
      expect(again.sessionsUsed, dto.sessionsUsed);
      expect(again.purchasedAt, dto.purchasedAt);
      expect(again.expiresAt, dto.expiresAt);
      expect(again.status, dto.status);
    });

    test('purchase request body carries the payment method', () {
      expect(const PackagePurchaseRequestDto(paymentMethod: 'ESEWA').toJson(), {
        'paymentMethod': 'ESEWA',
      });
      expect(const PackagePurchaseRequestDto().toJson()['paymentMethod'], 'CASH');
    });
  });

  group('PackagePurchase progress', () {
    test('a part-used package reports used, remaining and percent', () {
      final p = _purchase();

      expect(p.sessionsRemaining, 10);
      expect(p.progress, closeTo(2 / 12, 1e-9));
      expect(p.progressPercent, 17);
      expect(p.isDepleted, isFalse);
    });

    test('an untouched package is 0%', () {
      final p = _purchase(used: 0);

      expect(p.progress, 0);
      expect(p.progressPercent, 0);
      expect(p.sessionsRemaining, 12);
    });

    test('a fully used package is 100% with nothing left', () {
      final p = _purchase(used: 12);

      expect(p.progress, 1);
      expect(p.progressPercent, 100);
      expect(p.sessionsRemaining, 0);
      expect(p.isDepleted, isTrue);
    });

    test('a zero-session package is 0% and never divides by zero', () {
      final p = _purchase(total: 0, used: 0);

      expect(p.progress, 0);
      expect(p.progressPercent, 0);
      expect(p.sessionsRemaining, 0);
      expect(p.isDepleted, isFalse);
    });

    test('an over-counted sessionsUsed clamps instead of going negative', () {
      final p = _purchase(total: 12, used: 20);

      expect(p.sessionsRemaining, 0);
      expect(p.progress, 1);
      expect(p.progressPercent, 100);
    });
  });

  group('PackagePurchase expiry', () {
    final now = DateTime(2026, 10, 11, 12);

    test('a future expiry is not expired and counts whole days', () {
      final p = _purchase(expiresAt: DateTime(2026, 10, 21, 9));

      expect(p.isExpiredAt(now), isFalse);
      expect(p.daysRemainingAt(now), 10);
      expect(p.isUsableAt(now), isTrue);
    });

    test('expiry later today still reads as 0 days left, not expired', () {
      final p = _purchase(expiresAt: DateTime(2026, 10, 11, 23, 59));

      expect(p.isExpiredAt(now), isFalse);
      expect(p.daysRemainingAt(now), 0);
    });

    test('a past expiry is expired, unusable, and never negative days', () {
      final p = _purchase(expiresAt: DateTime(2026, 10, 1));

      expect(p.isExpiredAt(now), isTrue);
      expect(p.daysRemainingAt(now), 0);
      expect(p.isUsableAt(now), isFalse);
    });

    test('an expired-but-unspent package is still not bookable', () {
      final p = _purchase(used: 0, expiresAt: DateTime(2026, 1, 1));

      expect(p.sessionsRemaining, 12);
      expect(p.isUsableAt(now), isFalse);
    });

    test('a depleted package is not usable even before expiry', () {
      final p = _purchase(
        used: 12,
        status: 'DEPLETED',
        expiresAt: DateTime(2026, 12, 1),
      );

      expect(p.isActive, isFalse);
      expect(p.isUsableAt(now), isFalse);
    });

    test('a missing expiresAt is treated as not expired', () {
      final p = _purchase();

      expect(p.isExpiredAt(now), isFalse);
      expect(p.daysRemainingAt(now), 0);
    });
  });

  group('PackagePurchase.nextSessionAt', () {
    final now = DateTime(2026, 10, 11, 12);

    PackageSessionRef ref(String date, String status) => PackageSessionRef(
      id: '$date-$status',
      rawDate: date,
      date: DateTime.tryParse(date),
      status: status,
    );

    test('picks the soonest scheduled session from a date-desc list', () {
      final p = _purchase(
        sessions: [
          ref('2026-10-25', 'SCHEDULED'),
          ref('2026-10-15', 'SCHEDULED'),
          ref('2026-10-02', 'COMPLETED'),
        ],
      );

      expect(p.nextSessionAt(now)?.rawDate, '2026-10-15');
    });

    test('ignores past, completed and cancelled sessions', () {
      final p = _purchase(
        sessions: [
          ref('2026-10-01', 'SCHEDULED'),
          ref('2026-10-20', 'CANCELLED'),
          ref('2026-10-20', 'COMPLETED'),
        ],
      );

      expect(p.nextSessionAt(now), isNull);
    });

    test("today's session still counts as upcoming", () {
      final p = _purchase(sessions: [ref('2026-10-11', 'SCHEDULED')]);

      expect(p.nextSessionAt(now)?.rawDate, '2026-10-11');
    });

    test('no sessions at all is null, not an error', () {
      expect(_purchase().nextSessionAt(now), isNull);
    });

    test('an unparseable date is skipped rather than crashing', () {
      final p = _purchase(
        sessions: [
          const PackageSessionRef(
            id: 's1',
            rawDate: '',
            status: 'SCHEDULED',
          ),
        ],
      );

      expect(p.nextSessionAt(now), isNull);
    });
  });

  group('PackageCatalogue search', () {
    final catalogue = PackageCatalogue([
      _package(
        name: 'Stroke & Neuro Recovery',
        tag: 'Most requested from abroad',
        blurb: 'Structured neuro-rehab for stroke and Parkinson\'s at home.',
        points: ['Gait, balance and speech-support coordination'],
      ),
      _package(
        name: 'Sports Injury Comeback',
        tag: 'Return to play',
        blurb: 'ACL, rotator cuff, ankle and hamstring rehab.',
        points: ['Sports physio with clinic experience'],
      ),
      _package(
        name: 'Elderly Mobility & Fall Prevention',
        tag: 'For parents at home',
        blurb: 'Keep aging parents walking safely.',
        points: ['Caregiver training included'],
      ),
    ]);

    test('an empty query returns everything', () {
      expect(catalogue.filter(), hasLength(3));
      expect(catalogue.filter(query: '   '), hasLength(3));
    });

    test('matches on the package name, case-insensitively', () {
      expect(catalogue.filter(query: 'sports').single.name,
          'Sports Injury Comeback');
      expect(catalogue.filter(query: 'STROKE').single.name,
          'Stroke & Neuro Recovery');
    });

    test('matches on the blurb — the condition the patient actually types', () {
      expect(catalogue.filter(query: 'ACL').single.name,
          'Sports Injury Comeback');
      expect(catalogue.filter(query: 'parkinson').single.name,
          'Stroke & Neuro Recovery');
    });

    test('matches on an included point', () {
      expect(catalogue.filter(query: 'caregiver').single.name,
          'Elderly Mobility & Fall Prevention');
    });

    test('a query nothing matches returns empty, not everything', () {
      expect(catalogue.filter(query: 'dentistry'), isEmpty);
    });

    test('a tag narrows the list and combines with the query', () {
      expect(
        catalogue.filter(tag: 'Return to play').single.name,
        'Sports Injury Comeback',
      );
      expect(
        catalogue.filter(tag: 'Return to play', query: 'stroke'),
        isEmpty,
      );
    });
  });

  group('PackageCatalogue tag chips', () {
    test('lists distinct, non-blank tags in catalogue order', () {
      final catalogue = PackageCatalogue([
        _package(name: 'A', tag: 'Return to play'),
        _package(name: 'B', tag: ''),
        _package(name: 'C', tag: 'Return to play'),
        _package(name: 'D', tag: 'For parents at home'),
      ]);

      expect(catalogue.tags, ['Return to play', 'For parents at home']);
    });

    test('hides the chip row when every package has its own tag', () {
      // The seeded catalogue: three packages, three different tags. Chips
      // there would each select exactly one card.
      final catalogue = PackageCatalogue([
        _package(name: 'A', tag: 'Most requested from abroad'),
        _package(name: 'B', tag: 'Return to play'),
        _package(name: 'C', tag: 'For parents at home'),
      ]);

      expect(catalogue.hasUsefulTagFilter, isFalse);
    });

    test('shows the chip row once a tag groups more than one package', () {
      final catalogue = PackageCatalogue([
        _package(name: 'A', tag: 'Return to play'),
        _package(name: 'B', tag: 'Return to play'),
        _package(name: 'C', tag: 'For parents at home'),
      ]);

      expect(catalogue.hasUsefulTagFilter, isTrue);
    });

    test('a single tag is not a filter', () {
      final catalogue = PackageCatalogue([
        _package(name: 'A', tag: 'Return to play'),
        _package(name: 'B', tag: 'Return to play'),
      ]);

      expect(catalogue.hasUsefulTagFilter, isFalse);
    });

    test('an empty catalogue has no tags and no chips', () {
      const catalogue = PackageCatalogue([]);

      expect(catalogue.tags, isEmpty);
      expect(catalogue.hasUsefulTagFilter, isFalse);
      expect(catalogue.filter(query: 'anything'), isEmpty);
    });
  });
}
