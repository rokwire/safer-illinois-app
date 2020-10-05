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

import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:location/location.dart' as Core;
import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/service/LocationServices.dart';

class Covid19TestLocationsPanel extends StatefulWidget {
  _Covid19TestLocationsPanelState createState() => _Covid19TestLocationsPanelState();
}

class _Covid19TestLocationsPanelState extends State<Covid19TestLocationsPanel>{

  LinkedHashMap<String,HealthCounty> _counties;
  List<ProviderDropDownItem> _providerItems;
  ProviderDropDownItem _selectedProviderItem;
  String _initialProviderId;


  Core.LocationData _locationData;
  LocationServicesStatus _locationServicesStatus;

  bool _isLoading = false;
  List<HealthServiceLocation> _locations;

  @override
  void initState() {
    _initialProviderId = Storage().lastHealthProvider?.id;
    _loadLocationsServicesData();
    _loadCounties();

    if (Health().currentCountyId != null) {
      _loadProviders();
    } else {
      _loadLocations(); //load all by default
    }

    super.initState();
  }

  _loadLocations(){
  _isLoading = true;
  Health().loadHealthServiceLocations(countyId: Health().currentCountyId, providerId: _selectedProviderItem?.providerId).then((List<HealthServiceLocation> locations){
    setState(() {
      try {
        _locations = locations;
      } catch(e){
        print(e);
      }
      _isLoading = false;
    });
  });

  }

