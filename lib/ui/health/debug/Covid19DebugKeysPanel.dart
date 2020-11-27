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
import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health2.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Covid19.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import "package:pointycastle/export.dart" as PointyCastle;

class Covid19DebugKeysPanel extends StatefulWidget {

  Covid19DebugKeysPanel();

  @override
  _Covid19DebugKeysPanelState createState() => _Covid19DebugKeysPanelState();
}

class _Covid19DebugKeysPanelState extends State<Covid19DebugKeysPanel> {

  TextEditingController _rsaPublicKeyController;
  PointyCastle.PublicKey _rsaPublicKey;

  TextEditingController _rsaPrivateKeyController;
  PointyCastle.PrivateKey _rsaPrivateKey;

  bool _refreshingRSAKeys;
  String _rsaKeysStatus;

  TextEditingController _aesKeyController;
  TextEditingController _blobController;
  TextEditingController _encryptedAesKeyController;
  TextEditingController _encryptedBlobController;
  TextEditingController _decryptedAesKeyController;
  TextEditingController _decryptedBlobController;

  @override
  void initState() {

    _rsaPublicKeyController = TextEditingController();
    _rsaPrivateKeyController = TextEditingController();

    Health2().refreshUser().then((_) {
      if (mounted) {
        setState(() {
          _rsaPublicKey = Health2().user.publicKey;
          _rsaPublicKeyController.text = (_rsaPublicKey != null) ? RsaKeyHelper.encodePublicKeyToPemPKCS1(_rsaPublicKey) : "- NA -";

          _rsaPrivateKey = Health2().userPrivateKey;
          _rsaPrivateKeyController.text = (_rsaPrivateKey != null) ? RsaKeyHelper.encodePrivateKeyToPemPKCS1(_rsaPrivateKey) : "- NA -";

          _rsaKeysStatus = _buildRSAKeysStatus();
        });
      }
    });

    _aesKeyController = TextEditingController();
    _blobController = TextEditingController();

    _encryptedAesKeyController = TextEditingController();
    _encryptedBlobController = TextEditingController();
    
    _decryptedAesKeyController = TextEditingController();
    _decryptedBlobController = TextEditingController();

    super.initState();
  }

