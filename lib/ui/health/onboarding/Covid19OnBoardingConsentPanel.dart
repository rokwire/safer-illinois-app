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
import 'package:flutter/scheduler.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Onboarding.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/onboarding/OnboardingBackButton.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/TrianglePainter.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19OnBoardingConsentPanel extends StatefulWidget with OnboardingPanel {

  final Map<String, dynamic> onboardingContext;

  Covid19OnBoardingConsentPanel({this.onboardingContext});

  @override
  State<StatefulWidget> createState() {
    return _Covid19OnBoardingConsentPanelState();
  }

}

class _Covid19OnBoardingConsentPanelState extends State<Covid19OnBoardingConsentPanel>{
  bool _loading = false;
  bool _exposureNotification = false;
  bool _consent = true;
  bool _canContinue = false;
  ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_scrollListener);
    //19.06 - 5.1 Covid setup flow consents should be off by default
//    Health().loadUser().then((HealthUser user) {
//      setState(() {
//        _exposureNotification = user?.consent ?? false;
//        _consent = user?.exposureNotification ?? false;
//      });
//    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: Styles().colors.background,
        body: _loading? _buildLoading() : _buildContent());
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
                      child: OnboardingBackButton(padding: EdgeInsets.only(top: 24, left:12.5, right: 20, bottom: 20), onTap: () => _goBack(context)),
                    )
                  ],
                ),
                ]
          ),
          Expanded( child:
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
                      child:Text(Localization().getStringEx('panel.health.onboarding.covid19.consent.label.title', 'Special consents for COVID-19 features'),
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 28, color: Styles().colors.fillColorPrimary),
                    )),
                    Container(height: 11,),
                    Semantics( header: true, hint: Localization().getStringEx("app.common.heading.two.hint","Header 2"),
                      child: Text(Localization().getStringEx("panel.health.onboarding.covid19.consent.label.description", "Exposure Notifications"),
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color:Styles().colors.fillColorPrimary),
                    )),
                    Container(height: 4,),
                    Text(
                      Localization().getStringEx("panel.health.onboarding.covid19.consent.label.content1", "If you consent to exposure notifications, you allow your phone to send an anonymous Bluetooth signal to nearby Safer Illinois app users who are also using this feature. Your phone will receive and record a signal from their phones as well. If one of those users tests positive for COVID-19 in the next 14 days, the app will alert you to your potential exposure and advise you on next steps. Your identity and health status will remain anonymous, as will the identity and health status of all other users."),
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                    ),
                    Container(height: 8,),
                    ToggleRibbonButton(
                      label:  Localization().getStringEx("panel.health.onboarding.covid19.consent.check_box.label.participate","I consent to participate in the Exposure Notification System (requires Bluetooth to be ON)."),
                      toggled: _exposureNotification,
                      onTap: _onParticipateTap,
                      context: context,
                      height: null),
                    Container(height: 24,),
                    Semantics( header: true, hint: Localization().getStringEx("app.common.heading.two.hint","Header 2"),
                    child:
                      Text(
                        Localization().getStringEx("panel.health.onboarding.covid19.consent.label.content2", "Automatic Test Results"),
                        style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color:Styles().colors.fillColorPrimary),
                      ),
                    ),
                    Container(height: 4,),
                    Text(
                      Localization().getStringEx("panel.health.onboarding.covid19.consent.label.content3", "Test results for your healthcare provider can be automatically provided to the Safer Illinois app. The test results are encrypted so only you can see the actual results."),
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                    ),
                    Container(height: 8,),
                    ToggleRibbonButton(
                      label: Localization().getStringEx("panel.health.onboarding.covid19.consent.check_box.label.allow","I consent to allow my healthcare provider to provide my test results."),
                      toggled: _consent,
                      context: context,
                      onTap: _onAllowTap,
                      height: null),
                    Container(height: 24,),
                    Text(
                      Localization().getStringEx("panel.health.onboarding.covid19.consent.label.content4", "Your participation is voluntary and you can stop at any time."),
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color:Styles().colors.fillColorPrimary),
                    ),
                    Container(height: 12,),
                  ],
                ))
            ),
          ),),
          Container(color: Styles().colors.white, child: Padding(
            padding: EdgeInsets.all(16),
            child: RoundedButton(
              enabled: _canContinue,
              label:_canContinue? Localization().getStringEx('panel.health.onboarding.covid19.consent.button.consent.title', 'Next') : Localization().getStringEx('panel.health.onboarding.covid19.consent.button.scroll_to_continue.title', 'Scroll to Continue'),
              hint: Localization().getStringEx('panel.health.onboarding.covid19.consent.button.consent.hint', ''),
              borderColor: (_canContinue ? Styles().colors.lightBlue : Styles().colors.disabledTextColorTwo),
              backgroundColor: (_canContinue ? Styles().colors.white : Styles().colors.background),
              textColor: (_canContinue ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColorTwo),
              onTap: () => _goNext(context),
            ),
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

  Widget _buildLoading(){
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,),),
          )
          ]);
  }

  void _goBack(BuildContext context) {
    Analytics.instance.logSelect(target: "Back");
    Navigator.of(context).pop();
  }

  void _goNext(BuildContext context) {
    if (!_canContinue) {
      return;
    }
    Analytics.instance.logSelect(target: "Continue");

    if (Auth().isLoggedIn) {
      _handleLoggedIn();
    } else { // Not logged in yet
      _finishConsent();
    }
  }

  // Used only for Shibboleth logged in user!!!!!
  void _handleLoggedIn() async{
    setState(() {
      _loading = true;
    });
    Health().loginUser(consent: _consent, exposureNotification: _exposureNotification).then((user){
      if(user==null){
        //Error
        AppToast.show(Localization().getStringEx("panel.health.onboarding.covid19.consent.label.error.login","Unable to login in Health"));
      } else {
        _finishConsent();
      }
      setState(() {
        _loading = false;
      });
    }).catchError((_){
      //Error
      AppToast.show(Localization().getStringEx("panel.health.onboarding.covid19.consent.label.error.login","Unable to login in Health"));
      setState(() {
        _loading = false;
      });
    });
  }

  void _finishConsent() {
    if (Auth().isLoggedIn) {
      widget.onboardingContext['shouldDisplayQrCode'] = true;
    } else {
      widget.onboardingContext['shouldDisplayQrCode'] = false;
    }
    Onboarding().next(context, widget);
  }

  void _onParticipateTap(){
    Analytics.instance.logSelect(target: "concent to participate");
    setState(() {
      _exposureNotification = !_exposureNotification;
    });

  }

  void _onAllowTap(){
    Analytics.instance.logSelect(target: "concent to allow");
    setState(() {
      _consent = !_consent;
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
