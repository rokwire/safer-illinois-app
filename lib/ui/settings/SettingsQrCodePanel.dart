/*
 * Copyright 2020 Board of Trustees of the University of Illinois.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Covid19.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:pointycastle/export.dart' as secure;

class SettingsQrCodePanel extends StatefulWidget {

  const SettingsQrCodePanel({Key key}) : super(key: key);
  @override
  _SettingsQrCodePanelState createState() => _SettingsQrCodePanelState();
}

class _SettingsQrCodePanelState extends State<SettingsQrCodePanel> {
  Uint8List _qrCodeBytes;

  @override
  void initState() {
    super.initState();
    _loadQrImageBytes().then((imageBytes) {
      setState(() {
        _qrCodeBytes = imageBytes;
      });
    });
  }

  Future<Uint8List> _loadQrImageBytes() async {
    secure.PrivateKey privateKey = Health().userPrivateKey;
    Uint8List privateKeyData = (privateKey != null) ? RsaKeyHelper.encodePrivateKeyToPEMDataPKCS1(privateKey): null;
    List<int> privateKeyCompressedData = (privateKeyData != null) ? GZipEncoder().encode(privateKeyData) : null;
    String privateKeyString = (privateKeyData != null) ? base64.encode(privateKeyCompressedData) : null;
    if (AppString.isStringEmpty(privateKeyString)) {
      return null;
    }
    return await NativeCommunicator().getBarcodeImageData({
      'content': privateKeyString,
      'format': 'qrCode',
      'width': 1024,
      'height': 1024,
    });
  }

  Future<void> _saveQrCode() async{
    Analytics.instance.logSelect(target: "Save QR Code");
    
    if (_qrCodeBytes == null) {
      AppAlert.showDialogResult(context, Localization().getStringEx("panel.covid19.qr_code.alert.no_qr_code.msg", "There is no QR Code"));
    }
    else {
      bool result = await Covid19Utils.saveQRCodeImageToPictures(qrCodeBytes: _qrCodeBytes, title: Localization().getStringEx("panel.covid19.transfer.label.qr_image_label", "Safer Illinois COVID-19 Code"));
      String platformTargetText = (defaultTargetPlatform == TargetPlatform.android)?Localization().getStringEx("panel.health.covid19.alert.save.success.pictures", "Pictures"): Localization().getStringEx("panel.health.covid19.alert.save.success.gallery", "gallery");
      String message = result
          ? (Localization().getStringEx("panel.covid19.transfer.alert.save.success.msg", "Successfully saved qr code in ") + platformTargetText)
          : Localization().getStringEx("panel.covid19.transfer.alert.save.fail.msg", "Failed to save qr code in ") + platformTargetText;
      AppAlert.showDialogResult(context, message);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx('panel.covid19.qr_code.title', 'COVID-19 QR Code'),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      body: SingleChildScrollView(
        child: Container(
          color: Styles().colors.background,
          child: Padding(padding: EdgeInsets.all(24), child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                Localization().getStringEx('panel.covid19.qr_code.description.heading.1', 'If you use more than one device with the Safer Illinois app, use this QR code to transfer the necessary secret to decode your COVID-19 health information.'),
                style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold),),
              Padding(padding: EdgeInsets.only(top: 24), child:
                ((_qrCodeBytes != null) ?
                  Semantics(label: Localization().getStringEx('panel.covid19.qr_code.code.hint', "QR code image"), child:
                    Container(
                      decoration: BoxDecoration(color: Styles().colors.white, borderRadius: BorderRadius.all( Radius.circular(5))),
                      padding: EdgeInsets.all(5), child:
                        Image.memory(_qrCodeBytes, fit: BoxFit.fitWidth, semanticLabel: Localization().getStringEx("panel.health.covid19.qr_code.primary.heading.title", "Your COVID-19 Encryption Key"),
                    ),),) :
                  Container()),
              ),
              Padding(padding: EdgeInsets.only(top: 24), child: Text(
                Localization().getStringEx('panel.covid19.qr_code.description.heading.2', 'Save this QR code so that If you lose or replace your phone, you can retrieve your COVID-19 health information on your new phone.'),
                style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold),),),
              Padding(padding: EdgeInsets.only(top: 24, bottom: 12), child: ScalableRoundedButton(
                label: Localization().getStringEx('panel.covid19.qr_code.button.save.title', 'Save'),
                hint: '',
                backgroundColor: Styles().colors.background,
                fontSize: 16.0,
                textColor: Styles().colors.fillColorPrimary,
                borderColor: Styles().colors.fillColorSecondary,
                onTap: _onTapSave,
              ),),
            ],
          ),),
        ),
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  void _onTapSave() {
    _saveQrCode();
  }
}
