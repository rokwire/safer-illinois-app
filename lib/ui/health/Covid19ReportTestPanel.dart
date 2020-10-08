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
import 'dart:convert';
import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/PopupDialog.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class Covid19ReportTestPanel extends StatefulWidget {
  final HealthServiceProvider provider;
  Covid19ReportTestPanel({this.provider});

  @override
  _Covid19ReportTestPanelSate createState() => _Covid19ReportTestPanelSate();
}

class _Covid19ReportTestPanelSate extends State<Covid19ReportTestPanel>{

  int _loadingProgress = 0;

  File _testPhoto;

  LinkedHashMap<String,HealthServiceLocation> _locations;
  List<TestDropDownItem>_types;
  LinkedHashMap<String,HealthTestTypeResult> _results;

  DateTime _selectedDate;
  String _selectedLocationId;
  TestDropDownItem _selectedTestType;
  String _selectedResultId;
  //String _imageUrl;

  @override
  void initState() {
    DateTime now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    if(_isCustomProvider) {
      _loadTestTypes();
    } else {
      _loadLocations();
    }
    super.initState();
  }

  void _loadLocations(){
    _increaseProgress();
    Health().loadHealthServiceLocations(countyId: Health().currentCountyId, providerId: widget.provider?.id).then((List<HealthServiceLocation> locations){
      setState(() {
        try {
          _locations = locations != null ? Map<String, HealthServiceLocation>.fromIterable(locations, key: ((location) => location.id)) : null;
        } catch(e){
          print(e);
        }
        _decreaseProgress();
      });
    });
  }

  void _loadTestTypes(){
    _increaseProgress();
    List<String> typesIds = _selectedLocationId!=null? _locations[_selectedLocationId]?.availableTests: null;
    Health().loadHealthServiceTestTypes(typeIds: typesIds).then((List<HealthTestType> types){
      setState(() {
        _decreaseProgress();
        try{
          _types = List<TestDropDownItem>();
          if(types?.isNotEmpty?? false) {
            _types.addAll(types?.map((HealthTestType type) {
              TestDropDownItem item = TestDropDownItem(type: TestDropDownItemType.provider, item: type);

              return item;
            })?.toList());
          }
          _types.add(TestDropDownItem(type: TestDropDownItemType.other, item: null));
        } catch(e){
          print(e);
        }
      });
    });
  }

