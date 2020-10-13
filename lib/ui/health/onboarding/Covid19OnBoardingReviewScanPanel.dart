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

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/model/UserPiiData.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingIndicator.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19OnBoardingReviewScanPanel extends StatefulWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  Covid19OnBoardingReviewScanPanel({this.onboardingContext});

  _Covid19OnBoardingReviewScanPanelState createState() => _Covid19OnBoardingReviewScanPanelState();

  @override
  bool get onboardingCanDisplay {
    return !User().roles.contains(UserRole.student) && !User().roles.contains(UserRole.employee) && (onboardingContext != null) && onboardingContext['shouldDisplayReviewScan'] == true;
  }
}

class _Covid19OnBoardingReviewScanPanelState extends State<Covid19OnBoardingReviewScanPanel> {

  static const String kFirstNameFieldName   = 'firstName';
  static const String kMiddleNameFieldName  = 'middleName';
  static const String kLastNameFieldName    = 'lastName';
  static const String kFullNameFieldName    = 'fullName';

  static const String kBirthYearFieldName   = 'birthYear';

  static const String kAddressFieldName     = 'address';
  static const String kStateFieldName       = 'state';
  static const String kZipFieldName         = 'zip';
  static const String kCountryFieldName     = 'country';
  static const String kFullAddressFieldName = 'fullAddress';

  /*static const String kHomeCountyFieldName  = 'homeCounty';
  static const String kWorkCountyFieldName  = 'workCounty';
  static const String kProvidersFieldName   = 'providers';
  static const String kConsentFieldName     = 'consent';*/

  static const String kFaceImageFieldName   = 'faceImage';
  static const String kFaceBase64FieldName  = 'faceBase64';

  Map<String, dynamic> _scanResult;
  bool _processingScanResult;
  bool _applyingScanResult;
  UserDocumentType _documenType;
  Map<dynamic, dynamic> _scanData;

