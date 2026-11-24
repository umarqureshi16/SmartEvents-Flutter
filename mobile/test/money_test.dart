import 'package:flutter_test/flutter_test.dart';
import 'package:smartevents/core/format.dart';

void main() {
  test('shows dollars until the server rates and the country are known', () {
    Money.setCountry('PK');
    expect(Money.currency, 'USD');
    expect(money(120), '\$ 120');
  });

  test('converts stored dollars to the user\'s currency and back', () {
    Money.loadRates({
      'rates': {'USD': 1, 'PKR': 280},
      'countries': {'PK': {'currency': 'PKR'}},
    });
    Money.setCountry('PK');
    expect(Money.currency, 'PKR');
    expect(money(4500), 'Rs 1,260,000');
    expect(Money.toBase(1260000), 4500);
    expect(Money.step, 10000);
    Money.setCountry(null);
    expect(money(10), '\$ 10');
  });
}
