import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:firebase_ml_vision/firebase_ml_vision.dart';
import 'package:flutter/material.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Gallery.dart';
import 'package:illinois/service/Styles.dart';
import 'package:image_picker/image_picker.dart';

class Covid19Utils {

  static Future<bool> saveQRCodeImageToPictures({Uint8List qrCodeBytes, String title}) async {
    if (qrCodeBytes != null) {
      try {

        final recorder = new ui.PictureRecorder();
        Canvas canvas = new Canvas(recorder, new Rect.fromPoints(new Offset(0.0, 0.0), new Offset(1024.0, 1180.0)));
        final fillPaint = new Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill;

        canvas.drawRect(
            new Rect.fromLTWH(0.0, 0.0, 1024.0, 1180.0), fillPaint);

        ui.Codec codec = await ui.instantiateImageCodec(qrCodeBytes);
        ui.FrameInfo frameInfo = await codec.getNextFrame();
        canvas.drawImage(frameInfo.image, Offset(0.0, 156.0), fillPaint);

        final ui.ParagraphBuilder paragraphBuilder = ui.ParagraphBuilder(
          ui.ParagraphStyle(textDirection: ui.TextDirection.ltr, textAlign: TextAlign.center, fontSize: 54, fontFamily: Styles().fontFamilies.bold,),
        )
          ..pushStyle(new ui.TextStyle(color: Styles().colors.textSurface))
          ..addText(title);
        final ui.Paragraph paragraph = paragraphBuilder.build()
          ..layout(ui.ParagraphConstraints(width: 1024));
        double textY = ((1180.0 - 1024.0) - paragraph.height) / 2.0;
        canvas.drawParagraph(paragraph, Offset(0.0, textY));

        final picture = recorder.endRecording();
        final img = await picture.toImage(1024, 1180);
        ByteData pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
        Uint8List newQrBytes = Uint8List(pngBytes.lengthInBytes);
        for (int i = 0; i < pngBytes.lengthInBytes; i++) {
          newQrBytes[i] = pngBytes.getUint8(i);
        }

        String dateTimeStr = AppDateTime.formatDateTime(DateTime.now(), format: "MMMM dd, yyyy, HH:mm:ss a");
        String fileName = "Illinois COVID-19 Code $dateTimeStr";

        return await Gallery().storeImage(imageBytes: newQrBytes, name: fileName);
      }
      catch(e){
      }
    }
    return false;
  }

  static Future<String> loadQRCodeImageFromPictures() async {
    String qrCodeString;
    PickedFile imageFile = await ImagePicker().getImage(source: ImageSource.gallery);
    if (imageFile != null) {
      try {
        final FirebaseVisionImage visionImage = FirebaseVisionImage.fromFile(File(imageFile.path));
        final BarcodeDetector barcodeDetector = FirebaseVision.instance.barcodeDetector(BarcodeDetectorOptions(barcodeFormats: BarcodeFormat.qrCode));
        final List<Barcode> barcodes = await barcodeDetector.detectInImage(visionImage);
        if ((barcodes != null) && (0 < barcodes.length)) {
          Barcode resultBarcode, anyBarcode;
          for (Barcode barcode in barcodes) {
            if (barcode.format.value == BarcodeFormat.qrCode.value) {
              if (barcode.valueType == BarcodeValueType.text) {
                resultBarcode = barcode;
                break;
              }
              else if (anyBarcode == null) {
                anyBarcode = barcode;
              }
            }
          }
          if (resultBarcode == null) {
            resultBarcode = anyBarcode;
          }
          if (resultBarcode != null) {
            qrCodeString = resultBarcode.rawValue;
          }
        }
      }
      catch(e) {
        print(e?.toString());
      }
    }

    return qrCodeString;
  }

}