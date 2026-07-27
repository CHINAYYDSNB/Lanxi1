// ignore_for_file: require_trailing_commas

import 'package:flutter_test/flutter_test.dart';
import 'package:lanxi/core/source/panel_detector.dart';

void main() {
  group('PanelDetector', () {
    test('returns onePanel when 1pctl/install dir present', () async {
      final detector = PanelDetector(
        (_) async => '1p',
      );
      expect(await detector.detect(), PanelStatus.onePanel);
    });

    test('returns baota when bt/install dir present', () async {
      final detector = PanelDetector(
        (_) async => 'bt',
      );
      expect(await detector.detect(), PanelStatus.baota);
    });

    test('returns none when neither is found', () async {
      final detector = PanelDetector(
        (_) async => '',
      );
      expect(await detector.detect(), PanelStatus.none);
    });

    test('runs the 1Panel probe before the baota probe', () async {
      final calls = <String>[];
      final detector = PanelDetector((cmd) async {
        calls.add(cmd);
        // First probe matches, so detection should short-circuit.
        return '1p';
      });
      final result = await detector.detect();
      expect(result, PanelStatus.onePanel);
      expect(calls.length, 1);
    });
  });
}
