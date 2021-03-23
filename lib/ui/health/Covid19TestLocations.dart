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

  LinkedHashMap<String, HealthCounty> _counties;
  String _selectedCountyId;

  List<ProviderDropDownItem> _providerItems;
  ProviderDropDownItem _selectedProviderItem;
  
  List<HealthServiceLocation> _locations;
  Core.LocationData _currentLocation;

  int _loadingCount = 0;
  String _countyError, _providersError, _locationsError;

  @override
  void initState() {
    
    _selectedCountyId = Health().currentCountyId;
    
    _loadCounties();
    
    if (_selectedCountyId != null) {
      _loadProviders(countyId: _selectedCountyId);
    }

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    Widget contentWidget;
    
    if (0 < _loadingCount) {
      contentWidget = _buildLoading();
    }
    else if (_errorText != null) {
      contentWidget = _buildStatus(_errorText);
    }
    else if (AppCollection.isCollectionEmpty(_locations)) {
      contentWidget = _buildStatus(Localization().getStringEx("panel.covid19_test_locations.no_locations.text", "No Locations found for selected provider and county") );
    }
    else {
      contentWidget = ListView.builder(
        itemCount: _locations.length,
        itemBuilder: (BuildContext context, int index) {
          return _TestLocation(testLocation: _locations[index], /*distance: distance,*/);
        },
      );
    }

    return Scaffold(
      backgroundColor: Styles().colors.background,
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.covid19_test_locations.header.title", "Test locations"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: SafeArea(child:
        Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32), child:
          Column(children: [
            _buildCountyField(),
            Container(height: 32),
            _buildProviderField(),
            Container(height: 32),
            Expanded(child: contentWidget),
          ],),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child:
      Column(children: [
        Expanded(flex: 1, child: Container()),
        Center(child: CircularProgressIndicator(),),
        Expanded(flex: 3, child: Container()),
      ],),);
  }

  Widget _buildStatus(String text) {
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 32), child:
      Column(children: [
        Expanded(flex: 1, child: Container()),
        Text(text, textAlign: TextAlign.center, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 20, color: Styles().colors.fillColorPrimary,)),
        Expanded(flex: 3, child: Container()),
      ],),);
  }

  Widget _buildCountyField() {
    HealthCounty selectedCounty = (_counties != null) ? _counties[_selectedCountyId] : null;
    return Semantics(label: Localization().getStringEx("panel.covid19_test_locations.county_dropdown.text", "County dropdown") , container: true, child:
      Container(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
          Container(
            decoration: BoxDecoration(
                border: Border.all(color: Styles().colors.surfaceAccent, width: 1),
                borderRadius: BorderRadius.all(Radius.circular(4))),
            child: Padding(padding: EdgeInsets.only(left: 12, right: 16),
              child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                    isExpanded: true,
                    style: TextStyle(color: Styles().colors.mediumGray, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
                    hint: Text(selectedCounty == null ? Localization().getStringEx("panel.covid19_test_locations.select_county.text", "Select a county") : selectedCounty.name),
                    items: (_loadingCount == 0) ? _buildCountyDropDownItems() : null,
                    onChanged: (_loadingCount == 0) ? _switchCounty : null,
                  ),
              ),
            ),
          ),
        ],),
      ));
  }

  List<DropdownMenuItem<HealthCounty>> _buildCountyDropDownItems() {
    int itemsCount = _counties?.values?.length ?? 0;
    if (itemsCount == 0) {
      return null;
    }
    return _counties.values.map((HealthCounty item) {
      return DropdownMenuItem<HealthCounty>(value: item, child: Text(item.name));
    }).toList();
  }

  Widget _buildProviderField() {
    return Semantics(label: Localization().getStringEx("panel.covid19_test_locations.provider_dropdown.text", "Provider dropdown"), container: true, child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: Styles().colors.surfaceAccent, width: 1),
              borderRadius: BorderRadius.all(Radius.circular(4))),
          child: Padding(
            padding: EdgeInsets.only(left: 12, right: 16),
            child: DropdownButtonHideUnderline(
                child: DropdownButton(
                  icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                  isExpanded: true,
                  style: TextStyle(color: Styles().colors.mediumGray, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
                  hint: Text(_selectedProviderItem == null ? Localization().getStringEx("panel.covid19_test_locations.select_provider.text", "Select a provider") : _selectedProviderItem.title),
                  items: _buildProviderDropDownItems(),
                  onChanged: (_loadingCount == 0) ? _switchProvider : null,
                )),
          ),
        ),
      ],),
    );
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

  void _loadCounties() {
    setState(() {
      _loadingCount++;
    });
    Health().loadCounties().then((List<HealthCounty> counties) {
      if (mounted) {
        String countyError;
        LinkedHashMap<String, HealthCounty> countiesMap;
        String selectedCountyId = _selectedCountyId;

        if (counties != null) {
          countiesMap = LinkedHashMap<String, HealthCounty>();
          for (HealthCounty county in counties) {
            countiesMap[county.id] = county;
          }
          if (selectedCountyId == null) {
            HealthCounty defaultCounty = HealthCounty.defaultCounty(counties);
            if ((defaultCounty == null) && (0 < _counties.length)) {
              defaultCounty = counties.first;
            }
            selectedCountyId = defaultCounty?.id;
          }
        }
        else {
          countyError = Localization().getStringEx("panel.covid19_test_locations.error.counties.text", "Failed to load counties");
        }

        bool loadProviders = (_selectedCountyId == null);

        setState(() {
          _counties = countiesMap;
          _selectedCountyId = selectedCountyId;
          _countyError = countyError;
          _loadingCount--;
        });

        if (loadProviders) {
          _loadProviders(countyId: _selectedCountyId);
        }
      }
    });
  }

  void _loadProviders({String countyId}) {
    setState(() {
      _loadingCount++;
    });

    Health().loadHealthServiceProviders(countyId: countyId).then((List<HealthServiceProvider> providers){
      if (mounted) {
        List<ProviderDropDownItem> providerItems;
        ProviderDropDownItem selectedProviderItem;
        String providersError;
        
        if (providers != null) {

          // init providers list
          providerItems = List<ProviderDropDownItem>();
          providerItems.add(ProviderDropDownItem(type: ProviderDropDownItemType.all));
          for (HealthServiceProvider provider in providers) {
            providerItems.add(ProviderDropDownItem(provider: provider));
          }

          // init selected provider
          if ((_selectedProviderItem != null) && providerItems.contains(_selectedProviderItem)) {
            selectedProviderItem = _selectedProviderItem;
          }
          if (selectedProviderItem == null) {
            HealthServiceProvider lastProvicer = Storage().lastHealthProvider;
            if ((lastProvicer != null) && providerItems.contains(ProviderDropDownItem(provider: lastProvicer))) {
              selectedProviderItem = ProviderDropDownItem(provider: lastProvicer);
            }
          }
          if (selectedProviderItem == null) {
            selectedProviderItem = ProviderDropDownItem(type: ProviderDropDownItemType.all);
          }
        }
        else {
          providersError = Localization().getStringEx("panel.covid19_test_locations.error.providers.text", "Failed to load providers");
        }

        setState((){
          _providerItems = providerItems;
          _selectedProviderItem = selectedProviderItem;
          _providersError = providersError;
          _loadingCount--;
        });
        
        _loadLocations(countyId: countyId, providerId: _selectedProviderItem?.provider?.id);
      }
    });
  }

  void _loadLocations({String countyId, String providerId}) {
    setState(() {
      _loadingCount++;
    });

    Health().loadHealthServiceLocations(countyId: countyId, providerId: providerId).then((List<HealthServiceLocation> locations) {
      if (mounted) {
        _sortLocations(locations).then((_) {
          if (mounted) {
            setState(() {
              _locations = locations;
              _locationsError = (locations == null) ? "Failed to load locations" : null;
              _loadingCount--;
            });
          }
        });
      }
    });
  }


  Future<void> _sortLocations(List<HealthServiceLocation> locations) async {
    
    if ((locations != null) && (1 < locations.length)) {
      
      // Ensure current location, if available
      if (_currentLocation == null) {
        LocationServicesStatus status = await LocationServices.instance.status;
        if (status == LocationServicesStatus.PermissionNotDetermined) {
          status = await LocationServices.instance.requestPermission();
        }
        if (status == LocationServicesStatus.PermissionAllowed) {
          _currentLocation = await LocationServices.instance.location;
        }
      }

      // Sort by current location, if available
      if (_currentLocation != null) {
        locations.sort((fistLocation, secondLocation) {
          if ((fistLocation.latitude != null) && (fistLocation.longitude != null)) {
            if ((secondLocation.latitude != null) && (secondLocation.longitude != null)) {
              double firstDistance = AppLocation.distance(fistLocation.latitude, fistLocation.longitude, _currentLocation.latitude, _currentLocation.longitude);
              double secondDistance = AppLocation.distance(secondLocation.latitude, secondLocation.longitude, _currentLocation.latitude, _currentLocation.longitude);
              return firstDistance.compareTo(secondDistance);
            }
            else {
              return 1; // (fistLocation > secondLocation)
            }
          }
          else {
            if ((secondLocation.latitude != null) && (secondLocation.longitude != null)) {
              return -1; // (fistLocation < secondLocation)
            }
            else {
              return 0; // fistLocation == secondLocation == null
            }
          }
        });
      }
    }
  }

  void _switchCounty(HealthCounty selectedValue) {
    Analytics.instance.logSelect(target: "Selected county: " + selectedValue?.name);
    setState(() {
      _selectedCountyId = selectedValue?.id;
    });
    Health().switchCounty(selectedValue?.id);
    _loadProviders(countyId: selectedValue?.id);
  }

  void _switchProvider(ProviderDropDownItem selectedValue) {
    Analytics.instance.logSelect(target: "Selected provider: " + selectedValue?.title);
    
    setState((){
      _selectedProviderItem = selectedValue;
    });
    
    //if (selectedValue?.provider != null) {
      Storage().lastHealthProvider = selectedValue?.provider;
    //}
    
    _loadLocations(countyId: _selectedCountyId, providerId: selectedValue?.provider?.id);
  }

  String get _errorText {
    return _countyError ?? _providersError ?? _locationsError;
  }
}

