@JS()
library web_js_lib;

import 'package:js/js.dart';
import 'package:universal_html/js_util.dart';

@JS()
external dynamic readQrCodeImage();

@JS()
Future<String> getQrCodeValue() async {
  String qrCode = await promiseToFuture(readQrCodeImage());
  return qrCode;
}
