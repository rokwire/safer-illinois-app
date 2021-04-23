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

import 'dart:async';
import 'dart:typed_data';
import 'package:intl/intl.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/TransportationService.dart';
import 'package:illinois/service/UserProfile.dart';
import 'package:illinois/ui/widgets/StatusInfoDialog.dart';
import 'package:illinois/ui/widgets/TrianglePainter.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:qr_flutter/qr_flutter.dart';

class HealthStatusPanel extends StatefulWidget {

  @override
  _HealthStatusPanelState createState() => _HealthStatusPanelState();
}

class _HealthStatusPanelState extends State<HealthStatusPanel> implements NotificationsListener {
  final double _headingH1 = 130;
  final double _headingH2 = 80;
  final double _photoSize = 240;

  List<HealthCounty> _counties;
  Color _colorOfTheDay;
  String _currentDateTime;
  Timer _currentDateTimeTimer;
  MemoryImage _photoImage;
  bool _netIdStatusChecked;
  bool _loading;

  final SwiperController _swiperController = SwiperController();

  @override
  void initState() {
    super.initState();

    NotificationService().subscribe(this, [
      Health.notifyStatusUpdated,
    ]);

    _currentDateTime = _getCurrentDateTime();
    _currentDateTimeTimer = Timer.periodic(const Duration(seconds: 1), _updateCurrentDateTime);

    _initData();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);

