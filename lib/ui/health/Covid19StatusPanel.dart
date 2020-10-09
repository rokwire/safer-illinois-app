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

import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_swiper/flutter_swiper.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/TransportationService.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/widgets/StatusInfoDialog.dart';
import 'package:illinois/ui/widgets/TrianglePainter.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:qr_flutter/qr_flutter.dart';

class Covid19StatusPanel extends StatefulWidget {

  @override
  _Covid19StatusPanelState createState() => _Covid19StatusPanelState();
}

class _Covid19StatusPanelState extends State<Covid19StatusPanel> implements NotificationsListener {
  final double _headingH1 = 130;
  final double _headingH2 = 80;
  final double _photoSize = 240;

  int _loadingProgress = 0;
  bool _netIdStatusChecked;
  Covid19Status _covid19Status;
  bool _covid19Access;
  Color _colorOfTheDay;
  LinkedHashMap<String, HealthCounty> _counties;

  MemoryImage _photoImage;

  final SwiperController _swiperController = SwiperController();

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [
      Health.notifyStatusChanged,
      Health.notifyProcessingFinished,
    ]);
    _loadCounties();
    _loadCovidStatus();
    _loadColorOfTheDay();
    _loadPhotoBytes();
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  @override
  void onNotification(String name, param) {
    if (name == Health.notifyStatusChanged) {
      _updateCovidStatus(param);
    }
    else if (name == Health.notifyProcessingFinished) {
      _updateCovidStatus(param?.status);
    }
  }

  void _loadCounties(){
    _loadingProgress++;
    Health().loadCounties().then((List<HealthCounty> counties) {
      if (mounted) {
        setState(() {
          _counties = HealthCounty.listToMap(counties);
          _loadingProgress--;
        });
        _checkNetIdStatus();
      }
    });
  }

  void _loadCovidStatus() {
    _loadingProgress++;
    Health().currentCountyStatus.then((Covid19Status status) {
      if (mounted) {
        setState(() {
          _covid19Status = status;
          _loadingProgress--;
        });
        _updateCovid19Access();
        _checkNetIdStatus();
      }
    });
  }

  void _updateCovidStatus(Covid19Status status) {
    if (mounted) {
      setState(() {
        _covid19Status = status;
      });
      _updateCovid19Access();
    }
  }

  void _updateCovid19Access() {
    Health().isBuildingAccessGranted(_covid19Status?.blob?.healthStatus).then((bool granted) {
      if (mounted) {
        setState(() {
          _covid19Access = granted;
        });
      }
    });
  }

  void _loadPhotoBytes() {
    _loadingProgress++;
    _loadAsyncPhotoBytes().whenComplete((){
      if (mounted) {
        setState(() {
          _loadingProgress--;
        });
        _checkNetIdStatus();
      }
    });
  }

  Future<void> _loadAsyncPhotoBytes() async {
    Uint8List photoBytes = await Auth().photoImageBytes;
    if(AppCollection.isCollectionNotEmpty(photoBytes)){
      _photoImage = await compute(AppImage.memoryImageWithBytes, photoBytes);
    }
  }

  HealthCounty get _selectedCounty {
    return (_counties != null) ? _counties[Health().currentCountyId] : null;
  }

  void _loadColorOfTheDay() {
    _loadingProgress++;
    NativeCommunicator().getDeviceId().then((deviceId) {
      TransportationService().loadBussColor(deviceId: deviceId, userId: User().uuid).then((color) {
        if (mounted) {
          setState(() {
            _colorOfTheDay = color;
            _loadingProgress--;
          });
          _checkNetIdStatus();
        }
      });
    });
  }

  void _checkNetIdStatus() {
    if ((_loadingProgress == 0) && (_netIdStatusChecked != true)) {
      _netIdStatusChecked = true;
      if (Auth().isShibbolethLoggedIn && (Auth().authCard?.photoBase64?.length ?? 0) == 0) {
        AppAlert.showDialogResult(context, Localization().getStringEx('panel.covid19_passport.message.missing_id_info', 'No Illini ID information found. You may have an expired i-card. Please contact the ID Center.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                height: _headingH1,
                color: _colorOfTheDay,
              ),
              Container(
                height: _headingH2,
                color: _colorOfTheDay,
                child: CustomPaint(
                  painter: TrianglePainter(painterColor: _backgroundColor),
                  child: Container(),
                ),
              ),
              Expanded(child: Container(color: _backgroundColor,))
            ],
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
            Expanded(child: _userDetails()),
            Container(
              child: SafeArea(
                bottom: true,
              child:
              Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child:Semantics(button: true,label: Localization().getStringEx("panel.covid19_passport.button.close.title", "Close"), child:
                  InkWell(
                      onTap: _onTapClose,
                      child:  Image.asset('images/close-orange-large.png', excludeFromSemantics: true,)
                  ),
                  ))),
            ),
          ]),
          SafeArea(
            child: Stack(
              children: <Widget>[
                Padding(
                    padding: EdgeInsets.all(16),
                    child:Semantics(header: true, child: Text(
                      Localization().getStringEx("panel.covid19_passport.header.title", "COVID-19"),
                      style: TextStyle(
                          color: Styles().colors.white, fontFamily: Styles().fontFamilies.extraBold, fontSize: 16,
                          shadows: [
                           Shadow(
                               offset: Offset(2, 2),
                               blurRadius: 4.0,
                               color: Styles().colors.blackTransparent018,
                           )
                          ]
                      ),),
                    )),
              ],
            ),
          ),
          Visibility(visible: _isLoading, child: Container(width: MediaQuery.of(context).size.width, height: MediaQuery.of(context).size.height, color: Styles().colors.fillColorPrimaryTransparent09,
            child: Center(child: CircularProgressIndicator(),),),)
        ],
      ),
    );
  }

  Widget _userDetails() {
    String userFullName = AppString.getDefaultEmptyString(value: Auth()?.userPiiData?.fullName);

    return SingleChildScrollView(scrollDirection: Axis.vertical, child:
    Column(crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _userAvatar(),
        Padding(padding: EdgeInsets.only(top: 8, bottom: 1), child: Text(
          userFullName,
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 24, color: Styles().colors.fillColorPrimary),
        ),),
        Padding(padding: EdgeInsets.only(bottom: 10),
          child: Text(AppString.getDefaultEmptyString(value: _userRoleString),
            style: TextStyle(color: Styles().colors.mediumGray1, fontSize: 16, fontFamily: Styles().fontFamilies.regular, letterSpacing: 1),),),
        _buildCountyDropdown(),
        _buildStatusDetails(),
      ],
    )
    );
  }

  Widget _buildStatusDetails(){
    return Container(
      child:
        Column(children: <Widget>[
          SizedBox(
            width: 300,
            height: 240,
            child:
            Swiper(
              containerHeight: 240, // Distance from SwiperIndicator
              itemHeight: 200,
              itemCount: 2,
              loop: false,
              controller: _swiperController,
              pagination:SwiperCustomPagination(
                  builder:(BuildContext context, SwiperPluginConfig config){
                    return Container(padding: EdgeInsets.only(top: 200),child:_buildPageIndicator(config.activeIndex));
                  }),
              itemBuilder: (BuildContext context, int index) {
                if(0==index){
                  return _buildAccesLayout();
                } else if(1== index){
                  return _buildQrCode();
                }
                return Container();
              },
            )
          ),
          Container(height: 10,),
//          _buildPageIndicator()
        ],),
    );
  }


  Widget _buildPageIndicator(int index){
    return
      Container(
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Semantics(
              label: Localization().getStringEx("panel.covid19_passport.button.show_page_1.title", "Show page 1 of 2"),
              hint: Localization().getStringEx("panel.covid19_passport.button.show_page_1.hint", ""),
              button: true,
              selected: 0==index,
              child: GestureDetector(
                onTap: (){
                  _swiperController.previous();
                },
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    color: 0==index? Styles().colors.fillColorSecondary : Styles().colors.background,
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                    border: Border.all(color: Styles().colors.fillColorSecondary, width: 2),
                  ),
                ),
              ),
            ),
            Container(width: 8,),
            GestureDetector(
              onTap: (){
                _swiperController.next();
              },
              child: Semantics(
                label: Localization().getStringEx("panel.covid19_passport.button.show_page_2.title", "Show page 2 of 2"),
                hint: Localization().getStringEx("panel.covid19_passport.button.show_page_2.hint", ""),
                button: true,
                selected: 1==index,
                child: Container(
                  height: 12,
                  width: 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.all(Radius.circular(100)),
                    color: 1==index? Styles().colors.fillColorSecondary : Styles().colors.background,
                    border: Border.all(color: Styles().colors.fillColorSecondary, width: 2),
                  ),
                ),
              ),
            ),
          ],),
      );
  }

  Widget _buildAccesLayout() {
    String imageAsset = (_covid19Access == true) ? 'images/group-20.png' : 'images/group-28.png';
    String accessText = '';
    switch (_covid19Access) {
      case true: accessText = Localization().getStringEx("panel.covid19_passport.label.access.granted","GRANTED"); break;
      case false: accessText = Localization().getStringEx("panel.covid19_passport.label.access.denied","DENIED"); break;
    }
    return Semantics(
      label: Localization().getStringEx("panel.covid19_passport.label.page_1", "Page 1"),
      explicitChildNodes: true,
      child: SingleChildScrollView(child:Container(
        child: Column(children: <Widget>[
          Container(height: 15,),
          Image.asset(imageAsset, excludeFromSemantics: true,),
          Container(height: 7,),
          Text(Localization().getStringEx("panel.covid19_passport.label.access.heading","Building Access"),
            style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Styles().colors.fillColorPrimary),),
          Container(height: 6,),
          Text(accessText, style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 28, color: Styles().colors.fillColorPrimary),),
        ],),
      )),
    );
  }

  Widget _buildQrCode(){
    String healthStatus = _covid19Status?.blob?.healthStatus;
    String statusName = _covid19Status?.blob?.localizedHealthStatus ?? '';
    bool userHasHealthStatus = (healthStatus != null);
    Color statusColor = (userHasHealthStatus ? (covid19HealthStatusColor(healthStatus) ?? _backgroundColor) : _backgroundColor);
    String authCardOrPhone = Auth().isShibbolethLoggedIn
        ? Auth().authCard?.magTrack2 ?? ""
        : (Auth().isPhoneLoggedIn ? Auth().userPiiData?.phone : "");
    String textAuthCardOrPhone = Auth().isShibbolethLoggedIn
        ? ""
        : (Auth().isPhoneLoggedIn ? Auth().userPiiData?.phone : "");
    String noStatusDescription = (_counties?.isNotEmpty ?? false) ? 
      Localization().getStringEx('panel.covid19_passport.label.status.empty', "No available status for this County") :
      Localization().getStringEx('panel.covid19_passport.label.counties.empty', "No counties available");
    String qrCodeImageData = AppString.getDefaultEmptyString(value: authCardOrPhone, defaultValue: User().uuid);
    return Semantics(
      label: Localization().getStringEx("panel.covid19_passport.label.page_2", "Page 2"),
      explicitChildNodes: true,
      child: SingleChildScrollView(child:Column(children: <Widget>[
        Visibility(
          visible: userHasHealthStatus,
          child: Container(
            width: 176,
            height: 176,
            padding: EdgeInsets.all(13),
            decoration: BoxDecoration(
                color: statusColor, borderRadius: BorderRadius.circular(4)),
            child: Container(decoration: BoxDecoration(
                color: Styles().colors.white, borderRadius: BorderRadius.circular(4)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
              Visibility(visible: AppString.isStringNotEmpty(qrCodeImageData), child: QrImage(
                data: AppString.getDefaultEmptyString(value: qrCodeImageData),
                version: QrVersions.auto,
                size: MediaQuery.of(context).size.width / 4 + 10,
                padding: EdgeInsets.all(5),),),
              Visibility(visible: AppString.isStringNotEmpty(textAuthCardOrPhone), child: Padding(padding: EdgeInsets.only(top: 5),
                child: Text(
                  AppString.getDefaultEmptyString(value: textAuthCardOrPhone),
                  style: TextStyle(color: Colors.black, fontSize: 12, fontFamily: Styles().fontFamilies.regular),),),),
            ],),),),),
        userHasHealthStatus ?
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child:
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Expanded(child:
                  Text(statusName, style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Styles().colors.textSurface),maxLines: 1, overflow: TextOverflow.ellipsis,),
                ),
                Container(width: 6,),
                Semantics(
                  explicitChildNodes: true,
                  child: Semantics(
                      label: Localization().getStringEx("panel.covid19_passport.button.info.title","Info "),
                      button: true,
                      excludeSemantics: true,
                      child:  IconButton(icon: Image.asset('images/icon-info-orange.png', excludeFromSemantics: true,), onPressed: () =>  StatusInfoDialog.show(context, _selectedCounty?.nameDisplayText ?? ""), padding: EdgeInsets.all(10),)
                ))
            ],)):
          Container(
            padding: EdgeInsets.only(bottom: 8),
            child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
            Expanded(
            child: Text(noStatusDescription, style:TextStyle(color: Colors.black, fontSize: 18, fontFamily: Styles().fontFamilies.regular)),
          )])
          ),

      ],)),
    );
  }

  Widget _buildCountyDropdown(){
    return Visibility(visible: _counties?.isNotEmpty ?? false,
      child: Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 0),
        child: Column(crossAxisAlignment:CrossAxisAlignment.center, children: <Widget>[
          Semantics(container: true, child:
            Padding(padding: EdgeInsets.only(bottom: 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
              Container(
              child: Padding(padding: EdgeInsets.only(left: 12, right: 16),
                child: DropdownButtonHideUnderline(
                    child:DropdownButton(
                      icon: Icon(Icons.arrow_drop_down, color:Styles().colors.fillColorPrimary, semanticLabel: null,),
                      isExpanded: true,
                      style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),
                      hint: Text(_selectedCounty?.nameDisplayText ?? Localization().getStringEx('panel.covid19_passport.label.county.empty.hint',"Select a county...",),
                        style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary,),overflow: TextOverflow.ellipsis,),
                      items: _buildCountyDropdownItems(),
                      onChanged: (value) { _switchCounty(value); },
                    )
                )
              ),
              )
            ],),
          ),
        ),
        Container(height: 12,)
        ])));
  }

  List <DropdownMenuItem> _buildCountyDropdownItems(){
    List <DropdownMenuItem> result;
    if (_counties?.isNotEmpty ?? false) {
      result = List <DropdownMenuItem>();
      for (HealthCounty county in _counties.values) {
        result.add(DropdownMenuItem<dynamic>(
          value: county.id,
          child: Text(county.nameDisplayText),
        ));
      }
    }
    return result;
  }

  String get _userRoleString { // Simplified - show resident for the rest of the situations
    String roleDisplayString = Auth()?.authCard?.roleDisplayString;
    if(Auth().isShibbolethLoggedIn && AppString.isStringNotEmpty(roleDisplayString)){
      return roleDisplayString;
    }
    return UserRole.resident.toDisplayString();
  }

  Widget _userAvatar() {
    return Padding(
      padding: EdgeInsets.only(top: _headingH1 + (_headingH2 - _photoSize) / 2),
      child: _RotatingBorder(
          activeColor: _colorOfTheDay ?? Colors.transparent,
          child: Padding(
              padding: EdgeInsets.all(16),
              child: _userPhotoImage()
          )),
    );
  }

  Widget _userPhotoImage() {
    if (_photoImage != null) {
      return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
            image: DecorationImage(
              fit: BoxFit.cover,
              alignment: Alignment.center,
              image: _photoImage,
            ),
          ));
    } else {
      return Container(
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Styles().colors.fillColorPrimary,
              image: DecorationImage(image: ExactAssetImage('images/3.0x/icon-avatar-placeholder.png'), fit: BoxFit.cover)
          ));
    }
  }

  void _switchCounty(String countyId) {
    setState(() {
      _loadingProgress++;
    });
    Health().switchCounty(countyId).then((Covid19Status status) {
      if (mounted) {
        setState(() {
          _loadingProgress--;
          if (status != null) {
            _covid19Status = status;
          }
        });
        _updateCovid19Access();
      }
    });
  }

  void _onTapClose() {
    Navigator.of(context).pop();
  }

  Color get _backgroundColor {
    return Styles().colors.background;
  }

  bool get _isLoading {
    return ((_loadingProgress > 0) || (Health().processing == true));
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
    return Container( width: _photoSize, height: _photoSize,
        child:Stack(children: <Widget>[
          Transform.rotate(
              angle: angle,
              child:Container(
                height: _photoSize,
                width: _photoSize,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [widget.activeColor, widget.baseGradientColor ?? Styles().colors.fillColorSecondary],
                      stops:  [0.0, 1.0],
                    )
                ),
              )),
          widget.child,
        ], ));
  }

}