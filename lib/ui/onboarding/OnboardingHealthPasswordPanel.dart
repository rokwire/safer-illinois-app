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


class OnboardingHealthPasswordPanel extends StatefulWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  OnboardingHealthPasswordPanel({this.onboardingContext});

  @override
  _OnboardingHealthPasswordPanelState createState() => _OnboardingHealthPasswordPanelState();

  @override
  bool get onboardingCanDisplay {
    return (onboardingContext != null) && kIsWeb &&
        onboardingContext['shouldDisplayQrCode'] == true &&
        onboardingContext['privateKeyLoaded'] == null &&
        Health().hasPrivateKey && !Health().hasEncryptedPrivateKey;
  }
}

class _OnboardingHealthPasswordPanelState extends State<OnboardingHealthPasswordPanel> {

  bool _saving = false;

  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
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
                    ],
                  ),
                  Expanded( child:
                    SingleChildScrollView(
                      child: Padding(padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          children: [
                            Text(
                              Localization().getStringEx("panel.health.covid19.password.description", "Please enter password and remember it."),
                              textAlign: TextAlign.left,
                              style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                            ),
                            TextField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              textAlign: TextAlign.center,
                              obscureText: true,
                              decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                      borderSide: BorderSide(color: Colors.black, width: 1.0)
                                  )
                              ),
                            )
                          ],
                        )
                      ),
                    )),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
                        child: ScalableRoundedButton(
                          label: _getContinueButtonTitle,
                          hint: Localization().getStringEx("panel.health.covid19.qr_code.button.continue.hint", ""),
                          borderColor: Styles().colors.fillColorSecondaryVariant,
                          backgroundColor: Styles().colors.surface,
                          textColor: Styles().colors.fillColorPrimary,
                          onTap: _goNext,
                        ),
                      ),
                      _saving ? Column(
                        children: <Widget>[
                          Expanded(child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,),)),
                        ],
                      ) : Container(),
                    ],
                  ),
                ],
              ),
          ),
    );
  }

  //Actions

  void _goNext() {
    setState(() {
      _saving = true;
    });
    Health().encryptUserPrivateKey(_passwordController.text).then((value){
      setState(() {
        _saving = false;
      });
      Onboarding().next(context, widget);
    }).catchError((error){
      AppAlert.showDialogResult(context, error);
    }).whenComplete((){
      setState(() {
        _saving = false;
      });
    });
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  String get _getContinueButtonTitle {
    return Localization().getStringEx("panel.health.covid19.password.button.continue.title", "Continue");
  }
}