  @override
  void dispose() {
    _rsaPublicKeyController.dispose();
    _rsaPrivateKeyController.dispose();

    _aesKeyController.dispose();
    _blobController.dispose();

    _encryptedAesKeyController.dispose();
    _encryptedBlobController.dispose();
    
    _decryptedAesKeyController.dispose();
    _decryptedBlobController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.health.covid19.debug.keys.heading.title","COVID-19 Keys"), style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(padding: EdgeInsets.all(16),
                      child: _buildContent()
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      
      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.public_key","RSA Public Key:") , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _rsaPublicKeyController, maxLines: 6, readOnly: true, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 4), child: Container(),),
      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.private_key","RSA Private Key:") , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _rsaPrivateKeyController, maxLines: 6, readOnly: true, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 4), child: Container(),),
      Row(children: <Widget>[
        Text("RSA Keys Status: " , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
        Text(_rsaKeysStatus ?? '', style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground),),
      ],),
      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),
      _buildRSAKeys1(),
      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),
      _buildRSAKeys2(),
      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),
      _buildRSAKeys3(),

      Padding(padding: EdgeInsets.only(top: 16), child: Container(),),

      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.aes_key","AES Key:") , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _aesKeyController, maxLines: 1, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),
      _buildGenerateAESKey(),

      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),

      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.blob","Blob:") , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _blobController, maxLines: 6, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),
      _buildEncrypt(),

      Padding(padding: EdgeInsets.only(top: 16), child: Container(),),

      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.encripted_aes","Encrypted AES Key:") , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _encryptedAesKeyController, maxLines: 6, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 4), child: Container(),),
      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.encripted_blob","Encrypted Blob:"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _encryptedBlobController, maxLines: 6, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 8), child: Container(),),
      _buildDecrypt(),
      
      Padding(padding: EdgeInsets.only(top: 16), child: Container(),),
      
      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.decripted_aes","Decrypted AES Key:") , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _decryptedAesKeyController, maxLines: 1, readOnly: true, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      Padding(padding: EdgeInsets.only(top: 4), child: Container(),),
      Text(Localization().getStringEx("panel.health.covid19.debug.keys.label.decripted_blob","Decrypted Blob:"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
      TextField(controller: _decryptedBlobController, maxLines: 6, readOnly: true, decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))), style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
      
      Padding(padding: EdgeInsets.only(top: 16), child: Container(),),

    ],);
  }

  Widget _buildRSAKeys1() {
    return Row(children: <Widget>[
      Expanded(child:
      Stack(children: <Widget>[
        RoundedButton(label: "Refresh Pair",
          textColor: (_refreshingRSAKeys != true) ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
          borderColor: (_refreshingRSAKeys != true) ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
          backgroundColor: Styles().colors.white,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16, borderWidth: 2, height: 42,
          onTap:() { _onRefreshRSAKeys();  }
        ),
        Visibility(visible: (_refreshingRSAKeys == true), child:
          Padding(padding: EdgeInsets.only(left: (200 - 21) / 2), child:
            Center(child:
              Padding(padding: EdgeInsets.only(top: 10.5), child:
              Container(width: 21, height:21, child:
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                ),
              ),
            ),
          ),
        ),
      ],),
      ),
      Container(width: 16,),
      Expanded(child:
        Container(),
      ),
    ],);
  }

  Widget _buildRSAKeys2() {
    return Row(children: <Widget>[
      Expanded(child:
        RoundedButton(label: "Scan",
          textColor: Styles().colors.fillColorPrimary,
          borderColor: Styles().colors.fillColorSecondary,
          backgroundColor: Styles().colors.white,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16, borderWidth: 2, height: 42,
          onTap:() { _onScanPrivateRSAKey();  }
        ),
      ),
      Container(width: 16,),
      Expanded(child:
        RoundedButton(label: "Load",
          textColor: Styles().colors.fillColorPrimary,
          borderColor: Styles().colors.fillColorSecondary,
          backgroundColor: Styles().colors.white,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16, borderWidth: 2, height: 42,
          onTap:() { _onLoadPrivateRSAKey();  }
        ),
      ),
    ],);
  }

  Widget _buildRSAKeys3() {
    return Row(children: <Widget>[
      Expanded(child:
        RoundedButton(label: "Save",
          textColor: Styles().colors.fillColorPrimary,
          borderColor: Styles().colors.fillColorSecondary,
          backgroundColor: Styles().colors.white,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16, borderWidth: 2, height: 42,
          onTap:() { _onSavePrivateRSAKey();  }
        ),
      ),
      Container(width: 16,),
      Expanded(child:
        RoundedButton(label: "Clear",
          textColor: (_rsaPrivateKey != null) ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
          borderColor: (_rsaPrivateKey != null) ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
          backgroundColor: Styles().colors.white,
          fontFamily: Styles().fontFamilies.bold,
          fontSize: 16, borderWidth: 2, height: 42,
          onTap:() { _onClearPrivateRSAKey();  }
        ),
      ),
    ],);
  }

  Widget _buildGenerateAESKey() {
    return Row(children: <Widget>[
      RoundedButton(label: Localization().getStringEx("panel.health.covid19.debug.keys.button.generate_aes.title","Generate AES Key"),
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorSecondary,
        backgroundColor: Styles().colors.white,
        fontFamily: Styles().fontFamilies.bold,
        fontSize: 16,
        borderWidth: 2,
        width: 200,
        height: 42,
        onTap:() { _onGenerateAESKey();  }
      ),
    ],);
  }

  Widget _buildEncrypt() {
    return Row(children: <Widget>[
      RoundedButton(label: Localization().getStringEx("panel.health.covid19.debug.keys.button.encript.title","Encrypt"),
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorSecondary,
        backgroundColor: Styles().colors.white,
        fontFamily: Styles().fontFamilies.bold,
        fontSize: 16,
        borderWidth: 2,
        width: 200,
        height: 42,
        onTap:() { _onEncrypt();  }
      ),
    ],);
  }

  Widget _buildDecrypt() {
    return Row(children: <Widget>[
      RoundedButton(label: Localization().getStringEx("panel.health.covid19.debug.keys.button.decript.title","Decrypt"),
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorSecondary,
        backgroundColor: Styles().colors.white,
        fontFamily: Styles().fontFamilies.bold,
        fontSize: 16,
        borderWidth: 2,
        width: 200,
        height: 42,
        onTap:() { _onDecrypt();  }
      ),
    ],);
  }

  String _buildRSAKeysStatus() {
    String status;
    if ((_rsaPublicKey != null) && (_rsaPrivateKey != null)) {
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_rsaPublicKey, _rsaPrivateKey)).then((bool result) {
        if (mounted) {
          setState(() {
            switch (result) {
              case true: _rsaKeysStatus = 'Paired'; break;
              case false: _rsaKeysStatus = 'Unpaired'; break;
              default:    _rsaKeysStatus = 'Internal Error Occured'; break;
            }
          });
        }
      });
    }
    else if ((_rsaPublicKey != null) && (_rsaPrivateKey == null)) {
      status = 'Missing private key';
    }
    else if ((_rsaPublicKey == null) && (_rsaPrivateKey != null)) {
      status = 'Missing public key';
    }
    else {
      status = 'NA';
    }
    return status;
  }

  void _onRefreshRSAKeys() {
    Analytics.instance.logSelect( target: "Refresh RSA Keys");
    setState(() {
      _refreshingRSAKeys = true;
    });
    
    Health2().resetUserKeys().then((PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey> rsaKeys) {
      if (mounted) {
        setState(() {
          _refreshingRSAKeys = false;
          if (rsaKeys != null) {
            _rsaPublicKey = rsaKeys.publicKey;
            _rsaPublicKeyController.text = (_rsaPublicKey != null) ? RsaKeyHelper.encodePublicKeyToPemPKCS1(_rsaPublicKey) : "- NA -";

            _rsaPrivateKey = rsaKeys.privateKey;
            _rsaPrivateKeyController.text = (_rsaPrivateKey != null) ? RsaKeyHelper.encodePrivateKeyToPemPKCS1(_rsaPrivateKey) : "- NA -";

            _rsaKeysStatus = _buildRSAKeysStatus();
          }
          else {
            AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.covid19.debug.keys.label.error.refres.title","Refresh Failed"));
          }
        });
      }
    });
  }

  void _onClearPrivateRSAKey() {
    Health2().setUserPrivateKey(null).then((bool result){
      if (mounted) {
        if (result) {
          setState(() {
            _rsaPrivateKey = null;
            _rsaPrivateKeyController.text = "- NA -";
            _rsaKeysStatus = _buildRSAKeysStatus();
          });
        }
        else {
          AppAlert.showDialogResult(context, "Clear Failed");
        }
      }
    });
  }

  void _onScanPrivateRSAKey() {
    BarcodeScanner.scan().then((String result) {
      // barcode_scan plugin returns 8 digits when it cannot read the qr code. Prevent it from storing such values
      if (AppString.isStringEmpty(result) || (result.length <= 8)) {
        AppAlert.showDialogResult(context, 'Failed to read QR code.');
      }
      else {
        _applyPrivateRsaKeyString(result);
      }
    });
  }

  void _onLoadPrivateRSAKey() {
    Covid19Utils.loadQRCodeImageFromPictures().then((String qrCodeString) {
      _applyPrivateRsaKeyString(qrCodeString);
    });
  }

  void _onSavePrivateRSAKey() {
    String privateKeyString = (_rsaPrivateKey != null) ? RsaKeyHelper.encodePrivateKeyToPemPKCS1(_rsaPrivateKey) : null;
    if (privateKeyString != null) {
      NativeCommunicator().getBarcodeImageData({
        'content': privateKeyString,
        'format': 'qrCode',
        'width': 1024,
        'height': 1024,
      }).then((Uint8List qrCodeBytes) {
        if (qrCodeBytes != null) {
          Covid19Utils.saveQRCodeImageToPictures(qrCodeBytes: qrCodeBytes, title: Localization().getStringEx("panel.covid19.transfer.label.qr_image_label", "Safer Illinois COVID-19 Code")).then((bool result) {
            AppAlert.showDialogResult(context, result ? 'QR Code Image saved.' : 'Failed to save QR Code image.');
          });
        }
        else {
          AppAlert.showDialogResult(context, 'Failed to build QR Code image.');
        }
      });
    }
    else {
      AppAlert.showDialogResult(context, 'No RSA private key.');
    }
  }

  void _applyPrivateRsaKeyString(String result) {

    PointyCastle.PrivateKey privateKey;
    try {
      Uint8List pemCompressedData = (result != null) ? base64.decode(result) : null;
      List<int> pemData = (pemCompressedData != null) ? GZipDecoder().decodeBytes(pemCompressedData) : null;
      privateKey = (pemData != null) ? RsaKeyHelper.parsePrivateKeyFromPemData(pemData) : null;
    }
    catch (e) {
      print(e?.toString());
    }
    
    if (privateKey != null) {
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_rsaPublicKey, privateKey)).then((bool result) {
        if (mounted) {
          if (result == true) {
            Health2().setUserPrivateKey(privateKey).then((success) {
              if (mounted) {
                if (success) {
                  _rsaPrivateKey = privateKey;
                  _rsaPrivateKeyController.text = (_rsaPrivateKey != null) ? RsaKeyHelper.encodePrivateKeyToPemPKCS1(_rsaPrivateKey) : "- NA -";
                  _rsaKeysStatus = _buildRSAKeysStatus();
                }
                else {
                  AppAlert.showDialogResult(context, "Failed to transfer COVID-19 secret.");
                }
              }
            });
          }
          else {
            AppAlert.showDialogResult(context, 'COVID-19 secret key does not match existing public RSA key.');
          }
        }
      });
    }
    else {
      AppAlert.showDialogResult(context, 'Invalid QR code.');
    }
  }

  void _onGenerateAESKey() {
    Analytics.instance.logSelect(target: "Generate AES Keys");
    _aesKeyController.text = AESCrypt.randomKey();
  }

  void _onEncrypt() {
    Analytics.instance.logSelect(target: "Decript");
    if (_rsaPublicKey == null) {
      AppAlert.showDialogResult(context, 'Missing Public RSA Key');
      return;
    }

    if (_rsaPrivateKey == null) {
      AppAlert.showDialogResult(context, 'Missing Private RSA Key');
      return;
    }

    String aesKey = _aesKeyController.text;
    if ((aesKey == null) || aesKey.isEmpty) {
      AppAlert.showDialogResult(context, 'Missing AES Key');
      return;
    }

    String blob = _blobController.text;
    if ((blob == null) || blob.isEmpty) {
      AppAlert.showDialogResult(context, 'Missing Blob');
      return;
    }

    String encryptedBlob = AESCrypt.encrypt(blob, keyString: aesKey);
    String encryptedAESKey = (encryptedBlob != null) ? RSACrypt.encrypt(aesKey, _rsaPublicKey) : null;

    _encryptedAesKeyController.text = encryptedAESKey ?? 'NA';
    _encryptedBlobController.text = encryptedBlob ?? 'NA';

  }

  void _onDecrypt() {
    Analytics.instance.logSelect(target: "Decript");
    String encryptedBlob = _encryptedBlobController.text;
    if ((encryptedBlob == null) || (encryptedBlob == 'NA')  /*|| encryptedBlob.isEmpty*/) {
      AppAlert.showDialogResult(context, 'Missing Encrypted Blob');
      return;
    }

    String encryptedAESKey = _encryptedAesKeyController.text;
    if ((encryptedAESKey == null) || (encryptedAESKey == 'NA') || encryptedAESKey.isEmpty) {
      AppAlert.showDialogResult(context, 'Missing Encrypted AES Key');
      return;
    }


    String decryptedAESKey = (encryptedAESKey != null) ? RSACrypt.decrypt(encryptedAESKey, _rsaPrivateKey) : null;
    String decryptedBlob = ((decryptedAESKey != null) && (encryptedBlob != null)) ? AESCrypt.decrypt(encryptedBlob, keyString: decryptedAESKey) : null;
    
    _decryptedAesKeyController.text = decryptedAESKey ?? 'NA';
    _decryptedBlobController.text = decryptedBlob ?? 'NA';

  }

}

