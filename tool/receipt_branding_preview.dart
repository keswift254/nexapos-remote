import 'dart:io';
import 'package:image/image.dart' as img;
import '../lib/data/printing/receipt_branding.dart';

void main(List<String> args) {
  final output = Directory(args.single)..createSync(recursive: true);
  File('${output.path}/logo.png').writeAsBytesSync(img.encodePng(receiptLogo()));
  File('${output.path}/barcode.png').writeAsBytesSync(img.encodePng(receiptBarcode('112284-20260907073158-FTVQ')));
}