class _TestLocation extends StatelessWidget {
  final HealthServiceLocation testLocation;
  final double distance;

  _TestLocation({this.testLocation, this.distance = 0});

  @override
  Widget build(BuildContext context) {

    String distanceSufix = Localization().getStringEx("panel.covid19_test_locations.distance.text","mi away get directions");
    String distanceText = distance?.toStringAsFixed(2);

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
            Text(testLocation?.name ?? "", style: TextStyle(fontFamily: Styles().fontFamilies.extraBold, fontSize: 20, color: Styles().colors.fillColorPrimary, ),
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
                          distance > 0 ? '$distanceText' + distanceSufix:
                          (testLocation?.fullAddress?? Localization().getStringEx("panel.covid19_test_locations.distance.unknown","unknown distance")),
                          style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface, ),
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
              _buildWaitTime(),
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

  Widget _buildWaitTime(){
    if(!_isLocationOpen){
      return Container();
    }

    HealthLocationWaitTimeColor waitTimeColor = testLocation.waitTimeColor;
    bool isWaitTimeAvailable = (waitTimeColor == HealthLocationWaitTimeColor.red) ||
        (waitTimeColor == HealthLocationWaitTimeColor.yellow) ||
        (waitTimeColor == HealthLocationWaitTimeColor.green);
    String waitTimeText = "";
    if(isWaitTimeAvailable)  {
      if(waitTimeColor == HealthLocationWaitTimeColor.red){
        waitTimeText = Localization().getStringEx('panel.covid19_test_locations.wait_time.status.label.red', 'Long wait time');
      } else if(waitTimeColor == HealthLocationWaitTimeColor.yellow){
        waitTimeText = Localization().getStringEx('panel.covid19_test_locations.wait_time.status.label.yellow', 'Medium wait time');
      } else if(waitTimeColor == HealthLocationWaitTimeColor.green){
        waitTimeText = Localization().getStringEx('panel.covid19_test_locations.wait_time.status.label.green', 'Short wait time');
      }
    } else {
      {
        waitTimeText = Localization().getStringEx(
            'panel.covid19_test_locations.wait_time.unavailable',
            'Unknown wait time');
      }
    }
    return Container(
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
        ));
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


  bool get _isLocationOpen{
    HealthLocationDayOfOperation todayPeriod;
    if(AppCollection.isCollectionNotEmpty(testLocation?.daysOfOperation)) {
      todayPeriod = _determineTodayPeriod(
          Map<int, HealthLocationDayOfOperation>.fromIterable(
              testLocation.daysOfOperation, key: (period) => period?.weekDay));
    }

    return todayPeriod?.isOpen ?? false;
  }
}

enum ProviderDropDownItemType{
  provider, all
}

class ProviderDropDownItem{
  final ProviderDropDownItemType type;
  final HealthServiceProvider provider;

  ProviderDropDownItem({ProviderDropDownItemType type, this.provider}) :
    this.type = (type != null) ? type : ((provider != null) ? ProviderDropDownItemType.provider : null);

  bool operator ==(o) =>
      o is ProviderDropDownItem &&
          o.type == type &&
          o.provider?.id == provider?.id;

  int get hashCode =>
      (type?.hashCode ?? 0) ^
      (provider?.hashCode ?? 0);

  String get title {
    if(type == ProviderDropDownItemType.all){
      return Localization().getStringEx("panel.covid19_test_locations.all_providers.text" ,"All Providers");
    } else {
      return provider?.name ?? "";
    }
  }
}