  void _loadTestResults(){
    List<HealthTestTypeResult> results = _selectedTestType?.item?.results;
    setState(() {
      _results = results!=null?Map<String,HealthTestTypeResult>.fromIterable(results,key:((result)=>result.id)): null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.health.report_test.heading.title","Manually Enter Result"), style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: _isLoading? _buildLoading() : _buildContent()
            ),
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildContent(){
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 26,),
          _buildProviderField(),
          _buildDateField(),
          _buildLocationField(),
          _buildTypeField(),
          _buildResultField(),
          _buildAddImageField(),
          _buildAddTestButton()
        ],
      ),
    );
  }

  Widget _buildLoading(){
    return
        Center(child:
          Padding(padding: EdgeInsets.only(top: 10.5), child:
            Container(width: 21, height:21, child:
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
    ),),);
  }

  Widget _buildDateField(){
    String dateText = _selectedDate != null ? AppDateTime.formatDateTime(_selectedDate, format: 'MM/dd/yyyy h:mm a') : "";

    return Semantics(container: true, child:
    Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        _fieldTitle(Localization().getStringEx("panel.health.report_test.label.date","TEST DATE AND TIME")),
        Container(height: 8,),
        GestureDetector(
          onTap: _onTapPickTime,
          child: Container(
//            height: 48,
//            width: 142,
            decoration: BoxDecoration(
                border: Border.all(color: Styles().colors.surfaceAccent, width: 1),
                borderRadius: BorderRadius.all(Radius.circular(4))),
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Expanded(child:
                  Text(
                    AppString.getDefaultEmptyString(value: dateText, defaultValue: ''),
                    style: TextStyle(
                        color: Styles().colors.fillColorPrimary,
                        fontSize: 16,
                        fontFamily: Styles().fontFamilies.medium),
                  ),
                ),
                Image.asset('images/icon-down-orange.png')
              ],
            ),
          ),
        ),
        Container(height: 26,)
      ],),
    ));
  }

  Widget _buildProviderField(){
    return Semantics(container: true, child:
      Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        _fieldTitle(Localization().getStringEx("panel.health.report_test.label.provider","HEALTHCARE PROVIDER")),
        Container(height: 8,),
        _fieldTitle(widget?.provider?.name?? Localization().getStringEx("app.common.label.other", "Other")),
          Container(height: 26,)
      ],),
    ));
  }

  Widget _buildLocationField(){
    return _showLocationField?
    Semantics(container: true, child:
      Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        _fieldTitle(Localization().getStringEx("panel.health.report_test.label.date.location","TEST LOCATION")),
        Container(height: 8,),
          _dropDownMenu(Localization().getStringEx("panel.health.report_test.label.location.empty","Select location…"), _locations!=null?_locations[_selectedLocationId] : null, _locations?.values,
                  getLabel: (HealthServiceLocation selectedValue) => selectedValue?.name ?? "unknown",
                  onChanged:(HealthServiceLocation selectedValue) {
                    _selectedLocationId = selectedValue.id;
                    _loadTestTypes();
                  }),
        Container(height: 26,)
      ],),
    )) :
      Container();
  }

  Widget _buildTypeField(){
    return Semantics(container: true, child:
      Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        _fieldTitle(Localization().getStringEx("panel.health.report_test.label.type","TEST TYPE")),
        Container(height: 8,),
          _dropDownMenu("Select test type…", _selectedTestType, _types, /*enabled: _selectedLocationId!=null,*/
              getLabel: (TestDropDownItem selectedValue) => selectedValue.title,
              onChanged:(TestDropDownItem selectedValue) {
                _selectedTestType = selectedValue;
                _loadTestResults();
              }),
        Container(height: 26,)
      ],),
    ));
  }

  Widget _buildResultField(){
    return _showResultField? Semantics(container: true, child:
      Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        _fieldTitle(Localization().getStringEx("panel.health.report_test.label.result","RESULT")),
        Container(height: 8,),
          _dropDownMenu(Localization().getStringEx("panel.health.report_test.label.result.empty","Select test result…"),_results!=null ? _results[_selectedResultId]: null, _results?.values, /*enabled: _selectedTypeId!=null,*/
              getLabel: (HealthTestTypeResult selectedValue) => selectedValue.name,
              onChanged:(HealthTestTypeResult selectedValue) => _selectedResultId = selectedValue.id),
        Container(height: 26,)
      ],),
    )) :
      Container();
  }

  Widget _buildAddImageField(){
    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        _fieldTitle(Localization().getStringEx("panel.health.report_test.label.image","ADD TEST RESULT")),
        Container(height: 2,),
        Text(Localization().getStringEx("panel.health.report_test.label.image.hint","Upload an image of your test result."),
          style: TextStyle(color: Styles().colors.textBackground, fontSize: 16, fontFamily: Styles().fontFamilies.regular,),),
        Container(height: 11,),
        InkWell(
            onTap: _testPhoto!=null? _onTapViewImage : _onTapUploadImage,
            child: DottedBorder(
                color: Styles().colors.mediumGray2, padding: EdgeInsets.all(0), strokeWidth: 3,dashPattern: [4, 4],
                child: Container(height: 85,
                  decoration: BoxDecoration(
                    color: Styles().colors.lightGray,
                    image: _testPhoto != null ? DecorationImage(image: FileImage(_testPhoto,)) : null,
                  ),
                  alignment:  Alignment.center,
                  child: Row(children: <Widget>[
                    Expanded(child:Container()),

                    _testPhoto!=null?Container():
                    Text(Localization().getStringEx("panel.health.report_test.button.add_image.title","Upload Image"),
                      style: TextStyle(color: Styles().colors.fillColorPrimaryVariant, fontSize: 16, fontFamily: Styles().fontFamilies.bold,),),
                    Container(width: 8,),
                    _testPhoto!=null?Container():
                    Image.asset("images/icon-plus.png", excludeFromSemantics: true,),
                    Expanded(child:Container()),
                  ],
                  ),
        )   )   )
      ],),
    );
  }

  //Buttons
  Widget _buildAddTestButton() {
    return
      Stack(children: <Widget>[
        Container(
          padding: EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: ScalableRoundedButton(
              label: Localization().getStringEx("panel.health.report_test.button.add_test.title", "Add Test"),
              backgroundColor: Colors.white,
              borderColor: Styles().colors.fillColorSecondary,
              textColor: Styles().colors.fillColorPrimary,
              onTap: _onTapAddTest,
//              height: 48,
            ),
          )
          ,),
        Visibility(visible: _isLoading,
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 26),
            height: 48,
            child: Align(alignment: Alignment.center,
              child: SizedBox(height: 24, width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), )
              ),
            ),
          ),
        ),
      ],);
  }

  Widget _fieldTitle(String title){
    return Container(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold,letterSpacing: 0.86),
      ),
    );
  }

  //Dtopdown

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
                    'images/icon-down-orange.png') : Container(),
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

  void _onTapPickTime() async{
    //This always returns 00:00 as Time
    DateTime date = await _pickDate(_selectedDate);

    if(date!=null){
      TimeOfDay time = await showTimePicker(context: context, initialTime: new TimeOfDay(hour: _selectedDate?.hour??date.hour, minute: _selectedDate?.minute??date.minute),
        builder: (BuildContext context, Widget child) {
          return MediaQuery( //Show in 12 hour format (depending on locale)
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: false),
            child: child,
          );
        }
      );
      if (time != null){
        DateTime accurateDate = DateTime(date.year, date.month, date.day,time.hour,time.minute);
        _selectedDate = accurateDate;
      } else {
        //Canceled time selection so use the previously selected hours
        DateTime previuslySelectedTime= DateTime(date.year, date.month, date.day,_selectedDate?.hour??date.hour,_selectedDate.minute?? time.minute);
        _selectedDate = previuslySelectedTime;
      }
    }

    setState(() {});
  }

  void _onTapViewImage() async {
    Analytics.instance.logSelect(target: "View Image");
    await showDialog(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child:
          Container(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                Container(
                  color: Styles().colors.background,
                  padding: EdgeInsets.symmetric(vertical: 0),
                  child: Image.file(_testPhoto),),
                Container(color: Styles().colors.background,height: 4,),
                Container(
                  color: Styles().colors.background,
                  child: Row(children: <Widget>[
                    Container(width: 4,),
                    Expanded(child:
                      RoundedButton(
                        label: Localization().getStringEx("panel.health.report_test.button.close.title","Close"),
                        onTap: _onTapCloseView,
                        backgroundColor: Styles().colors.background,
                        borderColor: Styles().colors.fillColorSecondary,
                        textColor: Styles().colors.fillColorPrimary,),
                    ),
                    Container(width: 8,),
                    Expanded(child:
                      RoundedButton(
                        label: Localization().getStringEx("panel.health.report_test.button.retake.title","Retake"),
                        onTap: _onTapRetake,
                        backgroundColor: Styles().colors.background,
                        borderColor: Styles().colors.fillColorSecondary,
                        textColor: Styles().colors.fillColorPrimary,
                      )),
                    Container(width: 4,),
                ],)),
                Container(color: Styles().colors.background,height: 4,)
          ],)
    )));
  }

  void _onTapRetake(){
    Analytics.instance.logSelect(target: "Retake");
    Navigator.pop(context);
    _onTapUploadImage();
  }
  void _onTapCloseView(){
    Analytics.instance.logSelect(target: "Close");
    Navigator.pop(context);
  }

  void _onTapUploadImage() async {
    showCupertinoModalPopup(context: context, builder: (context){
      Analytics.instance.logSelect(target: "Uppload Image");
      return CupertinoActionSheet(
        title: Text(Localization().getStringEx("panel.health.report_test.label.select_photo","Select photo")),
        message: Text(Localization().getStringEx("panel.health.report_test.label.select_photo.description","Please take a photo of the test result or select it from the gallery")),
        actions: <Widget>[
          CupertinoActionSheetAction(
            child: Text(Localization().getStringEx("panel.health.report_test.button.take_photo","Take photo"), style: TextStyle(color: Styles().colors.fillColorSecondary),),
            onPressed: _onTapUseCamera,
          ),
          CupertinoActionSheetAction(
            child: Text(Localization().getStringEx("panel.health.report_test.button.select_gallery","Select from gallery"), style: TextStyle(color: Styles().colors.fillColorSecondary),),
            onPressed: _onTapSelectFromGallery,
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDefaultAction: true,
          child: Text(Localization().getStringEx("panel.health.report_test.button.cancel","Cancel"), style: TextStyle(color: Styles().colors.fillColorSecondary),),
          onPressed: () { Navigator.pop(context); },
        ),
      );
    });

    /*_imageUrl = await showDialog(
        context: context,
        builder: (_) => Material(
          type: MaterialType.transparency,
          child: AddImageWidget(),
        )
    );*/
  }

  void _onTapSelectFromGallery(){
    Analytics.instance.logSelect(target: "Select Forom Gallery");
    Navigator.pop(context);
    ImagePicker().getImage(source: ImageSource.gallery).then((PickedFile pickedFile){
      setState(() {_testPhoto = File(pickedFile.path);});
    });
  }

  void _onTapUseCamera(){
    Analytics.instance.logSelect(target: "Use Camera");
    Navigator.pop(context);
    ImagePicker().getImage(source: ImageSource.camera).then((PickedFile pickedFile){
      setState(() {_testPhoto = File(pickedFile.path);});
    });
  }

  void _onTapAddTest() async{
    Analytics.instance.logSelect(target: "Add Test");

    if(!_validate()){
      return;
    }
    _increaseProgress();

    File resizedImage = await resizeImage(_testPhoto);

    String imageBase64;
    try{
      List<int> photoBytes = resizedImage!=null? resizedImage.readAsBytesSync() : _testPhoto.readAsBytesSync();
      imageBase64 = base64Encode(photoBytes);
    }catch(e){

    }

    HealthServiceProvider provider = widget.provider;
    HealthServiceLocation location = _locations!=null ? _locations[_selectedLocationId] : null;
    HealthTestType testType = _selectedTestType?.item;
    HealthTestTypeResult testResult = _results!=null ? _results[_selectedResultId]: null;

    DateTime dateUtc = _selectedDate.toUtc();

    // Ensure county if provider is 'Other'
    String countyId;
    if (_isCustomProvider) {
      countyId = Storage().currentHealthCountyId;
      if (AppString.isStringEmpty(countyId)) {
        List<HealthCounty> counties = await Health().loadCounties();
        countyId = HealthCounty.defaultCounty(counties)?.id;
      }
    }

    Covid19ManualTest test = Covid19ManualTest(
      provider:   _isCustomProvider? null: provider?.name,
      providerId: _isCustomProvider? null: provider?.id,
      location:   _isCustomProvider? null: location?.name,
      locationId: _isCustomProvider? null: location?.id,
      countyId:   countyId,
      testType:   testType?.name,
      testResult: testResult?.name,
      dateUtc:    dateUtc,
      image:      imageBase64,
    );

    Health().processManualTest(test).then((success){
      _decreaseProgress();
      if(success)
        Navigator.pop(context,"success");
      else
        AppToast.show(Localization().getStringEx("panel.health.report_test.error.create.message","Unable to create test"));
    });
  }

  bool _validate(){
    if(_testPhoto==null){
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopupDialog(displayText: Localization().getStringEx("panel.health.report_test.missing.image.message","Please upload image"), positiveButtonText: Localization().getStringEx("dialog.ok.title","OK"));
        },
      );
      return false;
    } else if(_selectedDate?.isAfter(DateTime.now())?? false ){
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return PopupDialog(displayText: Localization().getStringEx("panel.health.report_test.future_date.forbidden.message","You cannot submit a test in the future"), positiveButtonText: Localization().getStringEx("dialog.ok.title","OK"));
        },
      );
      return false;
    }

    return true;
  }

  //Utils
  Future<DateTime> _pickDate(DateTime date) async {
    Analytics.instance.logSelect(target: "Pick Date");
    DateTime now = DateTime.now();
    DateTime firstDate = now.subtract(new Duration(days: 30));
    date = date ?? now;
    DateTime initialDate = date;
    if (firstDate.isAfter(date)) {
      firstDate = initialDate; //Fix exception
    }

    DateTime result = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: now,
      builder: (BuildContext context, Widget child) {
        return Theme(
          data: ThemeData.light(),
          child: child,
        );
      },
    );

    return result;
  }
  
  bool get _isCustomProvider {
    return widget?.provider==null;
  }

  bool get _showLocationField{
    return !_isCustomProvider; // is not "Other"
  }

  bool get _showResultField{
    return _selectedTestType?.type != TestDropDownItemType.other;
  }

  void _increaseProgress() {
    setState(() {
      _loadingProgress++;
    });
  }

  void _decreaseProgress() {
    setState(() {
      _loadingProgress--;
    });
  }

  bool get _isLoading {
    return (_loadingProgress > 0);
  }

  Future<File> resizeImage(File image) async{
    final int requiredBytesSize = 300000; //300k

    if(image == null) return image;
    final Directory path = await getApplicationDocumentsDirectory();
    String directoryPath = path?.path;
    String imagePath = directoryPath+"/upload_image.jpg";
    int originalSize = image.lengthSync();

    if(originalSize<=requiredBytesSize)
      return image;

    double reducedCoefficient = (originalSize / requiredBytesSize); //Percentage difference
    double reducedQuality = 100 - reducedCoefficient; //reduces the bytes size of 1 pixel // 80 - give us 20 times smaller, 60 give us 40 times smaller
    File result;
    try {
      result = await FlutterImageCompress.compressAndGetFile(
      image.absolute.path, imagePath,
      quality: reducedQuality?.toInt() ?? 90,
      minHeight: 1280,
      minWidth: 720
      );
    } catch(e){
      print(e);
    }
    print("Original Size: "+ image.lengthSync().toString());
    print("Resized Size: "+ result?.lengthSync()?.toString());
    print("Quality "+ reducedQuality?.toString());

    return result;
  }
}

enum TestDropDownItemType{
  provider, other
}

class TestDropDownItem{
  final TestDropDownItemType type;
  final HealthTestType item;

  TestDropDownItem({this.type, this.item});

  String get title{
    if(type == TestDropDownItemType.other){
      return Localization().getStringEx("app.common.label.other", "Other");
    } else {
      return item?.name ?? "";
    }
  }

  String get id{
    if(type == TestDropDownItemType.other){
      return null;
    } else {
      return item?.id;
    }
  }
}