    if (_currentDateTimeTimer != null) {
      _currentDateTimeTimer.cancel();
      _currentDateTimeTimer = null;
    }
  }

  @override
  void onNotification(String name, param) {
    if (name == Health.notifyStatusUpdated) {
      if (mounted) {
        setState(() {});
      }
    }
  }

  void _initData() {
    _loading = true;
    Future.wait([
      Health().refreshStatusAndUser(),
      Health().loadCounties(),
      _loadColorOfTheDay(),
      _loadPhotoBytes(),
    ]).then((List<dynamic> results) {
      if (mounted) {
        setState(() {
          _counties = ((results != null) && (1 < results.length)) ? results[1]  : null;
          _colorOfTheDay = ((results != null) && (2 < results.length)) ? results[2] : null;
          _photoImage = ((results != null) && (3 < results.length)) ? results[3] : null;
          _loading = false;
        });
        _checkNetIdStatus();
      }
    });
  }

  static Future<Color> _loadColorOfTheDay() async {
    return await TransportationService().loadBussColor(deviceId: await NativeCommunicator().getDeviceId(), userId: UserProfile().uuid);
  }

  static Future<MemoryImage> _loadPhotoBytes() async {
    Uint8List photoBytes = await Auth().photoImageBytes;
    return AppCollection.isCollectionNotEmpty(photoBytes) ? await compute(AppImage.memoryImageWithBytes, photoBytes) : null;
  }

  void _checkNetIdStatus() {
    if ((_loading != true) && (_netIdStatusChecked != true)) {
      _netIdStatusChecked = true;
      if (Auth().isShibbolethLoggedIn && (Auth().authCard?.photoBase64?.length ?? 0) == 0) {
        AppAlert.showDialogResult(context, Localization().getStringEx('panel.covid19_passport.message.missing_id_info', 'No Illini ID information found. You may have an expired i-card. Please contact the ID Center.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body:
      Stack(children: <Widget>[
        Column(children: <Widget>[
          Container(height: _headingH1, color: _colorOfTheDay,),
          Container(height: _headingH2, color: _colorOfTheDay, child:
            CustomPaint(painter: TrianglePainter(painterColor: _backgroundColor), child: Container(),),
          ),
          Expanded(child: Container(color: _backgroundColor,))
        ],),
        Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
          Expanded(child: _userDetails()),
          SafeArea(child:
            Padding(padding: EdgeInsets.only(bottom: 10), child:
              Semantics(button: true, label: Localization().getStringEx("panel.covid19_passport.button.close.title", "Close"), child:
                InkWell(onTap: _onTapClose, child:
                  Image.asset('images/close-orange-large.png', excludeFromSemantics: true,)
                ),
          ))),
        ]),
        SafeArea(child:
            Padding(padding: EdgeInsets.all(16), child:
              Semantics(header: true, child:
                Text(Localization().getStringEx("panel.covid19_passport.header.title", "COVID-19"), style: TextStyle(color: Styles().colors.white, fontFamily: Styles().fontFamilies.extraBold, fontSize: 16, shadows: [Shadow(offset: Offset(2, 2), blurRadius: 4.0, color: Styles().colors.blackTransparent018,)]),),
              )
            ),
        ),
        Visibility(visible: (_loading == true), child:
          Container(width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.height, color: Styles().colors.fillColorPrimaryTransparent09, child:
            Center(child: CircularProgressIndicator(),),
          ),
        ),
      ],),
    );
  }

  Widget _userDetails() {
    return SingleChildScrollView(scrollDirection: Axis.vertical, child:
      Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
        _userAvatarWidget(),
        Padding(padding: EdgeInsets.only(top: 8, bottom: 1), child:
          Text(AppString.getDefaultEmptyString(value: _userNameString), textAlign: TextAlign.center, style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 24, color: Styles().colors.fillColorPrimary),),
        ),
        Padding(padding: EdgeInsets.only(bottom: 10), child:
          Text(AppString.getDefaultEmptyString(value: _userRoleString), style: TextStyle(color: Styles().colors.mediumGray1, fontSize: 16, fontFamily: Styles().fontFamilies.regular, letterSpacing: 1),),
        ),
        _buildCountyDropdown(),
        _buildStatusDetails(),
      ],
    )
    );
  }

  Widget _buildStatusDetails(){
    return Column(children: <Widget>[
      SizedBox(width: 300, height: 240, child:
        Swiper(containerHeight: 240, itemHeight: 200, itemCount: 2, loop: false, controller: _swiperController,
          pagination: SwiperCustomPagination(
            builder: (BuildContext context, SwiperPluginConfig config) {
              return Container(padding: EdgeInsets.only(top: 200),child: _buildPageIndicator(config.activeIndex));
            }
          ),
          itemBuilder: (BuildContext context, int index) {
            switch(index) {
              case 0: return _buildAccesLayout();
              case 1: return _buildQrCode();
              default: return Container();
            }
          },
        ),
      ),
      // Container(height: 10,),
      // _buildPageIndicator()
    ],);
  }


  Widget _buildPageIndicator(int index){
    return  Row(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
      Semantics(label: Localization().getStringEx("panel.covid19_passport.button.show_page_1.title", "Show page 1 of 2"), hint: Localization().getStringEx("panel.covid19_passport.button.show_page_1.hint", ""), button: true, selected: (0 == index), child:
        GestureDetector( onTap: () { _swiperController.previous(); }, child:
          Container(height: 12, width: 12, decoration: BoxDecoration(color: (0 == index) ? Styles().colors.fillColorSecondary : Styles().colors.background, borderRadius: BorderRadius.all(Radius.circular(100)), border: Border.all(color: Styles().colors.fillColorSecondary, width: 2), ), ),
        ),
      ),
      Container(width: 8,),
      GestureDetector(onTap: () { _swiperController.next(); }, child:
        Semantics(label: Localization().getStringEx("panel.covid19_passport.button.show_page_2.title", "Show page 2 of 2"), hint: Localization().getStringEx("panel.covid19_passport.button.show_page_2.hint", ""), button: true, selected: (1 == index), child:
          Container(height: 12, width: 12, decoration: BoxDecoration(borderRadius: BorderRadius.all(Radius.circular(100)), color: (1 == index) ? Styles().colors.fillColorSecondary : Styles().colors.background, border: Border.all(color: Styles().colors.fillColorSecondary, width: 2), ), ),
        ),
      ),
    ],);
  }

  Widget _buildAccesLayout() {
    String imageAsset = (Health().buildingAccessGranted == true) ? 'images/group-20.png' : 'images/group-28.png';
    String currentDateTime = DateFormat("MMM d, yyyy HH:mm a").format(DateTime.now());
    String accessText;
    switch (Health().buildingAccessGranted) {
      case true:  accessText = Localization().getStringEx("panel.covid19_passport.label.access.granted", "GRANTED"); break;
      case false: accessText = Localization().getStringEx("panel.covid19_passport.label.access.denied", "DENIED"); break;
    }
    return Semantics(label: Localization().getStringEx("panel.covid19_passport.label.page_1", "Page 1"), explicitChildNodes: true, child:
      SingleChildScrollView(child:Container(child:
        Column(children: <Widget>[
          Container(height: 15,),
          Image.asset(imageAsset, excludeFromSemantics: true,),
          Container(height: 5,),
          Text(Localization().getStringEx("panel.covid19_passport.label.access.heading", "Building Access"), style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Styles().colors.fillColorPrimary),),
          Text(currentDateTime, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
          Container(height: 15,),
          Text(accessText ?? '', style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 28, color: Styles().colors.fillColorPrimary),),
        ],),
      )),
    );
  }

  Widget _buildQrCode(){
    String statusCode = Health().status?.blob?.code;
    String statusName = Health().rules?.codes[statusCode]?.displayName(rules: Health().rules) ?? '';
    Color statusColor = Health().rules?.codes[statusCode]?.color ?? _backgroundColor;
    String authCardOrPhone = this._userQRCodeContent;
    String textAuthCardOrPhone = this._userQRCodeDescr;
    String noStatusDescription = (_counties?.isNotEmpty ?? false) ? 
      Localization().getStringEx('panel.covid19_passport.label.status.empty', "No available status for this County") :
      Localization().getStringEx('panel.covid19_passport.label.counties.empty', "No counties available");
    
    List<Widget> contentList;
    if (statusCode != null) {
      contentList = <Widget>[
        Container(width: 176, height: 176, padding: EdgeInsets.all(13), decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(4)), child:
          Container(decoration: BoxDecoration(color: Styles().colors.white, borderRadius: BorderRadius.circular(4)), child:
            Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Visibility(visible: AppString.isStringNotEmpty(authCardOrPhone), child:
                QrImage(data: AppString.getDefaultEmptyString(value: authCardOrPhone), version: QrVersions.auto, size: MediaQuery.of(context).size.width / 4 + 10, padding: EdgeInsets.all(5),),),
              Visibility(visible: AppString.isStringNotEmpty(textAuthCardOrPhone), child:
                Padding(padding: EdgeInsets.only(top: 5), child: 
                  Text(AppString.getDefaultEmptyString(value: textAuthCardOrPhone), style: TextStyle(color: Colors.black, fontSize: 12, fontFamily: Styles().fontFamilies.regular),),
                ),
              ),
            ],),
          ),
        ),
        Padding(padding: const EdgeInsets.only(bottom: 16), child:
          Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
            Expanded(child:
              Text(statusName, style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Styles().colors.textSurface),maxLines: 1, overflow: TextOverflow.ellipsis,),
            ),
            Container(width: 6,),
            Semantics( explicitChildNodes: true, child: 
              Semantics(label: Localization().getStringEx("panel.covid19_passport.button.info.title","Info "), button: true, excludeSemantics: true, child:  
                IconButton(icon: Image.asset('images/icon-info-orange.png', excludeFromSemantics: true,), onPressed: () =>  StatusInfoDialog.show(context, Health().county?.displayName ?? ""), padding: EdgeInsets.all(10),)
              )
            )
          ],)
        ),
      ];
    }
    else {
      contentList = <Widget>[
        Container(padding: EdgeInsets.only(bottom: 8), child:
          Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Expanded(child: 
              Text(noStatusDescription, style:TextStyle(color: Colors.black, fontSize: 18, fontFamily: Styles().fontFamilies.regular)),
            ),
          ]),
        ),
      ];
    }

    return Semantics(label: Localization().getStringEx("panel.covid19_passport.label.page_2", "Page 2"), explicitChildNodes: true, child:
      SingleChildScrollView(child:
        Column(children: contentList,),
      ),
    );
  }

  Widget _buildCountyDropdown(){
    return Visibility(visible: _counties?.isNotEmpty ?? false, child:
      Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 0), child:
        Column(crossAxisAlignment:CrossAxisAlignment.center, children: <Widget>[
          Semantics(container: true, child:
            Padding(padding: EdgeInsets.only(bottom: 0), child:
              Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
                Padding(padding: EdgeInsets.only(left: 12, right: 16), child:
                  DropdownButtonHideUnderline(child:
                    DropdownButton(
                      icon: Icon(Icons.arrow_drop_down, color:Styles().colors.fillColorPrimary, semanticLabel: null,),
                      isExpanded: true,
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),
                      hint: Text(Health().county?.displayName ?? Localization().getStringEx('panel.covid19_passport.label.county.empty.hint',"Select a county...",), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),overflow: TextOverflow.ellipsis,),
                      items: _buildCountyDropdownItems(),
                      onChanged: (value) { _switchCounty(value); },
                    )
                  )
                ),
            ],),
          ),
        ),
        Container(height: 12,)
        ]),
      ),
    );
  }

  List <DropdownMenuItem> _buildCountyDropdownItems(){
    List <DropdownMenuItem> result;
    if (_counties?.isNotEmpty ?? false) {
      result = List <DropdownMenuItem>();
      for (HealthCounty county in _counties) {
        result.add(DropdownMenuItem<dynamic>(
          value: county,
          child: Text(county.displayName ?? ''),
        ));
      }
    }
    return result;
  }

  bool get _isDefaultUserAccount {
    return (Health().userAccount?.isDefault != false);
  }

  String get _userNameString {
    String userNameString = _isDefaultUserAccount ? Auth().fullUserName : null;
    return ((userNameString != null) && (0 < userNameString.length)) ? userNameString : Health().userAccount?.fullName;
  }

  String get _userRoleString {
    String userRoleString = (_isDefaultUserAccount && Auth().isShibbolethLoggedIn) ? Auth().authCard?.roleDisplayString : null;
    return ((userRoleString != null) && (0 < userRoleString.length)) ? userRoleString : Localization().getStringEx("panel.covid19_passport.label.capitol_staff", "Non University Member");
//  return Localization().getStringEx('panel.covid19_passport.label.resident', 'Resident');
  }

  MemoryImage get _userPhotoImage {
    return _isDefaultUserAccount ? _photoImage : null;
  }

  String get _userQRCodeContent {
    String qrCodeContent;
    if (_isDefaultUserAccount) {
      if (Auth().isShibbolethLoggedIn) {
        qrCodeContent = Auth().authCard?.magTrack2;
      }
      else if (Auth().isPhoneLoggedIn) {
        if (AppString.isStringNotEmpty(Auth().authUser?.uin)) {
          qrCodeContent = "xxxx${Auth().authUser.uin}xxx=xxxxxxxxxxx";
        }
        else {
          qrCodeContent = Auth().phoneToken?.phone;
        }
      }
    }
    else {
      if (AppString.isStringNotEmpty(Health().userAccount?.externalId)) {
        qrCodeContent = "xxxx${Health().userAccount.externalId}xxx=xxxxxxxxxxx";
      }
    }
    return ((qrCodeContent != null) && (0 < qrCodeContent.length)) ? qrCodeContent : UserProfile().uuid;
  }

  String get _userQRCodeDescr {
    if (_isDefaultUserAccount) {
      if (Auth().isShibbolethLoggedIn) {
        return null;
      }
      else if (Auth().isPhoneLoggedIn) {
        if (AppString.isStringNotEmpty(Auth().authUser?.uin)) {
          return Auth().authUser?.uin;
        }
        else {
          return Auth().phoneToken?.phone;
        }
      }
      else {
        return null;
      }
    }
    else {
      if (AppString.isStringNotEmpty(Health().userAccount?.externalId)) {
        return Health().userAccount.externalId;
      }
      else {
        return null;
      }
    }
  }

  Widget _userAvatarWidget() {
    double screenWidth = MediaQuery.of(context).size.width;
    double vaccinatedPaddingWidth = 20;
    double vaccinatedIconWidth = (screenWidth - _photoSize) / 2 - (3 * vaccinatedPaddingWidth / 2);
    return Padding(padding: EdgeInsets.only(top: _headingH1 + (_headingH2 - _photoSize) / 2), child:
      Stack(children: [
        Align(alignment: Alignment.center, child:
          _RotatingBorder(activeColor: _colorOfTheDay ?? Colors.transparent, child:
            Padding(padding: EdgeInsets.all(16), child:
              _userPhotoImageWidget()
            ),
          ),
        ),
        Visibility(visible: Health().isVaccinated, child:
          Container(width: screenWidth, height: _photoSize, child:
            Align(alignment: Alignment.bottomRight, child:
              Padding(padding: EdgeInsets.only(right: vaccinatedPaddingWidth), child:
                Semantics(label: Localization().getStringEx("panel.covid19_passport.icon.vaccine.effective.title", "Vaccine Effective"), excludeSemantics: true, child:  
                  Image.asset('images/vaccinated_icon.png', width: vaccinatedIconWidth, excludeFromSemantics: true,)
                ),
              ),
            ),
          ),
        ),
      ],),
    );
  }

  Widget _userPhotoImageWidget() {
    return Container(decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: (_userPhotoImage != null) ? Colors.white : Styles().colors.fillColorPrimary,
      image: DecorationImage(fit: BoxFit.cover, alignment: Alignment.center, image: _userPhotoImage ?? ExactAssetImage('images/3.0x/icon-avatar-placeholder.png'),),
    ),);
  }

  void _switchCounty(HealthCounty county) {
    setState(() {
      _loading = true;
    });
    Health().setCounty(county).then((_) {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    });
  }

  void _onTapClose() {
    Navigator.of(context).pop();
  }

  Color get _backgroundColor {
    return Styles().colors.background;
  }

  static String _getCurrentDateTime() {
    return DateFormat("MMM d, yyyy HH:mm a").format(DateTime.now());
  }

  void _updateCurrentDateTime(_) {
    if (mounted && (_loading != true)) {
      String currentDateTime = _getCurrentDateTime();
      if (currentDateTime != _currentDateTime) {
        setState(() {
          _currentDateTime = currentDateTime;
        });
      }
    }
  }

}

