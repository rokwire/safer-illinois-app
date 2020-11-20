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
import 'package:illinois/service/Exposure.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/utils/Utils.dart';

class SettingsPersonalInfoPanel extends StatefulWidget {
  _SettingsPersonalInfoPanelState createState() => _SettingsPersonalInfoPanelState();
}

class _SettingsPersonalInfoPanelState extends State<SettingsPersonalInfoPanel> {

  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _deleteUserData() async{
    Analytics.instance.logAlert(text: "Remove My Information", selection: "Yes");

    await Health().deleteUser();
    await Exposure().deleteUser();
    await Auth().deleteUserPiiData();
    await UserProfile().deleteProfile();
    Auth().logout();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.profile_info.header.title", "PERSONAL INFO"),
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0),
        ),
      ),
      body: Column(children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                child: Column(
                  children: <Widget>[
                    _PersonalInfoEntry(
                        visible: Auth().isShibbolethLoggedIn,
                        title: Localization().getStringEx('panel.profile_info.net_id.title', 'NetID'),
                        value: Auth().userPiiData?.netId ?? ""
                    ),
                    _PersonalInfoEntry(
                        title: Localization().getStringEx('panel.profile_info.full_name.title', 'Full Name'),
                        value: Auth().userPiiData?.fullName ?? ""),
                    _PersonalInfoEntry(
                        title: Localization().getStringEx('panel.profile_info.first_name.title', 'First Name'),
                        value: Auth().userPiiData?.firstName ?? ""),
                    _PersonalInfoEntry(
                        title: Localization().getStringEx('panel.profile_info.middle_name.title', 'Middle Name'),
                        value: Auth().userPiiData?.middleName ?? ""),
                    _PersonalInfoEntry(
                        title: Localization().getStringEx('panel.profile_info.last_name.title', 'Last Name'),
                        value:  Auth().userPiiData?.lastName ?? ""),
                    _PersonalInfoEntry(
                        visible: Auth().isShibbolethLoggedIn,
                        title: Localization().getStringEx('panel.profile_info.email_address.title', 'Email Address'),
                        value: Auth().userPiiData?.email ?? ""),
                    _PersonalInfoEntry(
                        visible: Auth().isPhoneLoggedIn,
                        title: Localization().getStringEx("panel.profile_info.phone_number.title", "Phone Number"),
                        value: Auth().userPiiData?.phone ?? ""),
                    _buildAccountManagementOptions()
                  ],
                ),
              ),
            ),
          ),
        ),
      ],),
      backgroundColor: Styles().colors.background,
    );
  }

  //AccountManagementOptions
  Widget _buildAccountManagementOptions() {
    return Column(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Container(height: 10,),
        Visibility(
          visible: Auth().isShibbolethLoggedIn,
          child: Padding(
            padding: EdgeInsets.symmetric( vertical: 5),
            child: ScalableRoundedButton(
              label: Localization().getStringEx("panel.profile_info.button.sign_out.title", "Sign Out"),
              hint: Localization().getStringEx("panel.profile_info.button.sign_out.hint", ""),
              backgroundColor: Styles().colors.background,
              fontSize: 16.0,
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorSecondary,
              onTap: _onSignOutClicked,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric( vertical: 5),
          child: ScalableRoundedButton(
            label: Localization().getStringEx("panel.profile_info.button.remove_my_information.title", "Remove My Information"),
            hint: Localization().getStringEx("panel.profile_info.button.remove_my_information.hint", ""),
            backgroundColor: Styles().colors.background,
            fontSize: 16.0,
            textColor: Styles().colors.fillColorPrimary,
            borderColor: Styles().colors.fillColorSecondary,
            onTap: _onRemoveMyInfoClicked,
          ),
        ),
      ],
    );
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
                                    Localization().getStringEx("panel.profile_info.label.remove_my_info.title", "Remove My Info"),
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
                Expanded(child:
                SingleChildScrollView(
                  child: Column(children: <Widget>[

                    Container(
                      height: 26,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Text(
                        Localization().getStringEx("panel.profile_info.dialog.remove_my_information.title",
                            "By answering YES all your personal information and preferences will be deleted from our systems. This action can not  be recovered.  After deleting the information we will return you to the first screen when you installed the app so you can start again or delete the app."),
                        textAlign: TextAlign.left,
                        style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                      ),
                    ),
                    Container(
                      height: 26,
                    ),
                    Text(
                      Localization().getStringEx("panel.profile_info.dialog.remove_my_information.subtitle", "Are you sure?"),
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
                              ScalableRoundedButton(
                                  onTap: () => onConfirmRemoveMyInfo(context, setState),
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
                          ScalableRoundedButton(
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

                ],),)),
              ],
            ),
          ),
        );
      },
    );
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
                Localization().getStringEx("panel.profile_info.logout.message", "Are you sure you want to sign out?"),
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
                      Auth().logout();
                      Navigator.pop(context);
                      Navigator.pop(context);
                    },
                    child: Text(Localization().getStringEx("panel.profile_info.logout.button.yes", "Yes"))),
                FlatButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Sign out", selection: "No");
                      Navigator.pop(context);
                    },
                    child: Text(Localization().getStringEx("panel.profile_info.logout.no", "No")))
              ],
            ),
          ],
        ),
      ),
    );
  }

  void onConfirmRemoveMyInfo(BuildContext context, Function setState){
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

  _onRemoveMyInfoClicked() {
    showDialog(context: context, builder: (context) => _buildRemoveMyInfoDialog(context));
  }

  _onSignOutClicked() {
    showDialog(context: context, builder: (context) => _buildLogoutDialog(context));
  }

}

class _PersonalInfoEntry extends StatelessWidget {
  final String title;
  final String value;
  final bool visible;

  _PersonalInfoEntry({this.title, this.value, this.visible = true});

  @override
  Widget build(BuildContext context) {
    return visible
        ? Container(
            margin: EdgeInsets.only(top: 25),
            child:
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      Expanded(child:
                        Text(
                          title,
                          style: TextStyle(
                              fontFamily: Styles().fontFamilies.medium,
                              fontSize: 14,
                              letterSpacing: 0.5,
                              color: Styles().colors.textBackground),
                        ),
                      )
                    ],),
                    Container(
                      height: 5,
                    ),
                    Row(children: <Widget>[
                      Expanded(child:
                        Text(
                          value,
                          style:
                          TextStyle(fontSize: 20, color: Styles().colors.fillColorPrimary),
                        ),)
                    ],),

                  ],
                ),
        )
        : Container();
  }
}
