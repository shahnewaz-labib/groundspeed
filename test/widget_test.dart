import 'package:flutter_test/flutter_test.dart';
import 'package:groundspeed/data/gnss_service.dart';
import 'package:groundspeed/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGnssService extends GnssService {
  @override
  Future<void> start() async {}

  void emit(GnssSnapshot snapshot) => debugEmit(snapshot);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('renders live readout from service snapshots', (tester) async {
    final fake = _FakeGnssService();

    await tester.pumpWidget(GroundspeedApp(service: fake));
    await tester.pump();

    expect(find.text('--'), findsOneWidget);
    expect(find.text('ACQUIRING SATELLITES'), findsOneWidget);

    // 20 m/s -> 72.0 km/h
    fake.emit(const GnssSnapshot(
      phase: GnssPhase.locked,
      hasFix: true,
      speedMps: 20,
      rawSpeedMps: 20.4,
      accuracyM: 3.2,
      speedAccuracyM: 0.5,
      satsUsed: 9,
      satsTotal: 14,
      satelliteMonitorSupported: true,
      distanceM: 1240,
      maxSpeedMps: 21,
      history: [5, 9, 14, 18, 20],
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('72.0'), findsOneWidget);
    expect(find.text('KM/H'), findsOneWidget);
    expect(find.text('MAX'), findsOneWidget);
    expect(find.text('DIST'), findsOneWidget);
    expect(find.text('SATS'), findsOneWidget);
    expect(find.text('1.24 km'), findsOneWidget);
    expect(find.text('LOCKED · ±3.2 m · 9 SV'), findsOneWidget);
  });

  testWidgets('switching units reformats the readout', (tester) async {
    final fake = _FakeGnssService();

    await tester.pumpWidget(GroundspeedApp(service: fake));
    await tester.pump();
    fake.emit(const GnssSnapshot(
      phase: GnssPhase.locked,
      hasFix: true,
      speedMps: 20,
      accuracyM: 4,
      speedAccuracyM: 0.4,
    ));
    await tester.pump(const Duration(milliseconds: 300));

    // 20 m/s -> 44.7 mph
    await tester.tap(find.text('MPH'));
    await tester.pumpAndSettle();

    expect(find.text('44.7'), findsOneWidget);
    expect(find.text('MPH'), findsWidgets);
  });

  testWidgets('blocked phases show recovery actions', (tester) async {
    final fake = _FakeGnssService();

    await tester.pumpWidget(GroundspeedApp(service: fake));
    await tester.pump();
    fake.emit(const GnssSnapshot(phase: GnssPhase.denied));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Permission required'), findsOneWidget);
    expect(find.text('Open Settings'), findsOneWidget);
  });
}
