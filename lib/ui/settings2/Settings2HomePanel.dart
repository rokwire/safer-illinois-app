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
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/AppNavigation.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Connectivity.dart';
import 'package:illinois/service/Exposure.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Log.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/health/Covid19HistoryPanel.dart';
import 'package:illinois/ui/health/Covid19TransferEncryptionKeyPanel.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingResidentInfoPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingLoginPhoneVerifyPanel.dart';
import 'package:illinois/ui/settings2/Settings2ConsentPanel.dart';
import 'package:illinois/ui/settings2/Settings2GovernmentIdPanel.dart';
import 'package:illinois/ui/settings2/Settings2ExposureNotificationsPanel.dart';
import 'package:illinois/ui/settings/debug/SettingsDebugPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:intl/intl.dart';


class Settings2HomePanel extends StatefulWidget {
  @override
  _Settings2HomePanelState createState() => _Settings2HomePanelState();
}

class _Settings2HomePanelState extends State<Settings2HomePanel> implements NotificationsListener {

  bool _isLoading = false;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();

    NotificationService().subscribe(this, [
      Auth.notifyUserPiiDataChanged,
      User.notifyUserUpdated,
      Health.notifyUserUpdated,
    ]);

    _loadHealthUser();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  void _updateState() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteUserData() async{
    Analytics.instance.logAlert(text: "Remove My Information", selection: "Yes");

    await Health().deleteUser();
    await Exposure().deleteUser();
    await Auth().deleteUserPiiData();
    await User().deleteUser();
    Auth().logout();
  }

