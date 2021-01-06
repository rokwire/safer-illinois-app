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
import 'package:illinois/model/UserProfile.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Exposure.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Settings2GovernmentIdPanel extends StatefulWidget with OnboardingPanel {

  final Map<String,dynamic> initialData;

  Settings2GovernmentIdPanel({this.initialData});

  _Settings2GovernmentIdPanelPanelState createState() => _Settings2GovernmentIdPanelPanelState();

  @override
  bool get onboardingCanDisplay {
    return (onboardingContext != null) && onboardingContext['shouldDisplayReviewScan'] == true;
  }
}

class _Settings2GovernmentIdPanelPanelState extends State<Settings2GovernmentIdPanel> {

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

  static const String kFaceImageFieldName   = 'faceImage';
  static const String kFaceBase64FieldName  = 'faceBase64';

  Map<String, dynamic> _scanResult;
  bool _processingScanResult;
  bool _applyingScanResult;
  UserDocumentType _documenType;
  Map<dynamic, dynamic> _scanData;

  String _fullName;
  String _birthYear;
  MemoryImage _photoImage;

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    _processingScanResult = false;
    _documenType = Auth()?.userPiiData?.documentType;
    _scanData = {};

    _loadInitialData();
  }

  void _loadInitialData(){
    if(widget.initialData != null){
      _scanData = widget.initialData['scanData'];
      _documenType = widget.initialData['userDocumentType'];
      _loadScanResult();
    }
    else{
      _fullName = Auth()?.userPiiData?.fullName;
      _birthYear = Auth()?.userPiiData?.birthYear?.toString() ?? '';
      _loadAsyncPhotoBytes();
    }

  }

  Future<void> _deleteUserData() async{
    Analytics.instance.logAlert(text: "Remove My Information", selection: "Yes");

    await Health().deleteUser();
    await Exposure().deleteUser();
    await Auth().deleteUserPiiData();
    await UserProfile().deleteProfile();
    Auth().logout();
  }

  Future<void> _loadAsyncPhotoBytes() async {
    Uint8List photoBytes = await Auth()?.userPiiData?.photoBytes;
    if(AppCollection.isCollectionNotEmpty(photoBytes)){
      _photoImage = await compute(AppImage.memoryImageWithBytes, photoBytes);
      setState(() {});
    }
  }

  Future<void> _loadScanResult() async{
    compute(_buildScanResult, _scanData).then((Map<String, dynamic> scanResult) {
      setState(() {
        _processingScanResult = false;
        _scanResult = scanResult;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          'Your Government ID',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontFamily: Styles().fontFamilies.extraBold,
            letterSpacing: 1.0,
          ),
          textAlign: TextAlign.center,
        ),
      ),
      backgroundColor: Styles().colors.background,
      body: SafeArea(child: Column(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
        Expanded(child: 
          SingleChildScrollView(child:
            Column(children: <Widget>[
              Container(height: 20,),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('You provided this information to verify your identity during COVID-19 onboarding. You may delete or replace the information below.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: Styles().fontFamilies.regular,
                    color: Styles().colors.textSurface,
                    fontSize: 16
                  ),
                ),
              ),
              _buildPreviewWidget(),
            ],)
          ),
        ),
        Container(height: 12,),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: <Widget>[
              Expanded(
                child: RoundedButton(
                  label: 'Re-scan',
                  hint: '',
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  textColor: Styles().colors.fillColorPrimary,
                  padding: EdgeInsets.symmetric(horizontal: 22),
                  onTap: () => _onRescan(),
                  height: 48,
                ),
              ),
              Container(width: 12,),
              Expanded(
                child: Stack(children: <Widget>[
                  RoundedButton(
                    label: "Use This Scan",
                    hint: '',
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
            ],
          ),
        ),
        Container(height: 16,),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: RoundedButton(
            label: 'Delete my COVID-19 Information',
            hint: '',
            backgroundColor: Styles().colors.surface,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorSecondary,
            borderColor: Styles().colors.surfaceAccent,
            onTap: _onRemoveMyInfoClicked,

          ),
        ),
        Container(height: 16,)
      ],),),
    );
  }

  Widget _buildPreviewWidget() {
    MemoryImage faceImage = (_scanResult != null) ? _scanResult[kFaceImageFieldName] : _photoImage;

    String nameText = ((_scanResult != null) ? _scanResult[kFullNameFieldName] : _fullName) ?? '';
    String nameLabel = nameText.isNotEmpty ? 'Name' : '';

    String birthYearText = ((_scanResult != null) ? _scanResult[kBirthYearFieldName] : _birthYear) ?? '';
    String birthYearLabel = birthYearText.isNotEmpty ? 'Birth Year' : '';

    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
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

  Widget _buildRemoveMyInfoDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState){
        return ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Container(
                        color: Styles().colors.fillColorPrimary,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Center(
                                  child: Text(
                                    "Remove My Info",
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
                    "By answering YES all your personal information and preferences will be deleted from our systems. This action can not  be recovered.  After deleting the information we will return you to the first screen when you installed the app so you can start again or delete the app.",
                    textAlign: TextAlign.left,
                    style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                  ),
                ),
                Container(
                  height: 26,
                ),
                Text(
                  "Are you sure?",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Colors.black),
                ),
                Container(
                  height: 26,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Stack(
                        children: <Widget>[
                          RoundedButton(
                              onTap: () => _onConfirmRemoveMyInfo(context, setState),
                              backgroundColor: Colors.transparent,
                              borderColor: Styles().colors.fillColorSecondary,
                              textColor: Styles().colors.fillColorPrimary,
                              label: Localization().getStringEx("panel.profile_info.dialog.remove_my_information.yes.title", "Yes")),
                          _isDeleting ? Align(alignment: Alignment.center, child: CircularProgressIndicator()) : Container()
                        ],
                      ),
                      Container(
                        height: 10,
                      ),
                      RoundedButton(
                          onTap: () {
                            Analytics.instance.logAlert(text: "Remove My Information", selection: "No");
                            Navigator.pop(context);
                          },
                          backgroundColor: Colors.transparent,
                          borderColor: Styles().colors.fillColorSecondary,
                          textColor: Styles().colors.fillColorPrimary,
                          label: Localization().getStringEx("panel.profile_info.dialog.remove_my_information.no.title", "No"))
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
  }

  void _didRescan(Map<dynamic, dynamic> scanData) {
    setState(() {
      _processingScanResult = true;
    });
    compute(_buildScanResult, scanData).then((Map<String, dynamic> scanResult) {
        setState(() {
          _processingScanResult = false;
          _scanResult = scanResult;
        });
    });

  }

  void _onUseScan() {
    Analytics.instance.logSelect(target: 'Use This Scan') ;
    
    if (_scanResult == null) {
      Navigator.pop(context);
    }

    setState(() {
      _applyingScanResult = true;
    });

    _applyScan().then((bool result){

      setState(() {
        _applyingScanResult = false;
      });

      if (result) {
        Navigator.pop(context);
      }
      else {
        AppAlert.showDialogResult(context, 'Failed to apply scanned data');
      }
    });
  }

  void _onConfirmRemoveMyInfo(BuildContext context, Function setState){
    setState(() {
      _isDeleting = true;
    });
    _deleteUserData()
        .then((_){
      Navigator.pop(context);
    })
        .whenComplete((){
      setState(() {
        _isDeleting = false;
      });
    })
        .catchError((error){
      AppAlert.showDialogResult(context, error.toString()).then((_){
        Navigator.pop(context);
      });
    });


  }

  void _onRemoveMyInfoClicked() {
    showDialog(context: context, builder: (context) => _buildRemoveMyInfoDialog(context));
  }
}