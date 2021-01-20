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

import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/TrianglePainter.dart';

class OnBoardingHealthDisclosurePanel extends StatefulWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  OnBoardingHealthDisclosurePanel({this.onboardingContext});

  bool get onboardingCanDisplay {
    return (onboardingContext != null && onboardingContext['skipOnboarding'] != true) && Platform.isAndroid;
  }

  @override
  State<StatefulWidget> createState() {
    return _OnBoardingHealthDisclosurePanelState();
  }
}

class _OnBoardingHealthDisclosurePanelState extends State<OnBoardingHealthDisclosurePanel>{
  bool _loading = false;
  bool _acknowledge= false;
  bool _canContinue = false;
  ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollListener());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Styles().colors.background,
        body: _buildContent());
  }

  Widget _buildContent(){
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
                             Expanded(child: Image.asset('images/background-onboarding-squares-light.png', excludeFromSemantics: true,fit: BoxFit.fitWidth,)),
                          ],
                        ),
                      ],
                    ),
                    Container(margin: EdgeInsets.only(top: 80, bottom: 20),child: Center(child: Image.asset('images/icon-big-onboarding-privacy.png', excludeFromSemantics: true,))),
                    Align(
                      alignment: Alignment.topLeft,
                      child: OnboardingBackButton(padding: EdgeInsets.only(top: 16, left:16, right: 20, bottom: 20), onTap: () => _goBack(context)),
                    ),
                  ],
                ),
              ]
          ),
          Expanded(child:
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
                controller: _scrollController,
                child: MeasureSize(
                    onChange: (Size size){
                      determineContentCanScroll();
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.one.hint","Header 1"),
                            child:Text(Localization().getStringEx('panel.health.onboarding.covid19.disclosure.label.title', 'Information Usage Disclosure'),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color: Styles().colors.textSurface),
                            )),
                        Container(height: 11,),

                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.two.hint","Header 2"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description1", "The Safer Community app uses:"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 14, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content1", "1. GPS to provide the user interactive maps and outdoor geofenced notifications to find test locations."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),
                        Container(height: 2,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content2", "2. SSID/BSSID (WiFi) to provide geofenced notifications to indoor test locations where GPS does not work."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),
                        Container(height: 2,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content3", "3. Bluetooth to enable opt in exposure notifications of close contact with individuals that test positive for COVID-19."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),
                        Container(height: 2,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content4", "4. Photos to allow a user to import their personal encryption key (QR code) in to the app and to allow reporting of a test result from a non UW-Madison testing center."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),
                        Container(height: 2,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content5", "5. Videos to allow a user to import their personal encryption key (QR code) in to the app and to allow reporting of a test result from a non UW-Madison testing center."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),
                        Container(height: 2,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content6", "6. Files (external storage read and write) to allow a user to import their personal encryption key (QR code) in to the app and to allow reporting of a test result from a non UW-Madison testing center."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),
                        Container(height: 2,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content7", "7. Location services on your device must be turned on to activate the Bluetooth low energy technology necessary for the exposure notification function of the Application. However, the Application does not access, collect, or store any location data, including GPS data. If location services on your device are turned off, the Application will perform the limited functions of storing and providing information about COVID-19 test results, any voluntarily reported symptoms, and building access status."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 14, color:Styles().colors.textSurface),
                        ),

                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.two.hint","Header 2"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description2", "YOUR INFORMATION AND HOW WE USE IT"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 24, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),

                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.three.hint","Header 3"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description3", "Information we need to provide you a COVID-19 Test"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 18, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content8", "Name, University identifier, Birth date, Phone number, Address, Sex, Race, and Ethnicity. This information is reported to public health and your University."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.textSurface),
                        ),
                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.three.hint","Header 3"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description4", "Symptoms"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 18, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content9", "Your COVID-19 Symptoms are reported as anonymous data. "),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.textSurface),
                        ),
                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.three.hint","Header 3"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description5", "COVID-19 Medical History"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 18, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content10", "Events such as test results, symptom reports, being placed in isolation/quarantine are maintained on record but encrypted so your details are private."),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.textSurface),
                        ),
                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.three.hint","Header 3"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description6", "Private Encryption Key Management to protect your health information"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 18, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content11", "Your health history, status, and test results are encrypted on our servers and only you can view them. The following permissions are used to save and restore your secret QR code in your photo library:"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content12", "  - CAMERA"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content13", "  - WRITE_EXTERNAL_STORAGE"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content14", "  - READ_EXTERNAL_STORAGE"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.three.hint","Header 3"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description7", "Assistance navigating to a COVID-19 test site"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 18, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content15", "To assist you in finding a test site on campus, we provide maps for directions and geolocation based notifications when you approach your test site. WiFi and the following permissions are used to enable this:"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content16", "  - LOCATION"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content17", "  - ACCESS_WIFI_STATE"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 11,),
                        Semantics( header: true, hint: Localization().getStringEx("app.common.heading.three.hint","Header 3"),
                            child: Text(Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.description8", "Opt-in exposure notification participation"),
                              style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 18, color:Styles().colors.textSurface),
                            )),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content18", "Your phone transmits and receives anonymous identifying numbers via Bluetooth. This identifier is stored on any phones that come close to you.  If someone tests positive for COVID-19, their phone tells our servers the anonymous numbers they have sent for the last 14 days.  Your phone will check if you were near that infected users' phone long enough to warrant an exposure notification. This is all done anonymously. Your location is never tracked or stored on our servers. The following permissions are used to enable this:"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content19", "  - BLUETOOTH"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content20", "  - BLUETOOTH_ADMIN"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 4,),
                        Text(
                          Localization().getStringEx("panel.health.onboarding.covid19.disclosure.label.content21", "  - LOCATION"),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color:Styles().colors.textSurface),
                        ),
                        Container(height: 10,),
                      ],
                    ))
            ),
          ),),
          Container(
            color: Styles().colors.white,
            height: 12,),
          Container(
            color: Styles().colors.white,
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: ToggleRibbonButton(
              label:  Localization().getStringEx("panel.health.onboarding.covid19.disclosure.check_box.label.acknowledge","Acknowledge"),
              toggled: _acknowledge,
              onTap: _onAknowledgeTap,
              context: context,
              height: null,
//              checkbox: true,
              style: TextStyle(color: _canContinue?Styles().colors.textSurface: Styles().colors.disabledTextColorTwo, fontSize: 16, fontFamily: Styles().fontFamilies.bold),
            ),
          ),
          Container(
            color: Styles().colors.white,
            height: 12,),
          Container(
            color: Styles().colors.white,
              child: Padding(
              padding: EdgeInsets.all(16),
              child: Stack(children: <Widget>[
                ScalableRoundedButton(
                  enabled: _canGoNext,
                  label:_canContinue? Localization().getStringEx('panel.health.onboarding.covid19.disclosure.button.disclosure.title', 'Next') : Localization().getStringEx('panel.health.onboarding.covid19.disclosure.button.scroll_to_continue.title', 'Scroll to Continue'),
                  hint: Localization().getStringEx('panel.health.onboarding.covid19.disclosure.button.disclosure.hint', ''),
                  borderColor: (_canGoNext ? Styles().colors.lightBlue : Styles().colors.disabledTextColorTwo),
                  backgroundColor: (_canGoNext ? Styles().colors.white : Styles().colors.background),
                  textColor: (_canGoNext ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColorTwo),
                  onTap: () => _goNext(context),
                ),
                Visibility(visible: (_loading == true), child:
                  Center(child:
                    Padding(padding: EdgeInsets.only(top: 10), child:
                      Container(width: 24, height:24, child:
                        CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), strokeWidth: 2,)
                      ),
                    ),
                  ),
                ),
            ],),
          ),)
        ],
      ),
    );
  }

  void determineContentCanScroll(){
    if(_scrollController.position.maxScrollExtent==0){
      //There is nothing for scrolling
      setState(() {
        _canContinue = true;
      });
    }
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _goNext(BuildContext context) {
    if (!_canGoNext || _loading) {
      return;
    }
    Analytics.instance.logSelect(target: "Continue");
    Onboarding().next(context, widget);
  }

  void _onAknowledgeTap(){
    if(!_canContinue || _loading){
      return;
    }
    Analytics.instance.logSelect(target: "disclosure");
    setState(() {
      _acknowledge = !_acknowledge;
    });
  }

  void _scrollListener() {
    if (!_canContinue && (_scrollController.offset >= _scrollController.position.maxScrollExtent) && !_scrollController.position.outOfRange) {
      // The user can continue only if he/she scrolls to the bottom of the page.
      setState(() {
        _canContinue = true;
      });
    }
  }

  bool get _canGoNext{
    return _canContinue && _acknowledge;
  }
}

typedef void OnWidgetSizeChange(Size size);

class MeasureSize extends StatefulWidget {
  final Widget child;
  final OnWidgetSizeChange onChange;

  const MeasureSize({
    Key key,
    @required this.onChange,
    @required this.child,
  }) : super(key: key);

  @override
  _MeasureSizeState createState() => _MeasureSizeState();
}

class _MeasureSizeState extends State<MeasureSize> {
  @override
  Widget build(BuildContext context) {
    SchedulerBinding.instance.addPostFrameCallback(postFrameCallback);
    return Container(
      key: widgetKey,
      child: widget.child,
    );
  }

  var widgetKey = GlobalKey();
  var oldSize;

  void postFrameCallback(_) {
    var context = widgetKey.currentContext;
    if (context == null) return;

    var newSize = context.size;
    if (oldSize == newSize) return;

    oldSize = newSize;
    widget.onChange(newSize);
  }
}
