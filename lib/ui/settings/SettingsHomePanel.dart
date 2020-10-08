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
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Connectivity.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/health/Covid19QrCodePanel.dart';
import 'package:illinois/ui/settings/SettingsRolesPanel.dart';
import 'package:illinois/ui/settings/SettingsPersonalInfoPanel.dart';
import 'package:illinois/ui/settings/debug/SettingsDebugPanel.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/utils/Covid19.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:barcode_scan/barcode_scan.dart';
import 'package:package_info/package_info.dart';
import 'package:pointycastle/export.dart' as PointyCastle;


class SettingsHomePanel extends StatefulWidget {
  @override
  _SettingsHomePanelState createState() => _SettingsHomePanelState();
}

class _SettingsHomePanelState extends State<SettingsHomePanel> implements NotificationsListener {

  static BorderRadius _bottomRounding = BorderRadius.only(bottomLeft: Radius.circular(5), bottomRight: Radius.circular(5));
  static BorderRadius _topRounding = BorderRadius.only(topLeft: Radius.circular(5), topRight: Radius.circular(5));
  static BorderRadius _allRounding = BorderRadius.all(Radius.circular(5));
  
  String _versionName = "";
  // Covid19
  HealthUser _healthUser;
  bool _loadingHealthUser;

  PointyCastle.PrivateKey _healthUserPrivateKey;
  bool _loadingHealthUserPrivateKey;

  bool _healthUserKeysPaired;
  bool _checkingHealthUserKeysPaired;

  bool _refreshingHealthUserKeys;