class _RotatingBorder extends StatefulWidget{
  final Widget child;
  final Color activeColor;
  final Color baseGradientColor;
  const _RotatingBorder({Key key, this.child, this.activeColor, this.baseGradientColor}) : super(key: key);

  @override
  _RotatingBorderState createState() => _RotatingBorderState();

}

class _RotatingBorderState extends State<_RotatingBorder>
    with SingleTickerProviderStateMixin{
  final double _photoSize = 240;
  Animation<double> animation;
  AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: Duration(hours: 1),animationBehavior: AnimationBehavior.preserve);
    animation = Tween<double>(begin: 0, end: 15000,).animate(controller)
      ..addListener(() {
        setState(() {});
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          controller.repeat().orCancel;

        } else if (status == AnimationStatus.dismissed) {
          controller.forward();
        }
      });
    controller.forward();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double angle = animation.value;
    return Container( width: _photoSize, height: _photoSize, child:
      Stack(children: <Widget>[
        Transform.rotate(angle: angle, child:
          Container(height: _photoSize, width: _photoSize, decoration:
            BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(colors: [widget.activeColor, widget.baseGradientColor ?? Styles().colors.fillColorSecondary], stops:  [0.0, 1.0],),
            ),
          )
        ),
        widget.child,
      ],
    ));
  }

}