  @override
  Widget build(BuildContext context) {
    int itemsLength = _locations?.length ?? 0;
    itemsLength+= 2; // for dropdowns
    return Scaffold(
      backgroundColor: Styles().colors.background,
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.covid19_test_locations.header.title", "Test locations"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: _isLoading
        ? Center(child: CircularProgressIndicator(),)
        : Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: itemsLength>0? ListView.builder(
            itemCount: itemsLength,
            itemBuilder: (BuildContext context, int index) {
              if(index == 0)
                return _buildCountyField();
              if(index == 1)
                return _buildProviderField();

              index -= 2; //for dropdowns
              HealthServiceLocation location = (_locations?.isNotEmpty ?? false)? _locations[index] : null;
              //double distance = _locationData!=null && location!=null? AppLocation.distance(location.latitude, location.longitude, _locationData.latitude, _locationData.longitude) : 0;
              return _TestLocation(testLocation: location, /*distance: distance,*/);
            },
          ) : Container(),
        ),
    );
  }

  void _sortLocations() async{
    _locationData = _userLocationEnabled ? await LocationServices.instance.location : null;
    if((_locations?.isNotEmpty?? false) && _locationData!=null){
      _locations.sort((fistLocation, secondLocation) {
          double firstDistance = AppLocation.distance(fistLocation.latitude, fistLocation.longitude, _locationData.latitude, _locationData.longitude);
          double secondDistance = AppLocation.distance(secondLocation.latitude, secondLocation.longitude, _locationData.latitude, _locationData.longitude);
          return  (firstDistance - secondDistance)?.toInt();
      });
      setState(() {});
    }
  }

  void _loadLocationsServicesData(){

    LocationServices.instance.status.then((LocationServicesStatus locationServicesStatus) {
      _locationServicesStatus = locationServicesStatus;

      if (_locationServicesStatus == LocationServicesStatus.PermissionNotDetermined) {
        LocationServices.instance.requestPermission().then((LocationServicesStatus locationServicesStatus) {
          _locationServicesStatus = locationServicesStatus;
          _sortLocations();
        });
      } else {
        _sortLocations();
      }
    });
  }

  Widget _buildCountyField(){
    return Semantics(label: "County dropdown", container: true, child:
    Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 8,),
          _dropDownMenu("Select County…",_counties!=null? _counties[Health().currentCountyId]: null, _counties?.values,
              onChanged: (HealthCounty selectedValue) {
                Health().switchCounty(selectedValue.id);
                //_selectedCountyId = Storage().currentHealthCountyId = selectedValue.id;
                _loadProviders();
              },
              getLabel: (HealthCounty county){
                return "${county?.name} County";
              }
          ),
          Container(height: 26,)
        ],),
    ));
  }

  Widget _buildProviderField(){
    return Semantics(label: "Provider dropdown", container: true, child:
    Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 8,),
          Container(
            decoration: BoxDecoration(
                border: Border.all(
                    color: Styles().colors.surfaceAccent,
                    width: 1),
                borderRadius:
                BorderRadius.all(Radius.circular(4))),
            child: Padding(
              padding: EdgeInsets.only(left: 12, right: 16),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    icon: Image.asset(
                        'images/icon-down-orange.png', excludeFromSemantics: true,),
                    isExpanded: true,
                    style: TextStyle(
                        color: Styles().colors.mediumGray,
                        fontSize: 16,
                        fontFamily:
                        Styles().fontFamilies.regular),
                    hint: Text(_selectedProviderItem == null? Localization().getStringEx("panel.health.covid19.add_test.label.provider.empty_hint","Select a provider") :
                      _selectedProviderItem.title),
                    items: _buildProviderDropDownItems(),
                    onChanged: (ProviderDropDownItem value)=>setState((){
                      Analytics.instance.logSelect(target: "Selected provider: "+value?.title);
                      _selectedProviderItem = value;
                      if(value!= null && ProviderDropDownItemType.provider == value.type ){
                        Storage().lastHealthProvider = value.provider;
                      }
                      _loadLocations();
                    }),
                  )),
            ),
          ),
          Container(height: 26,)
        ],),
    ));
  }

  List<DropdownMenuItem<ProviderDropDownItem>> _buildProviderDropDownItems() {
    int itemsCount = _providerItems?.length ?? 0;
    if (itemsCount == 0) {
      return null;
    }
    List<DropdownMenuItem<ProviderDropDownItem>> items = List<DropdownMenuItem<ProviderDropDownItem>>();

    items.addAll(_providerItems.map((ProviderDropDownItem providerItem){
        return DropdownMenuItem(
          value: providerItem,
          child: Text(providerItem?.title),
        );
    })?.toList());

    return items;
  }


  Widget _dropDownMenu(String hint, dynamic selectedValue, Iterable<dynamic> values ,{Function onChanged, Function getLabel, bool enabled=true}){
    return Container(
      decoration: BoxDecoration(
          border: Border.all(
              color: Styles().colors.surfaceAccent,
              width: 1),
          borderRadius:
          BorderRadius.all(Radius.circular(4))),
      child: Padding(
        padding:
        EdgeInsets.only(left: 12, right: 16),
        child: DropdownButtonHideUnderline(
            child: DropdownButton(

              icon: enabled? Image.asset(
                  'images/icon-down-orange.png', excludeFromSemantics: true,) : Container(),
              isExpanded: true,
              style: TextStyle(
                  color: Styles().colors.mediumGray,
                  fontSize: 16,
                  fontFamily:
                  Styles().fontFamilies.regular),
              hint: Text(selectedValue!=null ? _getLabel(selectedValue, getLabel) : hint),
              items: enabled?_buildDropDownItems(values, getLabel): null,
              onChanged: (value)=>setState(()=>onChanged(value)),
            )),
      ),
    );
  }

  List<DropdownMenuItem<dynamic>> _buildDropDownItems(Iterable<dynamic> items, Function getLabel) {
    int itemsCount = items?.length ?? 0;
    if (itemsCount == 0) {
      return null;
    }
    return items.map((dynamic item) {
      return DropdownMenuItem<dynamic>(
        value: item,
        child: Text(
            _getLabel(item, getLabel)
        ),
      );
    }).toList();
  }

  String _getLabel(dynamic item ,Function getLabel){
    return getLabel!=null?
    getLabel(item) : item?.toString()??"";
  }

  //loading
  void _loadCounties(){
    setState(()=> _isLoading = true);
    Health().loadCounties().then((List<HealthCounty> counties) {
      if (counties != null) {
        _counties = LinkedHashMap<String, HealthCounty>();
        for (HealthCounty county in counties) {
          _counties[county.id] = county;
        }
      }
      setState(()=> _isLoading = false);
    });
  }

  void _loadProviders(){
    setState(()=> _isLoading = true);
    Health().loadHealthServiceProviders().then((List<HealthServiceProvider> providers){
        _isLoading = false;
        _providerItems = List<ProviderDropDownItem>();
        ProviderDropDownItem allProvidersItem = ProviderDropDownItem(type: ProviderDropDownItemType.all, provider: null);
        _providerItems.add(allProvidersItem);
        if(_selectedProviderItem==null && _initialProviderId == null){
          //If there was no previously selected provider select All by default
          _selectedProviderItem = allProvidersItem;
        }
        if(providers?.isNotEmpty?? false) {
          _providerItems.addAll(providers?.map((HealthServiceProvider provider) {
            ProviderDropDownItem item = ProviderDropDownItem(type: ProviderDropDownItemType.provider, provider: provider);
            //Initial selection
            if (_selectedProviderItem == null && _initialProviderId != null) {
              // If we don't have selection but have previously selected providerId
              if (provider?.id == _initialProviderId) {
                _selectedProviderItem = item;
              }
            }
            return item;
          })?.toList());
        }
        setState((){});
        _loadLocations();
    });
  }

  bool get _userLocationEnabled {
    return (_locationServicesStatus == LocationServicesStatus.PermissionAllowed);
  }
}

