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
import 'package:barcode_scan/barcode_scan.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/TrianglePainter.dart';
import 'package:illinois/utils/Covid19.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:pointycastle/export.dart' as PointyCastle;


class Covid19OnBoardingQrCodePanel extends StatefulWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  Covid19OnBoardingQrCodePanel({this.onboardingContext});

  @override
  _Covid19OnBoardingQrCodePanelState createState() => _Covid19OnBoardingQrCodePanelState();

  @override
  bool get onboardingCanDisplay {
    return (onboardingContext != null) && onboardingContext['shouldDisplayQrCode'] == true;
  }
}

class _Covid19OnBoardingQrCodePanelState extends State<Covid19OnBoardingQrCodePanel> {


  PointyCastle.PublicKey _userHealthPublicKey;
  PointyCastle.PrivateKey _userHealthPrivateKey;
  bool _userHealthKeysLoading, _userHealthKeysPaired, _userHealthPublicKeyLoaded, _userHealthPrivateKeyLoaded;
  Uint8List _qrCodeBytes;
  bool _saving = false;

  bool _isRefreshing = false;

  @override
  void initState() {
    _userHealthKeysLoading = true;
    _loadHealthRSAPublicKey();
    _loadHealthRSAPrivateKey();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadHealthRSAPublicKey() {
    Health().loadRSAPublicKey().then((publicKey) {
      if (mounted) {
        _userHealthPublicKey = publicKey;
        _userHealthPublicKeyLoaded = true;
        _verifyHealthRSAKeys();
      }
    });
  }

  void _loadHealthRSAPrivateKey() {
    Health().loadRSAPrivateKey().then((privateKey) {
      if (mounted) {
        _userHealthPrivateKey = privateKey;
        _userHealthPrivateKeyLoaded = true;
        _verifyHealthRSAKeys();
      }
    });
  }

  void _verifyHealthRSAKeys() {

    if ((_userHealthPrivateKey != null) && (_userHealthPublicKey != null)) {
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_userHealthPublicKey, _userHealthPrivateKey)).then((bool result) {
        if (mounted) {
          _userHealthKeysPaired = result;
          _buildHealthRSAQRCode();
        }
      });
    }
    else if ((_userHealthPrivateKeyLoaded == true) && (_userHealthPublicKeyLoaded == true)) {
      _finishHealthRSAKeysLoading();
    }
  }

  void _buildHealthRSAQRCode() {
    Uint8List privateKeyData = (_userHealthKeysPaired && (_userHealthPrivateKey != null)) ? RsaKeyHelper.encodePrivateKeyToPEMDataPKCS1(_userHealthPrivateKey) : null;
    List<int> privateKeyCompressedData = (privateKeyData != null) ? GZipEncoder().encode(privateKeyData) : null;
    String privateKeyString = (privateKeyData != null) ? base64.encode(privateKeyCompressedData) : null;
    if (privateKeyString != null) {
      NativeCommunicator().getBarcodeImageData({
        'content': privateKeyString,
        'format': 'qrCode',
        'width': 1024,
        'height': 1024,
      }).then((Uint8List qrCodeBytes) {
        if (mounted) {
          _qrCodeBytes = qrCodeBytes;
          _finishHealthRSAKeysLoading();
        }
      });
    }
    else {
      _finishHealthRSAKeysLoading();
    }
  }

  void _finishHealthRSAKeysLoading() {
    setState(() {
      _userHealthKeysLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
          backgroundColor: Styles().colors.background,
          body:
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Stack(
                    children: <Widget>[
                      Column(
                        children: <Widget>[
                          Container(height: 90,color: Styles().colors.surface,),
                          CustomPaint(
                            painter: InvertedTrianglePainter(painterColor: Styles().colors.surface, left : true, ),
                            child: Container(
                              height: 67,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              Expanded(child: Image.asset('images/background-onboarding-squares.png', excludeFromSemantics: true,fit: BoxFit.fitWidth,)),
                            ],
                          ),
                        ],
                      ),
                      Container(margin: EdgeInsets.only(top: 80, bottom: 20),child: Center(child: Image.asset('images/group-25.png', excludeFromSemantics: true,))),
                      Align(
                        alignment: Alignment.topLeft,
                        child: OnboardingBackButton(
                            image: 'images/chevron-left-blue.png', padding: EdgeInsets.only(top: 16, right: 20, bottom: 20), onTap: () => _goBack(context)),
                      ),
                      _saving ? Column(
                        children: <Widget>[
                          Expanded(child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,),)),
                        ],
                      ) : Container(),
                    ],
                  ),
                  Expanded( child:
                    Padding(padding: EdgeInsets.symmetric(horizontal: 24),
                      child: (_userHealthKeysLoading == true) ? _buildWaitingContent() : _buildPrivateKeyContent()
                    )),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                      child: Visibility(visible: (_userHealthKeysLoading != true),
                        child: ScalableRoundedButton(
                          label: _getContinueButtonTitle,
                          hint: Localization().getStringEx("panel.health.covid19.qr_code.button.continue.hint", ""),
                          borderColor: Styles().colors.fillColorSecondaryVariant,
                          backgroundColor: Styles().colors.surface,
                          textColor: Styles().colors.fillColorPrimary,
                          onTap: _goNext,
                        )
                      ),
                  )
                ],
              ),
          ),
    );
  }

  Widget _buildWaitingContent(){
    return Center(child:
      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
    );
  }

  Widget _buildPrivateKeyContent(){
    return SingleChildScrollView(
      child: (_qrCodeBytes != null) ? _buildQrCodeContent() : _buildNoQrCodeContent(),
    );
  }

  Widget _buildQrCodeContent(){
    return Container(
      child: Column( children: <Widget>[
        Container(height: 15,),
        Container(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                child:Text(Localization().getStringEx("panel.health.covid19.qr_code.primary.heading.title", "Your COVID-19 Encryption Key"),
                  textAlign: TextAlign.left,
                  style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
                ))
        ),
        Container(height: 15,),
        Text(Localization().getStringEx("panel.health.covid19.qr_code.primary.description.1", "For your privacy, your healthcare data used for COVID-19 features is encrypted. The encryption key is stored locally on your phone to keep it secure. \n\nTo use the COVID-19 features on another device, you will need to manually transfer this encryption key using the QR code below."),
          textAlign: TextAlign.left,
          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
        ),
        Container(height: 30,),
        _buildQrCode(),
        Container(height: 20,),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ScalableRoundedButton(
            label: Localization().getStringEx("panel.health.covid19.qr_code.primary.button.save.title", "Save Your Encryption Key"),
            hint: Localization().getStringEx("panel.health.covid19.qr_code.primary.button.save.hint", ""),
            borderColor: Styles().colors.fillColorSecondaryVariant,
            backgroundColor: Styles().colors.surface,
            fontSize: 16,
            padding: EdgeInsets.symmetric(vertical: 5),
            textColor: Styles().colors.fillColorPrimary,
            onTap: _onSaveImage,
          ),
        ),
        Container(height: 30,),
        Text(Localization().getStringEx("panel.health.covid19.qr_code.primary.description.2", "In the event your current device is lost or damaged, we suggest you save a copy of this QR code to a cloud photo storage service, so that it can be retrieved on your replacement device. \n\nYou can access and save this key on this device at any time by accessing \"Transfer Your COVID-19 Encryption Key\" from the COVID-19 info center."),
          textAlign: TextAlign.left,
          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
        ),
        Container(height: 40,)
      ],)
    );
  }

  Widget _buildNoQrCodeContent(){
    return Container(
        child: Column( children: <Widget>[
          Container(height: 15,),
          Container(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                  child:Text(Localization().getStringEx("panel.health.covid19.qr_code.secondary.heading.title", "Looks like you’ve used this feature before on another device"),
                    textAlign: TextAlign.left,
                    style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color:Styles().colors.fillColorPrimary),
                  ))
          ),
          Container(height: 15,),
          Text(Localization().getStringEx("panel.health.covid19.qr_code.secondary.description.1", "Do you want to transfer your QR encryption key to this device to retrieve your previous health information?\n\nSelect which one applies to you below. You can always transfer a QR encryption key to this device at a later time using the “Transfer Your COVID-19 Encyrption Key” in the COVID-19 info center or in your app settings."),
            textAlign: TextAlign.left,
            style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
          ),
          Container(height: 18,),
          _buildAction(
              heading: Localization().getStringEx("panel.health.covid19.qr_code.secondary.button.scan.heading", "If you are adding a second device:"),
              description: Localization().getStringEx("panel.health.covid19.qr_code.secondary.button.scan.description", "If you still have access to your primary device, you can directly scan the COVID-19 Encryption Key QR code from that device."),
              title: Localization().getStringEx("panel.health.covid19.qr_code.secondary.button.scan.title", "Scan Your QR Code"),
              iconRes: "images/fill-1.png",
              onTap: _onScan
          ),
          Container(height: 12,),
          _buildAction(
              heading: Localization().getStringEx("panel.health.covid19.qr_code.secondary.button.retrieve.heading", "If you are using a replacement device:"),
              description: Localization().getStringEx("panel.health.covid19.qr_code.secondary.button.retrieve.description", "If you no longer have access to your primary device, but saved your QR code to a cloud photo service, you can transfer your COVID-19 Encryption Key by retrieving it from your photos."),
              title: Localization().getStringEx("panel.health.covid19.qr_code.secondary.button.retrieve.title", "Retrieve Your QR Code"),
              iconRes: "images/group-10.png",
              onTap: _onRetrieve
          ),
          Container(height: 12,),
          _buildAction(
              heading: Localization().getStringEx("panel.health.covid19.qr_code.reset.button.heading", "Reset my COVID-19 Secret QRcode:"),
              title: Localization().getStringEx("panel.health.covid19.qr_code.reset.button.title", "Reset my COVID-19 Secret QRcode"),
              iconRes: "images/group-10.png",
              onTap: _onRefreshQrCodeTapped
          ),
          Container(height: 12,),
          Container(height: 40,)
        ],)
    );
  }

  Widget _buildQrCode(){
    return Container(
      decoration: BoxDecoration(
          color: Styles().colors.white,
          borderRadius: BorderRadius.all( Radius.circular(5))),
      padding: EdgeInsets.all(1),
      child: Semantics(child:
        Image.memory(_qrCodeBytes, fit: BoxFit.fitWidth, semanticLabel: Localization().getStringEx("panel.health.covid19.qr_code.primary.heading.title", "Your COVID-19 Encryption Key"),
      )),
    );
  }

  Widget _buildAction({String heading, String description = "", String title, String iconRes, Function onTap}){
    return Semantics(container: true, child:Container(
        decoration: BoxDecoration(
        color: Styles().colors.white,
        borderRadius: BorderRadius.all( Radius.circular(5))),
        child: Column(
          children: <Widget>[
            Container(height: 18,),
            Container( padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(heading, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color:Styles().colors.fillColorPrimary))),
            Container(height: AppString.isStringNotEmpty(description) ? 9 : 0,),
            AppString.isStringNotEmpty(description) ? Container( padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(description, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.fillColorPrimary))) : Container(),
            Container(height: 14,),
            Semantics(
               explicitChildNodes: true,
              child: Container(child:
                GestureDetector(
                  onTap: onTap,
                  child:Container(
                    decoration: BoxDecoration(
                        color: Styles().colors.background,
                        borderRadius: BorderRadius.only( bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5)),
                        border: Border.all(color: Styles().colors.surfaceAccent,)
                    ),
                  padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  child: Row(
                    children: <Widget>[
                      Image.asset(iconRes, excludeFromSemantics: true,),
                      Container(width: 7,),
                      Expanded(child:
                        Container(
                          alignment: Alignment.centerLeft,
                          child: Semantics(button: true, excludeSemantics:false, child:
                            Text(title, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.fillColorPrimary))),
                      )),
                      Image.asset('images/chevron-right.png',excludeFromSemantics: true,),
                    ],
                  ))))),
          ],
        )
    ));
  }

  Widget _buildRefreshQrCodeDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState){
        return ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child:Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Styles().colors.fillColorPrimary,
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: Row(
                              children: <Widget>[
                                Expanded(
                                  child: Center(
                                    child: Text(
                                      Localization().getStringEx("panel.health.covid19.qr_code.dialog.refresh_qr_code.title", "Reset my COVID-19 Secret QRcode"),
                                      style: TextStyle(fontSize: 20, color: Colors.white),
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.pop(context),
                                  child: Container(
                                    height: 30,
                                    width: 30,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.all(Radius.circular(15)),
                                      border: Border.all(color: Styles().colors.white, width: 2),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '\u00D7',
                                        style: TextStyle(
                                          fontSize: 24,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    height: 26,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Text(
                      Localization().getStringEx("panel.health.covid19.qr_code.dialog.refresh_qr_code.description", "Doing this will provide you a new COVID-19 Secret QRcode but your previous COVID-19 event history will be lost, continue?"),

                      textAlign: TextAlign.left,
                      style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                    ),
                  ),
                  Container(
                    height: 26,
                  ),
                  Text(
                    Localization().getStringEx("panel.health.covid19.qr_code.dialog.refresh_qr_code.confirm", "Are you sure?"),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Colors.black),
                  ),
                  Container(
                    height: 26,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Expanded(
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              ScalableRoundedButton(
                                  onTap: () => _onConfirmRefreshQrCode(context, setState),
                                  backgroundColor: Colors.transparent,
                                  borderColor: Styles().colors.fillColorSecondary,
                                  textColor: Styles().colors.fillColorPrimary,
                                  label: Localization().getStringEx("app.common.yes", "Yes")),
                              _isRefreshing ? Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),)) : Container()
                            ],
                          ),
                        ),
                        Container(
                          width: 10,
                        ),
                        Expanded(
                          child: ScalableRoundedButton(
                              onTap: () {
                                Analytics.instance.logAlert(text: "Refresh QR Code", selection: "No");
                                Navigator.pop(context);
                              },
                              backgroundColor: Colors.transparent,
                              borderColor: Styles().colors.fillColorSecondary,
                              textColor: Styles().colors.fillColorPrimary,
                              label: Localization().getStringEx("app.common.no", "No")),
                        )
                      ],
                    ),
                  ),
                ],
              )
            ),
          ),
        );
      },
    );
  }

  //Actions

  void _goNext() {
    Onboarding().next(context, widget);
  }

  void _onSaveImage(){
    if(!_saving) {
      setState(() {
        _saving = true;
      });
      _saveQrImage().whenComplete(() {
        setState(() {
          _saving = false;
        });
      });
    }
  }

  Future<void> _saveQrImage() async{
    Analytics.instance.logSelect(target: "Save Your Encryption Key");
    if (_qrCodeBytes == null) {
      AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.covid19.qr_code.alert.no_qr_code.msg", "There is no QR Code")).then((_) {
        _goNext();
      });
    }
    else {
      bool result = await Covid19Utils.saveQRCodeImageToPictures(qrCodeBytes: _qrCodeBytes, title: Localization().getStringEx("panel.covid19.transfer.label.qr_image_label", "Safer Illinois COVID-19 Code"));
      String platformTargetText = (defaultTargetPlatform == TargetPlatform.android)?Localization().getStringEx("panel.health.covid19.alert.save.success.pictures", "Pictures"): Localization().getStringEx("panel.health.covid19.alert.save.success.gallery", "gallery");
      String message = result
            ? (Localization().getStringEx("panel.covid19.transfer.alert.save.success.msg", "Successfully saved qr code in ") + platformTargetText)
            : Localization().getStringEx("panel.covid19.transfer.alert.save.fail.msg", "Failed to save qr code in ") + platformTargetText;
      AppAlert.showDialogResult(context, message).then((_) {
        _goNext();
      });
    }
  }

  void _onScan(){
    BarcodeScanner.scan().then((result) {
    // barcode_scan plugin returns 8 digits when it cannot read the qr code. Prevent it from storing such values
      if (AppString.isStringEmpty(result) || (result.length <= 8)) {
        AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.covid19.alert.qr_code.scan.failed.msg', 'Failed to read QR code.'));
      }
      else {
        _onCovid19QrCodeScanSucceeded(result);
      }
    });
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _onRetrieve() {
    Analytics.instance.logSelect(target: "Retrieve Your QR Code");
    Covid19Utils.loadQRCodeImageFromPictures().then((String qrCodeString) {
      _onCovid19QrCodeScanSucceeded(qrCodeString);
    });
  }

  void _onCovid19QrCodeScanSucceeded(String result) {

    PointyCastle.PrivateKey privateKey;
    try {
      Uint8List pemCompressedData = (result != null) ? base64.decode(result) : null;
      List<int> pemData = (pemCompressedData != null) ? GZipDecoder().decodeBytes(pemCompressedData) : null;
      privateKey = (pemData != null) ? RsaKeyHelper.parsePrivateKeyFromPemData(pemData) : null;
    }
    catch (e) { print(e?.toString()); }
    
    if (privateKey != null) {
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_userHealthPublicKey, privateKey)).then((bool result) {
        if (mounted) {
          if (result == true) {
            Health().setUserRSAPrivateKey(privateKey).then((success) {
              if (mounted) {
                String resultMessage = success ?
                    Localization().getStringEx("panel.health.covid19.qr_code.alert.qr_code.transfer.succeeded.msg", "COVID-19 secret transferred successfully.") :
                    Localization().getStringEx("panel.health.covid19.alert.qr_code.transfer.failed.msg", "Failed to transfer COVID-19 secret.");
                AppAlert.showDialogResult(context, resultMessage).then((_){
                  if(success) {
                    Navigator.pop(context);
                    _goNext();
                  }
                });
              }
            });
          }
          else {
            AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.covid19.alert.qr_code.not_match.msg', 'COVID-19 secret key does not match existing public RSA key.'));
          }
        }
      });
    }
    else {
      AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.covid19.alert.qr_code.invalid.msg', 'Invalid QR code.'));
    }
  }

  void _onConfirmRefreshQrCode(BuildContext context, Function setStateEx){
    setStateEx(() {
      _isRefreshing = true;
    });

    Health().refreshRSAKeys().then((PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey> rsaKeys) {
      if (mounted) {
        setStateEx((){
          _isRefreshing = false;
        });

        if(rsaKeys != null) {
          Navigator.pop(context);

          _userHealthPrivateKey = rsaKeys.privateKey;
          _userHealthPublicKey = rsaKeys.publicKey;
          _userHealthPrivateKeyLoaded = _userHealthPublicKeyLoaded = true;

          _verifyHealthRSAKeys();
        }
        else{
          AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.covid19.debug.keys.label.error.refres.title","Refresh Failed"));
        }
      }
    });
  }

  void _onRefreshQrCodeTapped() {
    showDialog(context: context, builder: (context) => _buildRefreshQrCodeDialog(context));
  }

  String get _getContinueButtonTitle {
    if (_userHealthKeysLoading == true) {
      return '';
    }
    else if (_qrCodeBytes != null) {
      return Localization().getStringEx("panel.health.covid19.qr_code.button.continue.title", "Continue");
    }
    else {
      return Localization().getStringEx("panel.health.covid19.qr_code.button.transfer_later.title", "Transfer Later");
    }

  }
}