import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexapos_mobile/data/printing/thermal_printer_service.dart';

import '../../support/fake_secure_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ThermalPrinterService service;

  setUp(() {
    installFakeSecureStorage();
    service = ThermalPrinterService(const FlutterSecureStorage());
  });

  group('PrinterConnectionType.fromStored', () {
    test('recognizes windowsUsb', () {
      expect(PrinterConnectionType.fromStored('windowsUsb'), PrinterConnectionType.windowsUsb);
    });

    test('defaults to network for anything else, including null (a fresh install)', () {
      expect(PrinterConnectionType.fromStored(null), PrinterConnectionType.network);
      expect(PrinterConnectionType.fromStored('network'), PrinterConnectionType.network);
      expect(PrinterConnectionType.fromStored('garbage'), PrinterConnectionType.network);
    });
  });

  group('connection settings round-trip', () {
    test('a fresh device defaults to network with no address saved', () async {
      expect(await service.loadConnectionType(), PrinterConnectionType.network);
      expect(await service.loadIpAddress(), '');
      expect(await service.loadWindowsPrinterName(), '');
    });

    test('saving the network IP persists it', () async {
      await service.saveIpAddress('192.168.1.50');
      expect(await service.loadIpAddress(), '192.168.1.50');
    });

    test('switching to windowsUsb and saving a printer name persists both', () async {
      await service.saveConnectionType(PrinterConnectionType.windowsUsb);
      await service.saveWindowsPrinterName('EPSON TM-T88VI Receipt');
      expect(await service.loadConnectionType(), PrinterConnectionType.windowsUsb);
      expect(await service.loadWindowsPrinterName(), 'EPSON TM-T88VI Receipt');
    });
  });

  group('printReceipt without configuration', () {
    test('network mode with no IP set fails with a clear "not configured" message', () async {
      await expectLater(
        service.printTestPage(58),
        throwsA(
          isA<ThermalPrinterException>().having(
            (e) => e.message,
            'message',
            contains('Thermal printer not configured'),
          ),
        ),
      );
    });

    test('windowsUsb mode with no printer chosen fails with a clear "not configured" message', () async {
      await service.saveConnectionType(PrinterConnectionType.windowsUsb);
      await expectLater(
        service.printTestPage(58),
        throwsA(
          isA<ThermalPrinterException>().having(
            (e) => e.message,
            'message',
            contains('Thermal printer not configured'),
          ),
        ),
      );
    });
  });
}