  @override
  void initState() {
    _processingScanResult = true;
    _documenType = widget.onboardingContext['userDocumentType'];
    _scanData = widget.onboardingContext['scanData'];
    compute(_buildScanResult, _scanData).then((Map<String, dynamic> scanResult) {
        setState(() {
          _processingScanResult = false;
          _scanResult = scanResult;
        });
    });

    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles().colors.background,
      body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Container(color: Styles().colors.white, child: Stack(children: <Widget>[
          Covid19OnBoardingIndicator(progress: 0.75,),
          Align(alignment: Alignment.topLeft,
            child: OnboardingBackButton(image: 'images/chevron-left-blue.png', padding: EdgeInsets.only(top: 16, right: 20, bottom: 20), onTap: () => _goBack()),
          ),
          Align(alignment: Alignment.topCenter, child:
            Padding(padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12), child:
              Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                child:Text(Localization().getStringEx('panel.health.onboarding.covid19.review_scan.label.title', 'Review your scan',),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),
              ))
            ),
          ),
        ],),),
        Expanded(child: 
          SingleChildScrollView(child:
            Column(children: <Widget>[
              _buildPreviewWidget(),
            ],)
          ),
        ),
        Container(height: 12,),
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: 
          RoundedButton(
            label: Localization().getStringEx('panel.health.onboarding.covid19.review_scan.button.rescan.title', 'Re-scan'),
            hint: Localization().getStringEx('panel.health.onboarding.covid19.review_scan.button.rescan.hint', ''),
            borderColor: Styles().colors.fillColorSecondary,
            backgroundColor: Styles().colors.white,
            textColor: Styles().colors.fillColorPrimary,
            padding: EdgeInsets.symmetric(horizontal: 22),
            onTap: () => _onRescan(),
            height: 48,
          ),),
        Container(height: 12,),
        Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: 
          Stack(children: <Widget>[
            RoundedButton(
              label: Localization().getStringEx('panel.health.onboarding.covid19.review_scan.button.use_scan.title', "Use This Scan"),
              hint: Localization().getStringEx('panel.health.onboarding.covid19.review_scan.button.use_scan.hint', ''),
              borderColor: Styles().colors.fillColorSecondary,
              backgroundColor: Styles().colors.white,
              textColor: Styles().colors.fillColorPrimary,
              onTap: () => _onUseScan(),
              height: 48,
            ),
            Visibility(visible: (_applyingScanResult == true),
              child: Container(height: 48,
                child: Align(alignment: Alignment.center,
                  child: SizedBox(height: 24, width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                  ),
                ),
              ),
            ),
          ],),
        ),
        Container(height: 24,),
      ],),),
    );
  }

  Widget _buildPreviewWidget() {
    MemoryImage faceImage = (_scanResult != null) ? _scanResult[kFaceImageFieldName] : null;

    String nameText = ((_scanResult != null) ? _scanResult[kFullNameFieldName] : null) ?? '';
    String nameLabel = nameText.isNotEmpty ? Localization().getStringEx('panel.health.onboarding.covid19.review_scan.label.name.title', 'Name',) : '';

    String birthYearText = ((_scanResult != null) ? _scanResult[kBirthYearFieldName] : null) ?? '';
    String birthYearLabel = birthYearText.isNotEmpty ? Localization().getStringEx('panel.health.onboarding.covid19.review_scan.label.birth_year.title', 'Birth Year',) : '';

    return Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Styles().colors.white,
          borderRadius: BorderRadius.all(Radius.circular(4)),
          boxShadow: [BoxShadow(color: Styles().colors.fillColorPrimaryTransparent015, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(0, 2))],
        ),
        child: Stack(children: <Widget>[
          Visibility(visible: (_processingScanResult != true), child:
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Container(width: 55, height: 70,
                decoration: BoxDecoration(
                  color: Styles().colors.fillColorPrimaryTransparent03,
                  borderRadius: BorderRadius.all(Radius.circular(2)),
                  image: (faceImage != null) ? DecorationImage(fit: BoxFit.cover, alignment: Alignment.center, image: faceImage) : null,
                ),
              ),
              Expanded(
                child: Padding(padding: EdgeInsets.only(left: 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(nameLabel, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface)),
                    Text(nameText, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary)),
                    Container(height: 16,),
                    Text(birthYearLabel, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface)),
                    Text(birthYearText, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary)),
                  ],),
                ),
              ),
            ],),
          ),
          Visibility(visible: (_processingScanResult == true),
            child: Container(
              height: 70,
              child: Align(alignment: Alignment.center,
                child: SizedBox(height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                ),
              ),
            ),
          ),          
        ],)
        
        
      ),
    );
  }

  static Map<String, dynamic> _buildScanResult(Map<dynamic, dynamic> rawResult) {

    Map<dynamic, dynamic> rawMrz = rawResult['mrz'];
    
    String rawFirstName = rawResult['firstName'];       // "WILLIAM C III"
    if ((rawFirstName == null) && (rawMrz != null)) {
      rawFirstName = rawMrz['secondaryID'];             // "PETER MARK"
    }
    String firstName = _buildName(rawFirstName);
    String middleName = _buildName(rawFirstName, index: 1);
    
    String rawLastName = rawResult['lastName'];         // "SULLIVAN"
    if ((rawLastName == null) && (rawMrz != null)) {
      rawLastName = rawMrz['primaryID'];                // "HENNESSY"
    }
    String lastName = _buildName(rawLastName);
    
    String dateOfBirth = rawResult['dateOfBirth'];    // "09/30/1958"
    if ((dateOfBirth == null) && (rawMrz != null)) {
      dateOfBirth = rawMrz['dateOfBirth'];            // "11/22/1960"
    }
    String birthYear = ((dateOfBirth != null) && RegExp('[0-9]{2}/[0-9]{2}/[0-9]{4}').hasMatch(dateOfBirth)) ? dateOfBirth.substring(6, 10) : null;

    String country;
    if (rawMrz != null) {
      for (String key in ['sanitizedNationality', 'nationality', 'sanitizedIssuer', 'issuer']) {
        String entry = rawMrz[key];
        if ((entry != null) && (0 < entry.length)) {
          country = entry;
          break;
        }
      }
    }

    String rawAddress = rawResult['address']; // "1804 PLEASANT ST, URBANA, IL, 618010000"
    String address = rawAddress, state, zip;
    if (rawAddress != null) {
      List<String> addressComponents = rawAddress.split(',');
      int componentsCount = addressComponents.length;
      if ((addressComponents != null) && (1 < componentsCount)) {
        
        String aZip = addressComponents[componentsCount - 1].trim();
        bool hasZip = RegExp('[0-9]{5,}').hasMatch(aZip);
        
        String aState = addressComponents[componentsCount - 2].trim();
        bool hasState = RegExp('[a-zA-Z]{2,}').hasMatch(aState);

        if (hasZip && hasState) {
          zip = aZip.substring(0, 5);
          state = aState;
          if (country == null) {
            country = 'USA';
          }

          address = '';
          for (int index = 0; (index + 2) < componentsCount; index++) {
            if (0 < index) {
              address += ',';
            }
            address += addressComponents[index];
          }
        }
      }
    }

    String fullName = '';
    if ((firstName != null) && (0 < firstName.length)) {
      fullName += "${(0 < fullName.length) ? ' ' : ''}$firstName";
    }
    if ((middleName != null) && (0 < middleName.length)) {
      fullName += "${(0 < fullName.length) ? ' ' : ''}$middleName";
    }
    if ((lastName != null) && (0 < lastName.length)) {
      fullName += "${(0 < fullName.length) ? ' ' : ''}$lastName";
    }

    String fullAddress = address ?? '';
    if ((state != null) && (zip != null)) {
      fullAddress += "${(0 < fullAddress.length) ? ', ' : ''}$state $zip";
    }
    else if (state != null) {
      fullAddress += "${(0 < fullAddress.length) ? ', ' : ''}$state";
    }
    else if (zip != null) {
      fullAddress += "${(0 < fullAddress.length) ? ', ' : ''}$zip";
    }
    if (country != null) {
      fullAddress += "${(0 < fullAddress.length) ? ', ' : ''}$country";
    }

    String base64FaceImage = rawResult['base64FaceImage'];
    Uint8List faceImageData = (base64FaceImage != null) ? base64Decode(base64FaceImage) : null;
    MemoryImage faceImage = (faceImageData != null) ? MemoryImage(faceImageData) : null;

    return {
      // These should go to PII
      kFirstNameFieldName   : firstName,
      kMiddleNameFieldName  : middleName,
      kLastNameFieldName    : lastName,
      kBirthYearFieldName   : birthYear,
      kAddressFieldName     : address,
      kStateFieldName       : state,
      kZipFieldName         : zip,
      kCountryFieldName     : country,
      kFaceBase64FieldName  : base64FaceImage,

      // These are for display purpose only
      kFullNameFieldName    : fullName,
      kFullAddressFieldName : fullAddress,
      kFaceImageFieldName   : faceImage,
    };
  }

  static String _buildName(String rawName, {int index = 0}) {
    String resultName;
    if (rawName != null) {
      List<String> firstNameComponents = rawName.split(' ');
      if ((firstNameComponents != null) && (0 <= index) && (index < firstNameComponents.length)) {
        resultName = firstNameComponents[index];
      }
      else if (index == 0) {
        resultName = rawName;
      }
      resultName = (resultName != null) ? AppString.capitalize(resultName) : null;
    }
    return resultName;
  }

  Future<bool> _applyScan() async {

    UserPiiData updatedUserPiiData;
    UserPiiData userPiiData = UserPiiData.fromObject(await Auth().reloadUserPiiData());
    if (userPiiData != null) {
      _applyScanResult(userPiiData);
      updatedUserPiiData = await Auth().storeUserPiiData(userPiiData);
    }

    return (updatedUserPiiData != null);
  }

  void _applyScanResult(UserPiiData userPiiData) {
    
    String photoBase64 = _scanResult[kFaceBase64FieldName];
    if (photoBase64 != null) {
      userPiiData.photoBase64 = photoBase64;
    }

    String firstName = _scanResult[kFirstNameFieldName];
    if (firstName != null) {
      userPiiData.firstName = firstName;
    }

    String middleName = _scanResult[kMiddleNameFieldName];
    if (middleName != null) {
      userPiiData.middleName = middleName;
    }

    String lastName = _scanResult[kLastNameFieldName];
    if (lastName != null) {
      userPiiData.lastName = lastName;
    }

    String birthYearString = _scanResult[kBirthYearFieldName];
    int birthYear = ((birthYearString != null) && (0 < birthYearString.length)) ? int.tryParse(birthYearString) : null;
    if (birthYear != null) {
      userPiiData.birthYear = birthYear;
    }

    //Don't store this data in PiiData for now
/*    String address = _scanResult[kAddressFieldName];
    if ((address != null) && (0 < address.length)) {
      userPiiData.address = address;
    }

    String state = _scanResult[kStateFieldName];
    if ((state != null) && (0 < state.length)) {
      userPiiData.state = state;
    }

    String zip = _scanResult[kZipFieldName];
    if ((zip != null) && (0 < zip.length)) {
      userPiiData.zip = zip;
    }

    String country = _scanResult[kCountryFieldName];
    if ((country != null) && (0 < country.length)) {
      userPiiData.country = country;
    }*/

    if (_documenType != null) {
      userPiiData.documentType = _documenType;
    }
}

  void _goBack() {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _goNext() {
    if (Auth().isLoggedIn) {
      widget.onboardingContext['shouldDisplayQrCode'] = true;
    } else {
      widget.onboardingContext['shouldDisplayQrCode'] = false;
    }
    Onboarding().next(context, widget);
  }

  void _onRescan() {
    Analytics.instance.logSelect(target: 'Re-scan') ;

    String analyticsScanType;
    List<String> recognizers;
    if (_documenType == UserDocumentType.drivingLicense) {
      analyticsScanType = Analytics.LogDocumentScanDrivingLicenseType;
      recognizers = ['combined'];
    }
    else if (_documenType == UserDocumentType.passport) {
      analyticsScanType = Analytics.LogDocumentScanPassportType;
      recognizers = ['passport'];
    }

    NativeCommunicator().microBlinkScan(recognizers: recognizers).then((dynamic result) {
      Analytics().logDocumentScan(type: analyticsScanType, result: (result != null));
      if (result != null) {
        _didRescan(result);
      }
    });
  }

  void _didRescan(Map<dynamic, dynamic> scanData) {
    setState(() {
      _processingScanResult = true;
    });
    compute(_buildScanResult, _scanData).then((Map<String, dynamic> scanResult) {
        setState(() {
          _processingScanResult = false;
          _scanResult = scanResult;
        });
    });

  }

  void _onUseScan() {
    Analytics.instance.logSelect(target: 'Use This Scan') ;
    
    if (_scanResult == null) {
      return;
    }

    setState(() {
      _applyingScanResult = true;
    });

    _applyScan().then((bool result){

      setState(() {
        _applyingScanResult = false;
      });

      if (result) {
        _goNext();
      }
      else {
        AppAlert.showDialogResult(context, Localization().getStringEx('panel.health.onboarding.covid19.review_scan.message.failed', 'Failed to apply scanned data',));
      }
    });
  }

}