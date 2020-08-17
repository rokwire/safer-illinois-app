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
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/LinkTileButton.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:package_info/package_info.dart';

class SettingsPrivacyCenterPanel extends StatefulWidget{
  @override
  State<StatefulWidget> createState() => _SettingsPrivacyCenterPanelState();

}

class _SettingsPrivacyCenterPanelState extends State<SettingsPrivacyCenterPanel>{
  String _versionName = "";

  @override
  void initState() {
    _loadVersionInfo();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx("panel.settings.privacy_center.label.title", "Privacy Center"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
      ),
      body: SingleChildScrollView(child:_buildContent()),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildContent(){
    return
      Container(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child:
          Column(
          children: <Widget>[
            Container(height: 51,),
            Container(
              child: Image.asset("images/group-3.png",excludeFromSemantics: true,),
            ),
            _buildFinishSetupWidget(),
            Container(height: 40,),
            Text(Localization().getStringEx("panel.settings.privacy_center.label.description", "Personalize your privacy and data preferences."),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 20,
                  color: Styles().colors.fillColorPrimary
              ),
            ),
            Container(height: 32,),
            _buildSquareButtonsLayout(),
            Container(height: 10,),
            _buildButtonsLayout(),
            Container(height: 32,),
            _buildPrivacyPolicyButton(),
            Container(height: 33,),
            _buildVersionInfo(),
            Container(height: 30,),
          ],
        ));
  }


  Widget _buildFinishSetupWidget(){
    return Visibility(
      visible: _showFinishSetupWidget,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 32,),
          Text(Localization().getStringEx("panel.settings.privacy_center.label.finish_setup", "Finish setup"),
            style: TextStyle(
                fontFamily: Styles().fontFamilies.extraBold,
                fontSize: 16,
                color: Styles().colors.textSurface
            ),
          ),
          Container(height: 4,),
          Text(Localization().getStringEx("panel.settings.privacy_center.label.finish_setup_description", "Log in with your NetID or Telephone number to get the full Illinois experience."),
            style: TextStyle(
                fontFamily: Styles().fontFamilies.regular,
                fontSize: 16,
                color: Styles().colors.textSurface
            ),
          ),
          Container(height: 10,),
          RibbonButton(
            leftIcon: "images/user-check.png",
            label: Localization().getStringEx("panel.settings.privacy_center.button.verify_identity.title", "Verify your Identity"),
            borderRadius: BorderRadius.circular(4),
            onTap: () => _onTapVerifyIdentity(),
          ),
        ],
      ),
    );
  }

  Widget _buildSquareButtonsLayout(){
    return
      Container(
      alignment: Alignment.topCenter,
      child:
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
          Expanded(child: LinkTileSmallButton(
            label: Localization().getStringEx("panel.settings.privacy_center.button.manage_privacy.title", "Manage and Understand Your Privacy"),
            hint: Localization().getStringEx("panel.settings.privacy_center.button.manage_privacy.hint", ""),
            iconPath: 'images/privacy.png',
            onTap: (){},
            textStyle: TextStyle(
                fontFamily: Styles().fontFamilies.bold,
                fontSize: 16,
                color: LinkTileSmallButton.defaultTextColor
            ),)),
          Expanded(child: LinkTileSmallButton(
            label: Localization().getStringEx("panel.settings.privacy_center.button.covid19_privacy.title", "Your COVID-19 Privacy Settings"),
            hint: Localization().getStringEx("panel.settings.privacy_center.button.covid19_privacy.hint", ""),
            iconPath: 'images/covid.png',
            onTap: (){},
            textStyle: TextStyle(
                fontFamily: Styles().fontFamilies.bold,
                fontSize: 16,
                color: LinkTileSmallButton.defaultTextColor
            ),
            )),
        ],)
      );
  }

  Widget _buildButtonsLayout(){
      return
        Container(
            alignment: Alignment.topCenter,
            child:
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RibbonButton(
                  label: Localization().getStringEx("panel.settings.privacy_center.button.personal_information.title", "Personal Information"),
                  borderRadius: BorderRadius.circular(4),
                  onTap: _onTapPersonalInformation
                ),
                Container(height: 10,),
                RibbonButton(
                  label: Localization().getStringEx("panel.settings.privacy_center.button.notifications.title", "Notification Preferences"),
                  borderRadius: BorderRadius.circular(4),
                  onTap: _onTapNotifications
                ),
              ],)
        );
  }

  Widget _buildPrivacyPolicyButton(){
    return
      GestureDetector(
        onTap: _onTapPrivacyPolicy,
        child: Text(
          Localization().getStringEx("panel.settings.privacy_center.button.privacy_policy.title", "Privacy Policy"),
          style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16, decoration: TextDecoration.underline,decorationColor:  Styles().colors.fillColorSecondary,),
      ));
  }

  //Version Info
  Widget _buildVersionInfo(){
    return
      Column(children: <Widget>[
        Container(height: 1, color: Styles().colors.surfaceAccent,),
        Container(height: 12,),
        Container(
          alignment: Alignment.center,
          child:  Text(
            "Version: $_versionName",
            style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16),
          )),
      ],);
  }

  void _loadVersionInfo() async {
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        _versionName = packageInfo?.version;
      });
    });
  }


  void _onTapVerifyIdentity(){
    Analytics.instance.logSelect(target: "Verify Identity");
    //TBD
  }

  void _onTapPersonalInformation(){
    Analytics.instance.logSelect(target: "Personal Information");
    //TBD
  }

  void _onTapNotifications(){
    Analytics.instance.logSelect(target: "Notifications");
    //TBD
  }

  void _onTapPrivacyPolicy(){
    Analytics.instance.logSelect(target: "Privacy Policy");
    //TBD
  }

  bool get _identityVerified{
    return (Auth()?.userPiiData?.identityVerified ?? false);
  }

  bool get _showFinishSetupWidget{
    return !(Auth().isLoggedIn && _identityVerified);
  }
}