  void _loadHealthUser() {
    setState(() {
      _isLoading = true;
    });
    Health().loadUser().whenComplete((){
      setState(() {
        _isLoading = false;
      });
    });
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Auth.notifyUserPiiDataChanged) {
      _updateState();
    } else if (name == User.notifyUserUpdated){
      _updateState();
    } else if (name == Health.notifyUserUpdated){
      _updateState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: _DebugContainer(
            child: Text(
              Localization().getStringEx("panel.settings.home.settings.header", "Settings"),
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontFamily: Styles().fontFamilies.extraBold,
                letterSpacing: 1.0,
              ),
              textAlign: TextAlign.center,
            )),
      ),
      body: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: <Widget>[
                  Text("About You",
                    style: TextStyle(
                      fontFamily: Styles().fontFamilies.extraBold,
                      color: Styles().colors.fillColorPrimary,
                      fontSize: 20,
                    ),
                  ),
                  Container(height: 12,),
                  _buildConnected(),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Add A Government ID',
                    descriptionLabel: 'Verify your identity by adding a government-issued ID',
                    leftIcon: 'images/icon-passport.png',
                    onTap: _onAddGovernmentId,
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'COVID-19 Event History',
                    descriptionLabel: 'View or delete test results, symptom updates, or contact tracing information',
                    leftIcon: 'images/icon-identity.png',
                    onTap: _onEventHistoryTapped,
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Transfer Your COVID-19 Encryption Key',
                    descriptionLabel: 'View, scan, or save your COVID-19 Encryption Key to transfer to another device.',
                    leftIcon: 'images/icon-key.png',
                    onTap: _onTransferKeyTapped,
                  ),
                  Container(height: 40,),
                  Text("Special Consent",
                    style: TextStyle(
                      fontFamily: Styles().fontFamilies.extraBold,
                      color: Styles().colors.fillColorPrimary,
                      fontSize: 20,
                    ),
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Exposure Notifications',
                    value: (Health()?.healthUser?.exposureNotification ?? false) ? 'Enabled' : 'Disabled',
                    descriptionLabel: 'Learn more information about exposure notifications and manage your settings.',
                    onTap: _onExposureNotificationsTapped,
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    value: (Health()?.healthUser?.consent ?? false) ? 'Enabled' : 'Disabled',
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Automatic Test Results',
                    descriptionLabel: 'Learn more information about automatic test results and manage your settings.',
                    onTap: _onConsentTapped,
                  ),
                  Container(height: 40,),
                  Text("System Settings",
                    style: TextStyle(
                      fontFamily: Styles().fontFamilies.extraBold,
                      color: Styles().colors.fillColorPrimary,
                      fontSize: 20,
                    ),
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    value: 'Disabled',
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Access device’s location',
                    descriptionLabel: 'To get the most out of our features, enable location in your device’s settings.',
                    leftIcon: 'images/icon-location-1.png',
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    value: 'Disabled',
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Access device\'s bluetooth',
                    descriptionLabel: 'To use Bluetooth enable in your device\'s settings.',
                    leftIcon: 'images/icon-bluetooth.png',
                  ),
                  Container(height: 12,),
                  CustomRibbonButton(
                    height: null,
                    value: 'Disabled',
                    borderRadius: BorderRadius.all(Radius.circular(4)),
                    label: 'Notifications',
                    descriptionLabel: 'To receive notifications enable in your device\'s settings.',
                    leftIcon: 'images/icon-notifications-blue.png',
                  ),
                  Container(height: 1, color: Styles().colors.surfaceAccent, margin: EdgeInsets.symmetric(vertical: 20),),
                  RoundedButton(
                    label: 'Delete my COVID-19 Information',
                    hint: '',
                    backgroundColor: Styles().colors.surface,
                    fontSize: 16.0,
                    textColor: Styles().colors.fillColorSecondary,
                    borderColor: Styles().colors.surfaceAccent,
                    onTap: _onRemoveMyInfoClicked,

                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Delete your government issued ID information, COVID-19 event history, and encryption key.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontFamily: Styles().fontFamilies.regular,
                          color: Styles().colors.textBackground,
                          fontSize: 12
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
          _isLoading ? Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,),) : Container()
        ],
      )
    );
  }

  Widget _buildConnected() {
    return Column(
      children: <Widget>[
        _buildConnectedNetIdLayout(),
        _buildConnectedPhoneLayout()
      ],
    );
  }

  Widget _buildConnectedNetIdLayout() {
    List<Widget> contentList = List();

    if(Auth().isShibbolethLoggedIn){
      contentList.add(Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)), border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5)),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text("Connected as ",
                    style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
                Text(Auth().userPiiData?.fullName ?? "",
                    style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
              ]))));
      contentList.add(
          Semantics( explicitChildNodes: true,
            child:RibbonButton(
              borderRadius:  BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
              border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
              label: "Disconnect your NetID",
              onTap: _onDisconnectNetIdClicked)));
    }
    else if(!Auth().isLoggedIn){
      contentList.add(
        Semantics( explicitChildNodes: true,
          child: RibbonButton(
          borderRadius: BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          label: "Connect your NetID",
          onTap: _onConnectNetIdClicked)));
    }

    return Semantics( container:true,
      child: Container(child: Column(children: contentList,)));
  }

  Widget _buildConnectedPhoneLayout() {
    List<Widget> contentList = List();

    if(Auth().isPhoneLoggedIn){
      String full = Auth()?.userPiiData?.fullName ?? "";
      bool hasFull = AppString.isStringNotEmpty(full);

      contentList.add(Container(
          width: double.infinity,
          decoration: BoxDecoration(borderRadius: BorderRadius.only(topLeft: Radius.circular(4), topRight: Radius.circular(4)), border: Border.all(color: Styles().colors.surfaceAccent, width: 0.5)),
          child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                Text("Verified as ",
                    style: TextStyle(color: Styles().colors.textBackground, fontFamily: Styles().fontFamilies.regular, fontSize: 16)),
                Visibility(visible: hasFull, child: Text(full ?? "", style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),),
                Text(Auth().phoneToken?.phone ?? "", style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20)),
              ]))));
      contentList.add(
          Semantics( explicitChildNodes: true,
            child:RibbonButton(
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(4), bottomRight: Radius.circular(4)),
              border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
              label: "Disconnect your Phone",
              onTap: _onDisconnectNetIdClicked)));
    }
    else if(!Auth().isLoggedIn){
      contentList.add(
      Semantics( explicitChildNodes: true,
        child:RibbonButton(
          borderRadius:BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: Styles().colors.surfaceAccent, width: 0),
          label: "Verify Your Phone Number",
          onTap: _onPhoneVerClicked)));
    }
    return Column(children: contentList,);
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
                        decoration: BoxDecoration(
                          color: Styles().colors.fillColorPrimary,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: Row(
                            children: <Widget>[
                              Expanded(
                                child: Center(
                                  child: Text(
                                    "Delete your COVID-19 event history?",
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
                    "This will permanently delete all of your COVID-19 event history information. Are you sure you want to continue?",
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
                  height: 16,
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Expanded(
                        child: RoundedButton(
                            onTap: () {
                              Analytics.instance.logAlert(text: "Remove My Information", selection: "No");
                              Navigator.pop(context);
                            },
                            backgroundColor: Colors.transparent,
                            borderColor: Styles().colors.fillColorPrimary,
                            textColor: Styles().colors.fillColorPrimary,
                            label: 'No'),
                      ),
                      Container(
                        width: 10,
                      ),
                      Expanded(
                        child: Stack(
                          children: <Widget>[
                            RoundedButton(
                                onTap: () => _onConfirmRemoveMyInfo(context, setState),
                                backgroundColor: Styles().colors.fillColorSecondaryVariant,
                                borderColor: Styles().colors.fillColorSecondaryVariant,
                                textColor: Styles().colors.surface,
                                label: Localization().getStringEx("panel.profile_info.dialog.remove_my_information.yes.title", "Yes")),
                            _isDeleting ? Align(alignment: Alignment.center, child: CircularProgressIndicator()) : Container()
                          ],
                        ),
                      ),
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

  Widget _buildLogoutDialog(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              "Safer Illinois",
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Text(
                "Are you sure you want to sign out?",
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
                    child: Text("Yes")),
                FlatButton(
                    onPressed: () {
                      Analytics.instance.logAlert(text: "Sign out", selection: "No");
                      Navigator.pop(context);
                    },
                    child: Text("No"))
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _onConnectNetIdClicked() {
    Analytics.instance.logSelect(target: "Connect netId");
    Auth().authenticateWithShibboleth();
  }

  void _onDisconnectNetIdClicked() {
    if(Auth().isShibbolethLoggedIn) {
      Analytics.instance.logSelect(target: "Disconnect netId");
    } else {
      Analytics.instance.logSelect(target: "Disconnect phone");
    }
    showDialog(context: context, builder: (context) => _buildLogoutDialog(context));
  }

  void _onPhoneVerClicked() {
    Analytics.instance.logSelect(target: "Phone Verification");
    if (Connectivity().isNotOffline) {
      Navigator.push(context, CupertinoPageRoute(settings: RouteSettings(), builder: (context) => OnboardingLoginPhoneVerifyPanel(onFinish: _didPhoneVer,)));
    } else {
      AppAlert.showOfflineMessage(context, 'Verify Your Phone Number is not available while offline.');
    }
  }

  void _onAddGovernmentId(){
    if(Auth()?.userPiiData?.hasPasportInfo ?? false){
      Navigator.push(context, CupertinoPageRoute(
        builder: (context) => Settings2GovernmentIdPanel()
      ));
    }
    else {
      Navigator.push(context, CupertinoPageRoute(
          builder: (context) => Covid19OnBoardingResidentInfoPanel(
            onSucceed: (Map<String,dynamic> data){
              Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => Settings2GovernmentIdPanel(initialData: data,)));
            },
            onCancel: ()=>Navigator.pop(context),
          )
      ));
    }
  }

  void _onRemoveMyInfoClicked() {
    showDialog(context: context, builder: (context) => _buildRemoveMyInfoDialog(context));
  }

  void _didPhoneVer(_) {
    Navigator.of(context)?.popUntil((Route route){
      return AppNavigation.routeRootWidget(route, context: context)?.runtimeType == widget.runtimeType;
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

  void _onEventHistoryTapped(){
    Analytics.instance.logSelect(target: "COVID-19 Test History");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19HistoryPanel()));
  }

  void _onTransferKeyTapped() {
    Analytics.instance.logSelect(target: "Transfer Your COVID-19 Encryption Key");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19TransferEncryptionKeyPanel()));
  }

  void _onExposureNotificationsTapped(){
    Analytics.instance.logSelect(target: "Exposure Notifications");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => Settings2ExposureNotificationsPanel()));
  }

  void _onConsentTapped(){
    Analytics.instance.logSelect(target: "Consent");
    Navigator.push(context, CupertinoPageRoute(builder: (context) => Settings2ConsentPanel()));
  }
}

class CustomRibbonButton extends StatelessWidget {
  final String label;
  final String value;
  final String descriptionLabel;

  final GestureTapCallback onTap;
  final EdgeInsets padding;
  final BorderRadius borderRadius;
  final BoxBorder border;
  final TextStyle style;
  final double height;
  final String leftIcon;
  final String icon;
  final BuildContext context;
  final String hint;

  CustomRibbonButton({
    @required this.label,
    this.value,
    this.descriptionLabel,
    this.onTap,
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    this.style,
    this.height = 48.0,
    this.icon = 'images/chevron-right.png',
    this.leftIcon,
    this.context,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return getSemantics();
  }

  Semantics getSemantics() {
    return Semantics(label: label, hint : hint, button: true, excludeSemantics: true, child: _content());
  }

  Widget _content() {
    bool hasDescription = AppString.isStringNotEmpty(descriptionLabel);
    bool hasValue = AppString.isStringNotEmpty(value);
    Widget image = getImage();
    Widget leftIconWidget = AppString.isStringNotEmpty(leftIcon) ? Padding(padding: EdgeInsets.only(right: 7), child: Image.asset(leftIcon)) : Container();
    Widget leftIconHiddenWidget = Opacity(opacity: 0, child: AppString.isStringNotEmpty(leftIcon) ? Padding(padding: EdgeInsets.only(right: 7), child: Image.asset(leftIcon)) : Container(),);
    return GestureDetector(
      onTap: () { onTap(); anaunceChange(); },
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[ Expanded(
          child: Container(
            decoration: BoxDecoration(color: Colors.white, border:border, borderRadius: borderRadius, boxShadow: [
              BoxShadow(
                color: Styles().colors.lightGray,
                spreadRadius: 3,
                blurRadius: 3,
                offset: Offset(2, 2), // changes position of shadow
              ),
            ]),
            height: this.height,
            child: Padding(
              padding: padding,
              child:  Column(
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      leftIconWidget,
                      Expanded(child:
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(label,
                            style: style ?? TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold),
                          ),
                        ],
                      )
                      ),
                      (image != null) ? Padding(padding: EdgeInsets.only(left: 7), child: image) : Container(),
                    ],
                  ),
                  hasValue ? Row(
                    children: <Widget>[
                      leftIconHiddenWidget,
                      Expanded(child: hasValue ? Container(
                        child: Text(value,
                          style: style ?? TextStyle(color: Styles().colors.textSurface, fontSize: 14, fontFamily: Styles().fontFamilies.regular),
                        ),
                      ) : Container()
                        ,)
                    ],
                  ) : Container(),
                  Row(
                    children: <Widget>[
                      leftIconHiddenWidget,
                      Expanded(child: hasDescription ? Container(
                        margin: EdgeInsets.only(top: 4),
                        child: Text(descriptionLabel,
                          style: style ?? TextStyle(color: Styles().colors.textSurface, fontSize: 14, fontFamily: Styles().fontFamilies.regular),
                        ),
                      ) : Container()
                        ,)
                    ],
                  ),
                ],
              ),
            ),
          )
      ),],),
    );
  }

  Widget getImage() {
    return (icon != null) ? Image.asset(icon) : null;
  }

  void anaunceChange() {}
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
          _showPinDialog();
          _clickedCount = 0;
        }
      },
    );
  }

  void _showPinDialog(){
    TextEditingController pinController = TextEditingController(text: (!kReleaseMode || Config().isDev) ? this.pinOfTheDay : '');
    showDialog(context: context, barrierDismissible: false, builder: (context) =>  Dialog(
      child:  Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              Localization().getStringEx('app.title', 'Safer Illinois'),
              style: TextStyle(fontSize: 24, color: Colors.black),
            ),
            Padding(
              padding: EdgeInsets.symmetric(vertical: 26),
              child: Text(
                Localization().getStringEx('panel.debug.label.pin', 'Please enter pin'),
                textAlign: TextAlign.left,
                style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
              ),
            ),
            Container(height: 6,),
            TextField(controller: pinController, autofocus: true, keyboardType: TextInputType.number, obscureText: true,
              onSubmitted:(String value){
                _onEnterPin(value);
              }
              ,),
            Container(height: 6,),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                FlatButton(
                    onPressed: () {
                      Navigator.pop(context);
                      //_finish();
                    },
                    child: Text(Localization().getStringEx('dialog.cancel.title', 'Cancel'))),
                Container(width: 6),
                FlatButton(
                    onPressed: () {
                      _onEnterPin(pinController?.text);
                      //_finish();
                    },
                    child: Text(Localization().getStringEx('dialog.ok.title', 'OK')))
              ],
            )
          ],
        ),
      ),
    ));
  }

  String get pinOfTheDay {
    return DateFormat('MMdd').format(DateTime.now());
  }

  void _onEnterPin(String pin){
    if (this.pinOfTheDay == pin) {
      Navigator.pop(context);
      Navigator.push(context, CupertinoPageRoute(builder: (context) => SettingsDebugPanel()));
    } else {
      AppToast.show("Invalid pin");
    }
  }
}