import 'package:flutter_test/flutter_test.dart';
import 'package:smartevents/core/format.dart';
import 'package:smartevents/core/password_policy.dart';
import 'package:smartevents/models/models.dart';

void main() {
  group('dates', () {
    test('one-day events show a single date', () {
      final d = DateTime(2027, 1, 23);
      expect(dayCount(d, null), 1);
      expect(dateRange(d, null), '23 Jan 2027');
      expect(dateRange(d, d), '23 Jan 2027');
    });

    test('multi-day events show a range and the number of days', () {
      expect(dateRange(DateTime(2027, 1, 4), DateTime(2027, 1, 6)), '4–6 Jan 2027 · 3 days');
      expect(dateRange(DateTime(2027, 1, 30), DateTime(2027, 2, 2)), '30 Jan – 2 Feb 2027 · 4 days');
      expect(dateRange(DateTime(2026, 12, 30), DateTime(2027, 1, 1), withDays: false), '30 Dec 2026 – 1 Jan 2027');
    });
  });

  group('booking', () {
    Booking booking(Map<String, dynamic> extra) => Booking({
          '_id': 'b1',
          'status': 'negotiating',
          'offerPrice': 1200,
          'customerId': {'_id': 'c1', 'name': 'Ayesha'},
          'vendorId': {'_id': 'v1', 'name': 'Pearl Halls'},
          'negotiationHistory': [
            {'price': 1000, 'offeredBy': 'c1', 'action': 'offer'},
            {'price': 1200, 'offeredBy': 'v1', 'action': 'counter'},
          ],
          ...extra,
        });

    test('it is the organizer\'s turn after the vendor counters', () {
      final b = booking({});
      expect(b.myTurn('c1'), isTrue);
      expect(b.myTurn('v1'), isFalse);
      expect(b.otherName('c1'), 'Pearl Halls');
    });

    test('carries its event (plan) and multi-day dates', () {
      final b = booking({
        'planId': {'_id': 'p1', 'title': 'AI Summit', 'date': '2027-01-04T00:00:00.000Z', 'endDate': '2027-01-06T00:00:00.000Z', 'location': 'Lahore'},
        'eventDetails': {'date': '2027-01-04T00:00:00.000Z', 'endDate': '2027-01-06T00:00:00.000Z', 'eventType': 'Conference', 'location': 'Lahore'},
      });
      expect(b.plan?.title, 'AI Summit');
      expect(dayCount(b.eventDate, b.eventEndDate), 3);
    });

    test('a booking without an event has no plan', () {
      expect(booking({}).plan, isNull);
    });
  });

  test('event plan counts finished tasks', () {
    final plan = EventPlan({
      '_id': 'p1',
      'title': 'Our Nikah',
      'date': '2027-01-29T00:00:00.000Z',
      'tasks': [
        {'_id': 't1', 'title': 'Book the venue', 'status': 'done', 'daysBefore': 60},
        {'_id': 't2', 'title': 'Catering', 'status': 'todo', 'daysBefore': 30},
      ],
    });
    expect(plan.tasks.length, 2);
    expect(plan.doneCount, 1);
    expect(plan.endDate, isNull);
  });

  test('design pictures: full setup and each part', () {
    final d = DesignItem({'_id': 'd1', 'title': 'Spider-Man City', 'elements': [{'item': 'Backdrop'}]});
    expect(d.partUrl(0), contains('/designs/d1/image'));
    expect(d.partUrl(2), endsWith('/designs/d1/image?part=2'));
  });

  test('password rules match the server', () {
    expect(isStrongPassword('abcdefgh'), isFalse);
    expect(isStrongPassword('Ev3nt!Plan#26'), isTrue);
    expect(isStrongPassword('Ayesha!2026x', name: 'Ayesha Khan'), isFalse);
  });
}
