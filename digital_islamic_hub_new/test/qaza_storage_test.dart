import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:digital_islamic_hub_new/services/qaza_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Yes does not change counts; No increments qaza', () async {
    expect(await QazaStorage.getQaza('Fajr'), 0);
    await QazaStorage.incrementQaza('Fajr');
    expect(await QazaStorage.getQaza('Fajr'), 1);
    await QazaStorage.decrementQaza('Fajr');
    expect(await QazaStorage.getQaza('Fajr'), 0);
  });
}
