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

import 'package:flutter/cupertino.dart';
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
import 'package:illinois/ui/widgets/ScalableScrollView.dart';

class Covid19OnBoardingResidentInfoPanel extends StatelessWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;
  final Function(Map<String,dynamic>) onSucceed;
  final Function onCancel;

  Covid19OnBoardingResidentInfoPanel({this.onboardingContext, this.onSucceed, this.onCancel});

  @override
  bool get onboardingCanDisplay {
    return !User().isStudentOrEmployee && (onboardingContext != null) && onboardingContext['shouldDisplayResidentInfo'] == true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles().colors.background,
      body: ScalableScrollView(
        scrollableChild: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: <Widget>[
          Container(color: Styles().colors.white, child: Stack(children: <Widget>[
            Covid19OnBoardingIndicator(progress: 0.50,),
            Align(alignment: Alignment.topLeft,
              child: OnboardingBackButton(image: 'images/chevron-left-blue.png', padding: EdgeInsets.only(top: 16, right: 20, bottom: 20), onTap: () => _goBack(context)),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
              Padding(
                  padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 12),
                  child: Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                      child:Text( Localization().getStringEx('panel.health.onboarding.covid19.resident_info.label.title', 'Verify your identity with a government-issued ID',),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary),
                  ))),
              Padding(
                padding: EdgeInsets.only(left: 24, right: 24, bottom: 19),
                child: Text(
                  Localization().getStringEx('panel.health.onboarding.covid19.resident_info.label.description', 'After verifying you will receive a color-coded health status based on your county guidelines, symptoms, and any COVID-19 related tests.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.fillColorPrimary),
                )),
            ],)
          ],),),]),
          bottomNotScrollableWidget: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: <Widget>[
            Padding(padding: EdgeInsets.symmetric(vertical: 17, horizontal: 16), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
              Expanded(child:ScalableRoundedButton(
                label: Localization().getStringEx('panel.health.onboarding.covid19.resident_info.button.passport.title', 'Passport'),
                hint: Localization().getStringEx('panel.health.onboarding.covid19.resident_info.button.passport.hint', ''),
                borderColor: Styles().colors.fillColorSecondary,
                backgroundColor: Styles().colors.white,
                textColor: Styles().colors.fillColorPrimary,
                padding: EdgeInsets.symmetric(horizontal: 22),
                onTap: () => _doScan(context, UserDocumentType.passport),
              )),
              Container(width: 16,),
              Expanded(child: ScalableRoundedButton(
                label: Localization().getStringEx('panel.health.onboarding.covid19.resident_info.button.drivers_license.title', "Driver's License"),
                hint: Localization().getStringEx('panel.health.onboarding.covid19.resident_info.button.drivers_license.hint', ''),
                borderColor: Styles().colors.fillColorSecondary,
                backgroundColor: Styles().colors.white,
                textColor: Styles().colors.fillColorPrimary,
                onTap: () => _doScan(context, UserDocumentType.drivingLicense),
              ),)
            ],),),
            GestureDetector(
              onTap: () => _onTapVerifyLater(context),
              behavior: HitTestBehavior.translucent,
              child: Container(
                child: Padding(
                    padding: EdgeInsets.only(bottom: 20),
                    child: Text(
                        Localization().getStringEx('panel.health.onboarding.covid19.resident_info.button.verify_later.title', "Verify later"),
                      style: TextStyle(
                          fontFamily: Styles().fontFamilies.regular,
                          fontSize: 16,
                          color: Styles().colors.fillColorPrimary,
                          decoration: TextDecoration.underline,
                          decorationColor: Styles().colors.fillColorSecondary,
                          decorationThickness: 1,
                          decorationStyle: TextDecorationStyle.solid),
                    )),
              ),
          )
        ],
      ),)
    ));
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _doScan(BuildContext context, UserDocumentType documentType) {
    
    String analyticsScanType;
    List<String> recognizers;
    if (documentType == UserDocumentType.drivingLicense) {
      Analytics.instance.logSelect(target: "Driver's License") ;
      analyticsScanType = Analytics.LogDocumentScanDrivingLicenseType;
      recognizers = ['combined'];
    }
    else if (documentType == UserDocumentType.passport) {
      Analytics.instance.logSelect(target: 'Passport') ;
      analyticsScanType = Analytics.LogDocumentScanPassportType;
      recognizers = ['passport'];
    }

    NativeCommunicator().microBlinkScan(recognizers: recognizers).then((dynamic result) {
      Analytics().logDocumentScan(type: analyticsScanType, result: (result != null));
      if (result != null) {
        _didScan(context, documentType, result);
      }
    });
  }

  void _didScan(BuildContext context, UserDocumentType documentType, Map<dynamic, dynamic> scanData) {
    if(onboardingContext != null) {
      onboardingContext['shouldDisplayReviewScan'] = true;
      onboardingContext['userDocumentType'] = documentType;
      onboardingContext['scanData'] = scanData;
      Onboarding().next(context, this);
    }
    else if(onSucceed != null){
      onSucceed({
        'userDocumentType': documentType,
        'scanData': scanData
      });
    }
    else{
      Navigator.pop(context);
    }
  }

  void _onTapVerifyLater(BuildContext context) {
    if(onboardingContext != null) {
      Analytics.instance.logSelect(target: 'Verify later');
      onboardingContext['shouldDisplayReviewScan'] = false;
      if (Auth().isLoggedIn) {
        onboardingContext['shouldDisplayQrCode'] = true;
      } else {
        onboardingContext['shouldDisplayQrCode'] = false;
      }
      Onboarding().next(context, this);
    }
    else if(onCancel != null){
      onCancel();
    }
    else{
      Navigator.pop(context);
    }
  }
}