class _TestLocation extends StatelessWidget{
  final HealthServiceLocation testLocation;
  final double distance;

  _TestLocation({this.testLocation, this.distance = 0});

  @override
  Widget build(BuildContext context) {

    String distanceSufix = Localization().getStringEx("panel.covid19_test_locations.distance.text","mi away get directions");
    String distanceText = distance?.toStringAsFixed(2);
    HealthLocationWaitTimeColor waitTimeColor = testLocation.waitTimeColor;
    bool isWaitTimeAvailable = (waitTimeColor == HealthLocationWaitTimeColor.red) ||
        (waitTimeColor == HealthLocationWaitTimeColor.yellow) ||
        (waitTimeColor == HealthLocationWaitTimeColor.green);
    String waitTimeText = Localization().getStringEx('panel.covid19_test_locations.wait_time.label', 'Wait Time') +
        (isWaitTimeAvailable ? '' : (' ' + Localization().getStringEx('panel.covid19_test_locations.wait_time.unavailable', 'Unavailable')));
    return
      Semantics(button: false, container: true, child:
        Container(
        margin: EdgeInsets.only(top: 8, bottom: 8),
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
            color: Styles().colors.surface,
            borderRadius: BorderRadius.all(Radius.circular(4)),
            boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              testLocation?.name ?? "",
              style: TextStyle(
                fontFamily: Styles().fontFamilies.extraBold,
                fontSize: 20,
                color: Styles().colors.fillColorPrimary,
              ),
            ),
            Semantics(button: true,
            child: GestureDetector(
              onTap: _onTapAddress,
              child: Container(
                  padding: EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: <Widget>[
                      Image.asset('images/icon-location.png',excludeFromSemantics: true),
                      Container(width: 8,),
                      Expanded(child:
                        Text(
                          distance>0? '$distanceText' + distanceSufix:
                          (testLocation?.fullAddress?? Localization().getStringEx("panel.covid19_test_locations.distance.unknown","unknown distance")),
                          style: TextStyle(
                            fontFamily: Styles().fontFamilies.regular,
                            fontSize: 16,
                            color: Styles().colors.textSurface,
                          ),
                        )
                      )
                    ],
                  )),
            )),
            /*Semantics(label: Localization().getStringEx("panel.covid19_test_locations.call.hint","Call"), button: true, child:
            GestureDetector(
              onTap: _onTapContact,
              child:
              Container(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: Row(
                children: <Widget>[
                  Image.asset('images/icon-phone.png', excludeFromSemantics: true,),
                  Container(width: 8,),
                  Text(
                    testLocation?.contact ??Localization().getStringEx("panel.covid19_test_locations.label.contact.title", "Contact"),
                    style: TextStyle(
                      fontFamily: Styles().fontFamilies.regular,
                      fontSize: 16,
                      color: Styles().colors.textSurface,
                    ),
                  )
                ],
              ))
            )),*/
            Container(
                padding: EdgeInsets.only(top: 4),
                child: Row(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: <Widget>[
                        Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Container(
                            width: 16,
                            height: 16,
                            decoration: BoxDecoration(color: HealthServiceLocation.waitTimeColorHex(waitTimeColor), shape: BoxShape.circle),
                          ),
                        ),
                        Text(
                          waitTimeText,
                          style: TextStyle(
                            fontFamily: Styles().fontFamilies.regular,
                            fontSize: 16,
                            color: Styles().colors.textSurface,
                          ),
                        )
                      ],
                    )
                  ],
                )),
              Semantics(explicitChildNodes:true,button: false, child:
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Image.asset('images/icon-time.png',excludeFromSemantics: true),
                  Container(width: 8,),
                  Expanded(child:
                    _buildWorkTime(),
                  )
                ],
              )
            )
          ],
          ),
        )
      );
  }

  Widget _buildWorkTime(){
    List<HealthLocationDayOfOperation> items = List();
    HealthLocationDayOfOperation period;
    LinkedHashMap<int,HealthLocationDayOfOperation> workingPeriods;
    List<HealthLocationDayOfOperation> workTimes = testLocation?.daysOfOperation;
    if(workTimes?.isNotEmpty ?? false){
      workingPeriods = Map<int,HealthLocationDayOfOperation>.fromIterable(workTimes, key: (period) => period?.weekDay);
      items = workingPeriods?.values?.toList()?? List();
      period = _determineTodayPeriod(workingPeriods);
      if ((period == null) || !period.isOpen) {
        period = _findNextPeriod(workingPeriods);  
      }
    } else {
      return Container(
        child: Text(Localization().getStringEx("panel.covid19_test_locations.work_time.unknown","Unknown working time"))
      );
    }

    return DropdownButton<HealthLocationDayOfOperation>(
      isExpanded: true,
      isDense: false,
      underline: Container(),
      value: period,
      onChanged: (value){},
      icon: Image.asset('images/chevron-down.png', color: Styles().colors.fillColorSecondary, excludeFromSemantics: false,),
      selectedItemBuilder:(context){
        return items.map<Widget>((entry){
          return Row(
            children: <Widget>[
              Expanded(child:
              Text(
                _getPeriodText(entry, workingPeriods),
                softWrap: true,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  color: Styles().colors.fillColorPrimary,
                ),
              ),)
            ],
          );
        }).toList();
      },
      items: items.map((entry){
        return DropdownMenuItem<HealthLocationDayOfOperation>(
          value: entry,
          child: Text(
//            _getPeriodText(entry, activePeriod),
            entry.displayString,
            style: TextStyle(
              fontFamily: Styles().fontFamilies.bold,
              fontSize: 16,
              color: Styles().colors.fillColorPrimary,
            ),
          ),
        );
      }).toList(),
    );
  }

  String _getPeriodText(HealthLocationDayOfOperation period, LinkedHashMap<int,HealthLocationDayOfOperation> workingPeriods){
    String openText = Localization().getStringEx("panel.covid19_test_locations.work_time.open_until","Open until");
    String closedText = Localization().getStringEx("panel.covid19_test_locations.work_time.closed_until","Closed until");
    if((period != null) && period.isOpen){ //This is the active Period
      String end = period?.closeTime;
      return "$openText $end";
    } else {
      //Closed until the next open period
      HealthLocationDayOfOperation nextPeriod = _findNextPeriod(workingPeriods);
      String nextOpenTime = nextPeriod!=null? nextPeriod.name +" "+nextPeriod.openTime : " ";
      return "$closedText $nextOpenTime";
    }
  }

  HealthLocationDayOfOperation _determineTodayPeriod(LinkedHashMap<int,HealthLocationDayOfOperation> workingPeriods){
    int currentWeekDay = DateTime.now().weekday;
    return workingPeriods!=null? workingPeriods[currentWeekDay] : null;
  }

  HealthLocationDayOfOperation _findNextPeriod(
      LinkedHashMap<int, HealthLocationDayOfOperation> workingPeriods) {
    if (workingPeriods != null && workingPeriods.isNotEmpty) {
      // First, check if the current day period will open today
      int currentWeekDay = DateTime.now().weekday;
      HealthLocationDayOfOperation period = workingPeriods[currentWeekDay];
      if ((period != null) && period.willOpen) return period;

      // Modulus math works better with 0 based indexes, and flutter uses 1 based
      // weekdays
      int currentWeekDay0 = currentWeekDay - 1;
      for (int offset = 1; offset < 7; offset++) {
        // Take the current day (0 based), add the offset we want to check,
        // modulus 7 to wrap it around in the array, and add 1 to get the flutter
        // weekday index.
        int offsetDay = ((currentWeekDay0 + offset) % 7) + 1;

        period = workingPeriods[offsetDay];
        if (period != null) return period;
      }

      //If there is no nex period - return the fist element
      return workingPeriods?.values?.toList()[0];
    }
    return null;
  }

  /*void _onTapContact() async{
    await url_launcher.launch("tel:"+testLocation?.contact ?? "");
  }*/

  void _onTapAddress(){
    Analytics.instance.logSelect(target: "COVID-19 Test Location");
    double lat = testLocation?.latitude;
    double lng = testLocation?.longitude;
    if ((lat != null) && (lng != null)) {
      NativeCommunicator().launchMap(
          target: {
            'latitude': testLocation?.latitude,
            'longitude': testLocation?.longitude,
            'zoom': 17,
          },
          markers: [{
            'name': testLocation?.name,
            'description': testLocation?.fullAddress,
            'latitude': testLocation?.latitude,
            'longitude': testLocation?.longitude,
          }]);
    }
  }
}

enum ProviderDropDownItemType{
  provider, all
}

class ProviderDropDownItem{
  final ProviderDropDownItemType type;
  final HealthServiceProvider provider;

  ProviderDropDownItem({this.type, this.provider});

  String get title{
    if(type == ProviderDropDownItemType.all){
      return Localization().getStringEx("panel.covid19_test_locations.all_providers.text" ,"All Providers");
    } else {
      return provider?.name ?? "";
    }
  }

  String get providerId{
    if(type == ProviderDropDownItemType.all){
      return null;
    } else {
      return provider?.id;
    }
  }
}