  @override
  void initState() {
    NotificationService().subscribe(this, [
      Auth.notifyUserPiiDataChanged,
      User.notifyUserUpdated,
      FirebaseMessaging.notifySettingUpdated,
      FlexUI.notifyChanged,
    ]);
    _loadVersionInfo();

    //TBD move to Health service
    _initHealthUserData();
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Auth.notifyUserPiiDataChanged) {
      _updateState();
    } else if (name == User.notifyUserUpdated){
      _updateState();
    } else if (name == FirebaseMessaging.notifySettingUpdated) {
      _updateState();
    } else if (name == FlexUI.notifyChanged) {
      _updateState();
    }
  }

  @override
  Widget build(BuildContext context) {
    
    List<Widget> contentList = [];
    List<Widget> actionsList = [];

    List<dynamic> codes = FlexUI()['settings'] ?? [];

    for (String code in codes) {
      if (code == 'user_info') {
        contentList.add(_buildUserInfo());
      }
      else if (code == 'connect') {
        contentList.add(_buildConnect());
      }
      else if (code == 'customizations') {
        contentList.add(_buildCustomizations());
      }
      else if (code == 'connected') {
        contentList.add(_buildConnected());
      }
      else if (code == 'notifications') {
        contentList.add(_buildNotifications());
      }
      else if (code == 'covid19') {
        contentList.add(_buildCovid19Settings());
      }
      else if (code == 'privacy') {
        contentList.add(_buildPrivacy());
      }
      else if (code == 'account') {
        contentList.add(_buildAccount());
      }
      else if (code == 'feedback') {
        contentList.add(_buildFeedback(),);
      }
    }

    if (!kReleaseMode || Config().isDev) {
      contentList.add(_buildDebug());
      actionsList.add(_buildHeaderBarDebug());
    }

    contentList.add(_buildVersionInfo());
    
    contentList.add(Container(height: 12,),);

    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: _DebugContainer(
            child: Container(
//          height: 40,
          child: Padding(
            //PS I know it is ugly..
            padding: EdgeInsets.only(top: 10),
            child: Text(
              Localization().getStringEx("panel.settings.home.settings.header", "Settings"),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        )),
        actions: actionsList,
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea( 
                child: Container(
                  color: Styles().colors.background,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: contentList,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  // User Info

  String get _greeting {
    switch (AppDateTime.timeOfDay()) {
      case AppTimeOfDay.Morning:   return Localization().getStringEx("logic.date_time.greeting.morning", "Good morning");
      case AppTimeOfDay.Afternoon: return Localization().getStringEx("logic.date_time.greeting.afternoon", "Good afternoon");
      case AppTimeOfDay.Evening:   return Localization().getStringEx("logic.date_time.greeting.evening", "Good evening");
    }
    return Localization().getStringEx("logic.date_time.greeting.day", "Good day");
  }

  Widget _buildUserInfo() {
    String fullName = Auth()?.userPiiData?.fullName ?? "";
    bool hasFullName =  AppString.isStringNotEmpty(fullName);
    String welcomeMessage = AppString.isStringNotEmpty(fullName)
        ? _greeting + ","
        : Localization().getStringEx("panel.settings.home.user_info.title.sufix", "Welcome to Illinois");
    return
      Semantics( container: true,
        child: Container(
          width: double.infinity,
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(welcomeMessage, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
                Visibility(
                  visible: hasFullName,
                    child: Text(fullName, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 28))
                ),
              ]))));
  }


  // Connect

  Widget _buildConnect() {
    List<Widget> contentList = new List();
    contentList.add(Padding(
        padding: EdgeInsets.only(left: 8, right: 8, top: 12, bottom: 2),
        child: Text(
          Localization().getStringEx("panel.settings.home.connect.not_logged_in.title", "Connect to Illinois"),
          style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20),
        ),
      ),
    );

    List<dynamic> codes = FlexUI()['settings.connect'] ?? [];
    for (String code in codes) {
      if (code == 'netid') {
          contentList.add(Padding(
            padding: EdgeInsets.all(10),
            child: new RichText(
              textScaleFactor: MediaQuery.textScaleFactorOf(context),
              text: new TextSpan(
                style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                children: <TextSpan>[
                  new TextSpan(text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_1", "Are you a ")),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_2", "student"),
                      style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold)),
                  new TextSpan(text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_3", " or ")),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_4", "faculty member"),
                      style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold)),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.description.part_5",
                          "? Log in with your NetID to see Illinois information specific to you, like your Illini Cash and meal plan."))
                ],
              ),
            )),);
          contentList.add(RibbonButton(
            height: null,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            borderRadius: _allRounding,
            label: Localization().getStringEx("panel.settings.home.connect.not_logged_in.netid.title", "Connect your NetID"),
            onTap: _onConnectNetIdClicked),);
      }
      /*else if (code == 'phone') {
          contentList.add(Padding(
            padding: EdgeInsets.all(10),
            child: new RichText(
              textScaleFactor: MediaQuery.textScaleFactorOf(context),
              text: new TextSpan(
                style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                children: <TextSpan>[
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.phone.description.part_1", "Don't have a NetID"),
                      style: TextStyle(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold)),
                  new TextSpan(
                      text: Localization().getStringEx("panel.settings.home.connect.not_logged_in.phone.description.part_2",
                          "? Verify your phone number to save your preferences and have the same experience on more than one device.")),
                ],
              ),
            )),);
          contentList.add(RibbonButton(
            borderRadius: _allRounding,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.connect.not_logged_in.phone.title", "Verify Your Phone Number"),
            onTap: _onPhoneVerClicked),);
      }*/
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: contentList),
    );
  }

  void _onConnectNetIdClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Connect netId");
      Auth().authenticateWithShibboleth();
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Customizations

  Widget _buildCustomizations() {
    List<Widget> customizationOptions = new List();
    List<dynamic> codes = FlexUI()['settings.customizations'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      
      if (code == 'roles') {
        customizationOptions.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.customizations.role.title", "Who you are"),
            onTap: _onWhoAreYouClicked));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.customizations.title", "Customizations"),
      widgets: customizationOptions,);

  }

  void _onWhoAreYouClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Who are you");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsRolesPanel()));
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Connected

  Widget _buildConnected() {
    List<Widget> contentList = new List();

    List<dynamic> codes = FlexUI()['settings.connected'] ?? [];
    for (String code in codes) {
      if (code == 'netid') {
        contentList.add(_OptionsSection(
          title: Localization().getStringEx("panel.settings.home.net_id.title", "Illinois NetID"),
          widgets: _buildConnectedNetIdLayout()));
      }
      else if (code == 'phone') {
        contentList.add(_OptionsSection(
          title: Localization().getStringEx("panel.settings.home.phone_ver.title", "Phone Verification"),
          widgets: _buildConnectedPhoneLayout()));
      }
    }
    return Column(children: contentList,);

  }

  List<Widget> _buildConnectedNetIdLayout() {
    List<Widget> contentList = List();

    List<dynamic> codes = FlexUI()['settings.connected.netid'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'info') {
        contentList.add(
          Semantics( container: true,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(borderRadius: borderRadius, border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5)),
              child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Text(Localization().getStringEx("panel.settings.home.net_id.message", "Connected as "),
                        style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
                    Text(Auth().userPiiData?.fullName ?? "",
                        style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
                  ])))));
      }
      else if (code == 'connect') {
        contentList.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.net_id.button.connect", "Connect your NetID"),
            onTap: _onConnectNetIdClicked));
      }
      else if (code == 'disconnect') {
        contentList.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.net_id.button.disconnect", "Disconnect your NetID"),
            onTap: _onDisconnectNetIdClicked));
      }
    }

    return contentList;
  }

  List<Widget> _buildConnectedPhoneLayout() {
    List<Widget> contentList = List();

    String fullName = Auth()?.userPiiData?.fullName ?? "";
    bool hasFullName = AppString.isStringNotEmpty(fullName);

    List<dynamic> codes = FlexUI()['settings.connected.phone'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'info') {
        contentList.add(Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: borderRadius, border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5)),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text(Localization().getStringEx("panel.settings.home.phone_ver.message", "Verified as "),
                    style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
                Visibility(visible: hasFullName, child: Text(fullName ?? "", style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),),
                Text(Auth().phoneToken?.phone ?? "", style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
              ]))));
      }
      /*else if (code == 'verify') {
        contentList.add(RibbonButton(
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.phone_ver.button.connect", "Verify Your Phone Number"),
            onTap: _onPhoneVerClicked));
      }*/
      else if (code == 'disconnect') {
        contentList.add(RibbonButton(
            height: null,
            borderRadius: borderRadius,
            border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
            label: Localization().getStringEx("panel.settings.home.phone_ver.button.disconnect","Disconnect your Phone",),
            onTap: _onDisconnectNetIdClicked));
      }
    }
    return contentList;
  }

  void _onDisconnectNetIdClicked() {
    if(Auth().isShibbolethLoggedIn) {
      Analytics.instance.logSelect(target: "Disconnect netId");
    } else {
      Analytics.instance.logSelect(target: "Disconnect phone");
    }
    showDialog(context: context, builder: (context) => _buildLogoutDialog(context));
  }

  Widget _buildLogoutDialog(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              Localization().getStringEx("app.title", "Safer Illinois"),
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Text(
                Localization().getStringEx("panel.settings.home.logout.message", "Are you sure you want to sign out?"),
                textAlign: TextAlign.left,
                style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Sign out", selection: "Yes");
                      Navigator.pop(context);
                      Auth().logout();
                    },
                    child: Text(Localization().getStringEx("panel.settings.home.logout.button.yes", "Yes"))),
                FlatButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Sign out", selection: "No");
                      Navigator.pop(context);
                    },
                    child: Text(Localization().getStringEx("panel.settings.home.logout.no", "No")))
              ],
            ),
          ],
        ),
      ),
    );
  }

  // NotificationsOptions

  Widget _buildNotifications() {
    List<Widget> contentList = new List();

    List<dynamic> codes = FlexUI()['settings.notifications'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'covid19') {
        contentList.add(ToggleRibbonButton(
          height: null,
          borderRadius: borderRadius,
          label: Localization().getStringEx("panel.settings.home.notifications.covid19", "COVID-19 notifications"),
          toggled: FirebaseMessaging().notifyCovid19,
          context: context,
          onTap: _onCovid19Toggled));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.notifications.title", "Notifications"),
      widgets: contentList);
  }

  void _onCovid19Toggled() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "COVID-19 notifications");
      FirebaseMessaging().notifyCovid19 = !FirebaseMessaging().notifyCovid19;
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  //TBD move to Health service
  void _initHealthUserData(){
    if(Auth().isLoggedIn) {
      _loadHealthUser();
      _loadHealthRSAPrivateKey();
    }
  }

  void _loadHealthUser() {
    setState(() {
      _loadingHealthUser = true;
    });
    Health().loginUser().then((HealthUser user) {
      if (mounted) {
        if (user != null) {
          setState(() {
            _healthUser = user;
            _loadingHealthUser = false;
          });
          _verifyHealthRSAKeys();
        }
        else {
          setState(() {
            _loadingHealthUser = false;
          });
        }
      }
    });
  }

  void _updateHealthUser({bool consent, bool exposureNotification}){
    setState(() {
      _loadingHealthUser = true;
    });
    Health().loginUser(consent: consent, exposureNotification: exposureNotification).then((user) {
      if (mounted) {
        if (user != null) {
          setState(() {
            _healthUser = user;
            _loadingHealthUser = false;
          });
        }
        else {
          setState(() {
            _loadingHealthUser = false;
          });
          AppToast.show("Unable to login in Health");
        }
      }
    });
  }

  void _loadHealthRSAPrivateKey() {
    setState(() {
      _loadingHealthUserPrivateKey = true;
    });
    Health().loadRSAPrivateKey().then((privateKey) {
      if (mounted) {
        _healthUserPrivateKey = privateKey;
        _verifyHealthRSAKeys();
        setState(() {
          _loadingHealthUserPrivateKey = false;
        });
      }
    });
  }

  void _verifyHealthRSAKeys() {
    if ((_healthUserPrivateKey != null) && (_healthUser?.publicKey != null)) {
      setState(() {
        _checkingHealthUserKeysPaired = true;
      });
      RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_healthUser?.publicKey, _healthUserPrivateKey)).then((bool result) {
        if (mounted) {
          setState(() {
            _healthUserKeysPaired = result;
            _checkingHealthUserKeysPaired = false;
          });
        }
      });
    }
  }

  void _refreshHealthRSAKeys() {
    setState(() {
      _refreshingHealthUserKeys = true;
    });
    Health().refreshRSAKeys().then((keyPair) {
      if (mounted) {
        if (keyPair != null) {
          setState(() {
            _healthUser = Health().healthUser;
            _healthUserPrivateKey = keyPair.privateKey;
            _refreshingHealthUserKeys = false;
          });
          _verifyHealthRSAKeys();
        }
        else {
          setState(() {
            _refreshingHealthUserKeys = false;
          });
          AppAlert.showDialogResult(context, Localization().getStringEx('panel.settings.home.covid19.alert.reset.failed', 'Failed to reset the COVID-19 Secret QRcode'));
        }
      }
    });

  }

  

  Widget _buildCovid19Settings() {
    List<Widget> contentList = new List();

    if (_loadingHealthUser == true) {
      contentList.add(Container(
        padding: EdgeInsets.all(16),
        child: Center(child:
          CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
        ,),
      ));
    }
    else if (_healthUser == null) {
      contentList.add(Container(
        padding: EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(Localization().getStringEx('panel.settings.home.covid19.text.user.fail', 'Unable to retrieve user COVID-19 settings.') , style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
            Container(height: 4,),
//            Row(children: <Widget>[
              ScalableRoundedButton(
                label: Localization().getStringEx('panel.settings.home.covid19.button.retry.title', 'Retry'),
                backgroundColor: Styles().colors.background,
                fontSize: 16.0,
                padding: EdgeInsets.symmetric(horizontal: 24),
                textColor: Styles().colors.fillColorPrimary,
                borderColor: Styles().colors.fillColorPrimary,
                onTap: _onTapCovid19Login
              ),
//            ],)
        ],)
      ));
    }
    else {
      List<dynamic> codes = FlexUI()['settings.covid19'] ?? [];
      for (int index = 0; index < codes.length; index++) {
        String code = codes[index];
        BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
        if (code == 'exposure_notifications') {
          contentList.add(ToggleRibbonButton(
              height: null,
              borderRadius: borderRadius,
              label: Localization().getStringEx("panel.settings.home.covid19.exposure_notifications", "Exposure Notifications"),
              toggled: (_healthUser?.exposureNotification == true),
              context: context,
              onTap: _onExposureNotifications));
        }
        else if (code == 'provider_test_result') {
          contentList.add(ToggleRibbonButton(
              height: null,
              borderRadius: borderRadius,
              label: Localization().getStringEx("panel.settings.home.covid19.provider_test_result", "Health Provider Test Results"),
              toggled: (_healthUser?.consent == true),
              context: context,
              onTap: _onProviderTestResult));
        }
        else if (code == 'qr_code') {
          contentList.add(Padding(padding: EdgeInsets.only(left: 8, top: 16), child: _buildCovid19KeysSection(),));
        }
      }
    }

    return _OptionsSection(
        title: Localization().getStringEx("panel.settings.home.covid19.title", "COVID-19"),
        widgets: contentList);
  }

  Widget _buildCovid19KeysSection() {
    if ((_loadingHealthUserPrivateKey == true) || (_checkingHealthUserKeysPaired == true)) {
      return Text(Localization().getStringEx('panel.settings.home.covid19.text.keys.checking', 'Checking COVID-19 keys...'), style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),);
    }
    else {
      String statusText, descriptionText;
      List<Widget> buttons;
      if (_healthUser?.publicKey == null) {
        statusText = Localization().getStringEx('panel.settings.home.covid19.text.keys.missing.public', 'Missing COVID-19 public key');
        descriptionText = Localization().getStringEx('panel.settings.home.covid19.text.keys.reset', 'Reset the COVID-19 keys pair.');
        buttons =  <Widget>[
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: _buildCovid19ResetButton()),
        ];
      }
      else if ((_healthUserPrivateKey == null) || (_healthUserKeysPaired != true)) {
        statusText = (_healthUserPrivateKey == null) ?
          Localization().getStringEx('panel.settings.home.covid19.text.keys.missing.private', 'Missing COVID-19 private key') :
          Localization().getStringEx('panel.settings.home.covid19.text.keys.mismatch', 'COVID-19 keys not paired');
        descriptionText = Localization().getStringEx('panel.settings.home.covid19.text.keys.transfer_or_reset', 'Transfer the COVID-19 private key from your other phone or reset the COVID-19 keys pair.');
        buttons =  <Widget>[
          Expanded(child: ScalableRoundedButton(
            label: Localization().getStringEx('panel.settings.home.covid19.button.load.title', 'Load'),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorPrimary,
            onTap: _onTapLoadCovid19QrCode),),
          Container(width: 8,),
          Expanded(child: ScalableRoundedButton(
            label: Localization().getStringEx('panel.settings.home.covid19.button.scan.title', 'Scan'),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorPrimary,
            onTap: _onTapScanCovid19QrCode)),
          Container(width: 8,),
          Expanded(child:
            _buildCovid19ResetButton(),
          ),
        ];
      }
      else {
        statusText = Localization().getStringEx('panel.settings.home.covid19.text.keys.paired', 'COVID-19 keys valid and paired');
        descriptionText = Localization().getStringEx('panel.settings.home.covid19.text.keys.qr_code', 'Show your COVID-19 secret QR code.');
        buttons =  <Widget>[
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: Container()),
          Container(width: 8,),
          Expanded(child: ScalableRoundedButton(
            label: Localization().getStringEx('panel.settings.home.covid19.button.qr_code.title', 'QR Code'),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorPrimary,
            onTap: _onTapShowCovid19QrCode))
        ];
      }

      return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(statusText, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
            Container(height: 4,),
            Text(descriptionText, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.regular)),
            Container(height: 8,),
            Row(children: buttons)
        ],
      );
    }
  }

  Widget _buildCovid19ResetButton() {
    double buttonWidth = 100, buttonHeight = 48, progressSize = 24; 
    return Stack(children: <Widget>[
      ScalableRoundedButton(
        label: Localization().getStringEx('panel.settings.home.covid19.button.reset.title', 'Reset'),
        backgroundColor: Styles().colors.background,
        fontSize: 16.0,
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorPrimary,
        onTap: _onTapCovid19ResetKeys,
      ),
      Visibility(visible: (_refreshingHealthUserKeys == true), child:
        Padding(padding: EdgeInsets.only(top: (buttonHeight - progressSize) / 2, left: (buttonWidth - progressSize) / 2), child:
          Container(width: progressSize, height: progressSize, child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
          ),
        ),
      ),
    ],);
  }

  
  void _onExposureNotifications() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Exposure Notifications");
      bool exposureNotification = _healthUser?.exposureNotification ?? false;
      _updateHealthUser(exposureNotification: !exposureNotification);
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onProviderTestResult() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Health Provider Test Results");
      bool consent = _healthUser?.consent ?? false;
      _updateHealthUser(consent: !consent);
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapCovid19Login() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Retry");
      _loadHealthUser();
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapCovid19ResetKeys() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Reset");
      String message = Localization().getStringEx(
          'panel.settings.home.covid19.alert.reset.prompt', 'Doing this will provide you a new COVID-19 Secret QRcode but your previous COVID-19 event history will be lost, continue?');
      if (_refreshingHealthUserKeys != true) {
        showDialog(
            context: context,
            builder: (BuildContext buildContext) {
              return AlertDialog(
                content: Text(message, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
                actions: <Widget>[
                  FlatButton(
                      child: Text(
                          Localization().getStringEx("dialog.yes.title", "Yes"), style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
                      onPressed: () {
                        Analytics.instance.logAlert(text: message, selection: "Yes");
                        Navigator.pop(buildContext, true);
                      }
                  ),
                  FlatButton(
                      child: Text(Localization().getStringEx("dialog.no.title", "No"), style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold)),
                      onPressed: () {
                        Analytics.instance.logAlert(text: message, selection: "No");
                        Navigator.pop(buildContext, false);
                      }
                  ),
                ],
              );
            }
        ).then((result) {
          if (result == true) {
            _refreshHealthRSAKeys();
          }
        });
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapShowCovid19QrCode() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Show COVID-19 Secret QRcode");
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19QrCodePanel()));
    }
  }

  void _onTapScanCovid19QrCode() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Scan COVID-19 Secret QRcode");
      BarcodeScanner.scan().then((result) {
        // barcode_scan plugin returns 8 digits when it cannot read the qr code. Prevent it from storing such values
        if (AppString.isStringEmpty(result) || (result.length <= 8)) {
          AppAlert.showDialogResult(context, Localization().getStringEx('panel.settings.home.covid19.alert.qr_code.scan.failed.msg', 'Failed to read QR code.'));
        }
        else {
          _onCovid19QrCodeScanSucceeded(result);
        }
      });
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onTapLoadCovid19QrCode() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Load COVID-19 Secret QRcode");
      Covid19Utils.loadQRCodeImageFromPictures().then((String qrCodeString) {
        _onCovid19QrCodeScanSucceeded(qrCodeString);
      });
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  void _onCovid19QrCodeScanSucceeded(String result) {
    if (Connectivity().isNotOffline) {
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
        RsaKeyHelper.verifyRsaKeyPair(PointyCastle.AsymmetricKeyPair<PointyCastle.PublicKey, PointyCastle.PrivateKey>(_healthUser?.publicKey, privateKey)).then((bool result) {
          if (mounted) {
            if (result == true) {
              Health().setUserRSAPrivateKey(privateKey).then((success) {
                if (mounted) {
                  String resultMessage = success ? Localization().getStringEx(
                      'panel.settings.home.covid19.alert.qr_code.transfer.succeeded.msg', 'COVID-19 secret transferred successfully.') : Localization()
                      .getStringEx('panel.settings.home.covid19.alert.qr_code.transfer.failed.msg', 'Failed to transfer COVID-19 secret.');
                  AppAlert.showDialogResult(context, resultMessage).then((_) {
                    if (success) {
                      setState(() {
                        _healthUserPrivateKey = privateKey;
                        _healthUserKeysPaired = true;
                      });
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
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Privacy

  Widget _buildPrivacy() {
    List<Widget> contentList = new List();

    List<dynamic> codes = FlexUI()['settings.privacy'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'statement') {
        contentList.add(RibbonButton(
          height: null,
          borderRadius: borderRadius,
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          label: Localization().getStringEx("panel.settings.home.privacy.privacy_statement.title", "Privacy Statement"),
          onTap: _onPrivacyStatementClicked,
        ));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.privacy.title", "Privacy"),
      widgets: contentList);
  }

  void _onPrivacyStatementClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Privacy Statement");
      if (Config().privacyPolicyUrl != null) {
        Navigator.push(context, CupertinoPageRoute(
            builder: (context) => WebPanel(url: Config().privacyPolicyUrl, title: Localization().getStringEx("panel.settings.privacy_statement.label.title", "Privacy Statement"),)));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Account

  Widget _buildAccount() {
    List<Widget> contentList = new List();

    List<dynamic> codes = FlexUI()['settings.account'] ?? [];
    for (int index = 0; index < codes.length; index++) {
      String code = codes[index];
      BorderRadius borderRadius = _borderRadiusFromIndex(index, codes.length);
      if (code == 'personal_info') {
        contentList.add(RibbonButton(
          height: null,
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          borderRadius: borderRadius,
          label: Localization().getStringEx("panel.settings.home.account.personal_info.title", "Personal Info"),
          onTap: _onPersonalInfoClicked));
      }
    }

    return _OptionsSection(
      title: Localization().getStringEx("panel.settings.home.account.title", "Your Account"),
      widgets: contentList,
    );
  }

  void _onPersonalInfoClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Personal Info");
      if (Auth().isLoggedIn) {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsPersonalInfoPanel()));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Feedback

  Widget _buildFeedback(){
    return Column(
      children: <Widget>[
        Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(
                Localization().getStringEx("panel.settings.home.feedback.title", "We need your ideas!"),
                style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20),
              ),
              Container(height: 5,),
              Text(
                Localization().getStringEx("panel.settings.home.feedback.description", "Enjoying the app? Missing something? Tap on the bottom to submit your idea."),
                style: TextStyle(fontFamily: Styles().fontFamilies.regular,color: Styles().colors.textBackground, fontSize: 16),
              ),
            ])
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: ScalableRoundedButton(
            label: Localization().getStringEx("panel.settings.home.button.feedback.title", "Submit Feedback"),
            hint: Localization().getStringEx("panel.settings.home.button.feedback.hint", ""),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorSecondary,
            onTap: _onFeedbackClicked,
          ),
        ),
      ],
    );
  }

  String _constructFeedbackParams(String email, String phone, String name) {
    Map params = Map();
    params['email'] = Uri.encodeComponent(email != null ? email : "");
    params['phone'] = Uri.encodeComponent(phone != null ? phone : "");
    params['name'] = Uri.encodeComponent(name != null ? name : "");

    String result = "";
    if (params.length > 0) {
      result += "?";
      params.forEach((key, value) =>
      result+= key + "=" + value + "&"
      );
      result = result.substring(0, result.length - 1); //remove the last symbol &
    }
    return result;
  }

  void _onFeedbackClicked() {
    if (Connectivity().isNotOffline) {
      Analytics.instance.logSelect(target: "Provide Feedback");

      if (Connectivity().isNotOffline && (Config().feedbackUrl != null)) {
        String email = Auth().userPiiData?.email;
        String name = Auth().userPiiData?.fullName;
        String phone = Auth().phoneToken?.phone;
        String params = _constructFeedbackParams(email, phone, name);
        String feedbackUrl = Config().feedbackUrl + params;

        String panelTitle = Localization().getStringEx('panel.settings.feedback.label.title', 'PROVIDE FEEDBACK');
        Navigator.push(
            context, CupertinoPageRoute(builder: (context) => WebPanel(url: feedbackUrl, analyticsUrl: Config().feedbackUrl , title: panelTitle,)));
      }
      else {
        AppAlert.showOfflineMessage(context, Localization().getStringEx('panel.settings.label.offline.feedback', 'Providing a Feedback is not available while offline.'));
      }
    } else {
      AppAlert.showOfflineMessage(context);
    }
  }

  // Debug

  Widget _buildDebug() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ScalableRoundedButton(
        label: Localization().getStringEx("panel.profile_info.button.debug.title", "Debug"),
        hint: Localization().getStringEx("panel.profile_info.button.debug.hint", ""),
        backgroundColor: Styles().colors.background,
        fontSize: 16.0,
        textColor: Styles().colors.fillColorPrimary,
        borderColor: Styles().colors.fillColorSecondary,
        onTap: () { _onDebugClicked(); },
      ),
    ); 
  }

  Widget _buildHeaderBarDebug() {
    return Semantics(
      label: Localization().getStringEx('panel.settings.home.button.debug.title', 'Debug'),
      hint: Localization().getStringEx('panel.settings.home.button.debug.hint', ''),
      button: true,
      excludeSemantics: true,
      child: IconButton(
        icon: Image.asset('images/debug-white.png'),
        onPressed: _onDebugClicked)
    );
  }

  void _onDebugClicked() {
    Analytics.instance.logSelect(target: "Debug");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsDebugPanel()));
  }

  // Version Info

  Widget _buildVersionInfo(){
    return Container(
      alignment: Alignment.center,
      child:  Text(
        "Version: $_versionName",
        style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
    ));
  }

  void _loadVersionInfo() async {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        _versionName = packageInfo?.version;
      });
    });
  }

  // Utilities

  BorderRadius _borderRadiusFromIndex(int index, int length) {
    int first = 0;
    int last = length - 1;
    if ((index == first) && (index < last)) {
      return _topRounding;
    }
    else if ((first < index) && (index == last)) {
      return _bottomRounding;
    }
    else if ((index == first) && (index == last)) {
      return _allRounding;
    }
    else {
      return BorderRadius.zero;
    }
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

}

class _OptionsSection extends StatelessWidget {
  final List<Widget> widgets;
  final String title;
  final String description;

  const _OptionsSection({Key key, this.widgets, this.title, this.description}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child:  Semantics( header: true,
              child: Text(title, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20),
            )),
          ),
          AppString.isStringEmpty(description)
              ? Container()
              : Padding(
                  padding: EdgeInsets.only(left: 8, right: 8, bottom: 12),
                  child: Text(
                    description,
                    style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
                  )),
          Stack(alignment: Alignment.topCenter, children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5),
                borderRadius: BorderRadius.circular(5.0),
              ),
              child: Padding(padding: EdgeInsets.all(0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: widgets)),
            )
          ])
        ]));
  }
}

class _DebugContainer extends StatefulWidget {

  final Widget _child;

  _DebugContainer({@required Widget child}) : _child = child;

  _DebugContainerState createState() => _DebugContainerState();
}

class _DebugContainerState extends State<_DebugContainer> {

  int _clickedCount = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: widget._child,
      onTap: () {
        Log.d("On tap debug widget");
        _clickedCount++;
        if (_clickedCount == 7) {
          if (Auth().isDebugManager) {
            Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsDebugPanel()));
          }
          _clickedCount = 0;
        }
      },
    );
  }
}
