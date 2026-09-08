import 'dart:ffi' hide Size;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:printing/src/interface.dart';
import 'package:nexapos_mobile/features/reports/reports_screen.dart';

// Uses the release's PDFium renderer without opening a production POS database.
class _PdfiumPrinting extends PrintingPlatform {
  _PdfiumPrinting(this.dll) {
    dll.lookupFunction<Void Function(), void Function()>('FPDF_InitLibrary')();
  }
  final DynamicLibrary dll;
  double lastDpi = 0;
  int lastWidth = 0;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
  @override
  Future<PrintingInfo> info() async => const PrintingInfo(canRaster: true);
  @override
  Stream<PdfRaster> raster(
    Uint8List document,
    List<int>? pages,
    double dpi,
  ) async* {
    final memory = calloc<Uint8>(document.length);
    memory.asTypedList(document.length).setAll(0, document);
    final doc = dll
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Int32, Pointer<Utf8>),
          Pointer<Void> Function(Pointer<Void>, int, Pointer<Utf8>)
        >('FPDF_LoadMemDocument')(memory.cast(), document.length, nullptr);
    final page = dll
        .lookupFunction<
          Pointer<Void> Function(Pointer<Void>, Int32),
          Pointer<Void> Function(Pointer<Void>, int)
        >('FPDF_LoadPage')(doc, 0);
    final width =
        (dll.lookupFunction<
                  Double Function(Pointer<Void>),
                  double Function(Pointer<Void>)
                >('FPDF_GetPageWidth')(page) *
                dpi /
                72)
            .ceil();
    final height =
        (dll.lookupFunction<
                  Double Function(Pointer<Void>),
                  double Function(Pointer<Void>)
                >('FPDF_GetPageHeight')(page) *
                dpi /
                72)
            .ceil();
    final bitmap = dll
        .lookupFunction<
          Pointer<Void> Function(Int32, Int32, Int32),
          Pointer<Void> Function(int, int, int)
        >('FPDFBitmap_Create')(width, height, 1);
    try {
      dll.lookupFunction<
        Void Function(Pointer<Void>, Int32, Int32, Int32, Int32, Uint32),
        void Function(Pointer<Void>, int, int, int, int, int)
      >('FPDFBitmap_FillRect')(bitmap, 0, 0, width, height, 0xffffffff);
      dll.lookupFunction<
        Void Function(
          Pointer<Void>,
          Pointer<Void>,
          Int32,
          Int32,
          Int32,
          Int32,
          Int32,
          Int32,
        ),
        void Function(
          Pointer<Void>,
          Pointer<Void>,
          int,
          int,
          int,
          int,
          int,
          int,
        )
      >('FPDF_RenderPageBitmap')(bitmap, page, 0, 0, width, height, 0, 1);
      final stride = dll
          .lookupFunction<
            Int32 Function(Pointer<Void>),
            int Function(Pointer<Void>)
          >('FPDFBitmap_GetStride')(bitmap);
      final buffer = dll
          .lookupFunction<
            Pointer<Uint8> Function(Pointer<Void>),
            Pointer<Uint8> Function(Pointer<Void>)
          >('FPDFBitmap_GetBuffer')(bitmap)
          .asTypedList(stride * height);
      final rgba = Uint8List(width * height * 4);
      for (var y = 0; y < height; y++) {
        for (var x = 0; x < width; x++) {
          final source = y * stride + x * 4;
          final target = (y * width + x) * 4;
          rgba[target] = buffer[source + 2];
          rgba[target + 1] = buffer[source + 1];
          rgba[target + 2] = buffer[source];
          rgba[target + 3] = 255;
        }
      }
      lastDpi = dpi;
      lastWidth = width;
      expect(rgba.where((p) => p < 100).length, greaterThan(100));
      yield PdfRaster(width, height, rgba);
    } finally {
      dll.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FPDFBitmap_Destroy')(bitmap);
      dll.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FPDF_ClosePage')(page);
      dll.lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('FPDF_CloseDocument')(doc);
      calloc.free(memory);
    }
  }
}

void main() {
  final library = Platform.environment['NEXAPOS_TEST_PDFIUM'];
  testWidgets(
    'thermal preview renders sharp pixels at desktop zoom and mobile size',
    (tester) async {
      final previous = PrintingPlatform.instance;
      final printing = _PdfiumPrinting(DynamicLibrary.open(library!));
      PrintingPlatform.instance = printing;
      addTearDown(() => PrintingPlatform.instance = previous);
      final pdf = pw.Document();
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(
            58 * PdfPageFormat.mm,
            150 * PdfPageFormat.mm,
            marginAll: 10,
          ),
          build: (_) => pw.Column(
            children: [
              pw.Text(
                'PENTCYBER',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.Text(
                'Powered by NEXAPOS',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Divider(),
              pw.Text('DAILY SALES REPORT'),
              pw.SizedBox(height: 15),
              pw.Text(
                'Printing A4 x1       KES 15.00',
                style: const pw.TextStyle(fontSize: 8),
              ),
              pw.Divider(),
              pw.Text('GRAND TOTAL     KES 15.00'),
              pw.SizedBox(height: 20),
              pw.BarcodeWidget(
                barcode: pw.Barcode.code128(),
                data: '003948451689344937501195',
                height: 40,
              ),
            ],
          ),
        ),
      );
      final bytes = await pdf.save();
      tester.view.physicalSize = const Size(2400, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final capture = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          home: RepaintBoundary(
            key: capture,
            child: ReportPdfPreviewScreen(bytes: bytes, fileName: 'test.pdf'),
          ),
        ),
      );
      Future<void> render() async {
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        for (var i = 0; i < 60; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 100)),
          );
          await tester.pump();
          if (find
              .byType(RawImage)
              .evaluate()
              .any((e) => (e.widget as RawImage).image != null)) {
            return;
          }
        }
        fail('Preview did not display its rendered PDF image.');
      }

      await render();
      await render();
      expect(printing.lastDpi, greaterThanOrEqualTo(300));
      expect(printing.lastWidth, greaterThanOrEqualTo(1040));
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Zoom in'));
        await render();
      }
      expect(printing.lastWidth, greaterThanOrEqualTo(1520));
      expect(
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.zoom_in))
            .onPressed,
        isNull,
      );
      final out = Platform.environment['NEXAPOS_PREVIEW_SCREENSHOT'];
      if (out != null) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 2);
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(out).writeAsBytes(png!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.physicalSize = const Size(780, 1688);
      await render();
      expect(tester.takeException(), isNull);
      expect(find.byTooltip('Save PDF'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
    skip: library == null,
  );
}
