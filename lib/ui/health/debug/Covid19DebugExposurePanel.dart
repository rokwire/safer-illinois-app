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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:illinois/model/Exposure.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Exposure.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class Covid19DebugExposurePanel extends StatefulWidget {

  Covid19DebugExposurePanel();

  @override
  _Covid19DebugExposurePanelState createState() => _Covid19DebugExposurePanelState();
}

class _Covid19DebugExposurePanelState extends State<Covid19DebugExposurePanel> implements NotificationsListener {

  TextEditingController _minDurationSettingController;
  FocusNode             _minDurationSettingFocusNode;

  TextEditingController _minRSSISettingController;
  FocusNode             _minRSSISettingFocusNode;

  List<ExposureTEK> _teks;
  List<ExposureRecord> _exposures;

  bool _poolingTEKs;
  bool _reportingTEKs;
  bool _checkingTEKs;
  bool _checkingExposures;
  String _connection;

  Map<String, dynamic> _startSettings;

  @override
  void initState() {
    NotificationService().subscribe(this, [
      Exposure.notifyStartStop,
      Exposure.notifyTEKsUpdated,
      Exposure.notifyExposureUpdated,
      Exposure.notifyExposureThick,
    ]);
    _startSettings = Map.from(Exposure().startSettings ?? Config().settings);

    //int minDuration = _startSettings['covid19ExposureServiceMinDuration'];
    int minDuration = Exposure().exposureMinDuration;
    _minDurationSettingController = TextEditingController(text: minDuration?.toString() ?? '');
    _minDurationSettingFocusNode = FocusNode();

    int minRssi = _startSettings['covid19ExposureServiceMinRSSI'];
    _minRSSISettingController = TextEditingController(text: minRssi?.toString() ?? '');
    _minRSSISettingFocusNode = FocusNode();

    _loadTEKs();
    _loadExposures();
    
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    
    _minDurationSettingController.dispose();
    _minDurationSettingFocusNode.dispose();
    
    _minRSSISettingController.dispose();
    _minRSSISettingFocusNode.dispose();
    
    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    
    if (name == Exposure.notifyStartStop) {
      _updateConnection(null);
    }
    else if (name == Exposure.notifyTEKsUpdated) {
      _loadTEKs();
    }
    else if (name == Exposure.notifyExposureUpdated) {
      _loadExposures();
    }
    else if (name == Exposure.notifyExposureThick) {
      _updateConnection(param);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text("COVID-19 Exposure", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _buildHeading(),
                    Padding(padding: EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                        _buildTEKs(),
                        Container(height: 32,),
                        _buildExposures(),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildHeading() {
    String status;
    bool canStart, canStop, canEdit;
    if (!Exposure().isEnabled) {
      status = 'disabled';
      canStart = canStop = canEdit = false;
    }
    else  {
      status = Exposure().isStarted ? 'started' : 'stopped';
      canStart = !Exposure().isStarted;
      canStop = Exposure().isStarted;
      canEdit = !Exposure().isStarted;
    }

    return Container(color:Colors.white,
      child: Padding(padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children:<Widget>[
            Row(children: <Widget>[
              Padding(padding: EdgeInsets.only(right: 4), child: Text('Status: ', style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),),
              Text(status, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Color(0xff494949),),),
            ],),

            Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(right: 4), child: Text('Conn: ', style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),),
              Text(_connection ?? '', style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Color(0xff494949),),),
            ],),

            Padding(padding: EdgeInsets.only(top: 8), child:
              Row(children: <Widget>[
                Expanded(child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Padding(padding: EdgeInsets.only(bottom: 4),
                      child: Text("Min RSSI", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: canEdit ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor),),
                    ),
                    TextField(
                      controller: _minRSSISettingController,
                      focusNode: _minRSSISettingFocusNode,
                      enabled: canEdit,
                      decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0)), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: canEdit ? Styles().colors.textBackground : Styles().colors.disabledTextColor,),
                    ),
                  ],),
                ),
                Container(width: 16,),
                Expanded(child:
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
                    Padding(padding: EdgeInsets.only(bottom: 4),
                      child: Text("Min Duration", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: canEdit ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor),),
                    ),
                    TextField(
                      controller: _minDurationSettingController,
                      focusNode: _minDurationSettingFocusNode,
                      enabled: canEdit,
                      decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0)), contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: canEdit ? Styles().colors.textBackground : Styles().colors.disabledTextColor,),
                    ),
                  ],),
                ),
              ]),
            ),

            Padding(padding: EdgeInsets.only(top: 8), child:
              Row(children: <Widget>[
                Expanded(child:
                  RoundedButton(label:"Start",
                    textColor: canStart ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
                    borderColor: canStart ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
                    backgroundColor: Styles().colors.white,
                    fontFamily: Styles().fontFamilies.bold,
                    fontSize: 16, borderWidth: 2, height: 42,
                    onTap:() { _onStart();  }
                  ),
                ),
                Container(width: 16,),
                Expanded(child:
                  RoundedButton(label:"Stop",
                    textColor: canStop ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
                    borderColor: canStop ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
                    backgroundColor: Styles().colors.white,
                    fontFamily: Styles().fontFamilies.bold,
                    fontSize: 16, borderWidth: 2, height: 42,
                    onTap:() { _onStop();  }
                  ),
                )
              ],),
            ),

          ]),
      ),
    );
  }

  Widget _buildTEKs() {

    List<Widget> tekWidgets = <Widget>[];
    if (_teks != null) {
      for (ExposureTEK tek in _teks) {
        String time = AppDateTime.formatDateTime(tek.dateUtc, format: 'MM/dd HH:mm:ss UTC');
        String expiretime = AppDateTime.formatDateTime(tek.expireUtc, format: 'MM/dd HH:mm:ss UTC');
        tekWidgets.add(Row(children: <Widget>[Text("${tek.tek} | start: $time | expire: $expiretime", style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 12, color: Color(0xff494949),),),],),);
      }
    }

    if (tekWidgets.isEmpty) {
      tekWidgets.add(Row(children: <Widget>[],),);
    }

    List<Widget> content = <Widget>[];
    content.add(Text('Local TEKs:', style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),);
    content.add(Container(height: 100, decoration: BoxDecoration(border: Border.all(color: Styles().colors.fillColorPrimary, width: 1)), child:
      Stack(children: <Widget>[
        SingleChildScrollView(child:
          Padding(padding: EdgeInsets.all(4), child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: tekWidgets)
          ),
        ),
        Align(alignment: Alignment.topRight,
          child: Semantics (button: true, label: 'Copy',
            child: GestureDetector(onTap: () { _onCopyTEKs(); },
              child: Container(width: 36, height: 36,
                child: Align(alignment: Alignment.center,
                  child: Semantics( excludeSemantics: true, child: Image.asset('images/icon-copy.png')),
                ),
              ),
            ),
        )),
      ],),
    ));
    
    int teksCount = _teks?.length ?? 0;

    content.add(Padding(padding: EdgeInsets.only(top: 8), child:
      Row(children: <Widget>[
        Expanded(child:
          Stack(children: <Widget>[
            RoundedButton(label: 'Pull',
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorSecondary,
              backgroundColor: Styles().colors.white,
              fontFamily: Styles().fontFamilies.bold,
              fontSize: 16, borderWidth: 2, height: 42,
              onTap:() { _onPullTEKs();  }
            ),
            Visibility(visible: (_poolingTEKs == true), child:
              Center(child:
                Padding(padding: EdgeInsets.only(top: 10.5), child:
                Container(width: 21, height: 21, child:
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                  ),
                ),
              ),
            ),
          ]),
        ),
        Container(width: 8,),
        Expanded(child:
          Stack(children: <Widget>[
            RoundedButton(label: 'Report',
              textColor: (0 < teksCount) ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
              borderColor: (0 < teksCount) ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColor,
              backgroundColor: Styles().colors.white,
              fontFamily: Styles().fontFamilies.bold,
              fontSize: 16, borderWidth: 2, height: 42,
              onTap:() { _onReportTEKs();  }
            ),
            Visibility(visible: (_reportingTEKs == true), child:
              Center(child:
                Padding(padding: EdgeInsets.only(top: 10.5), child:
                Container(width: 21, height: 21, child:
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                  ),
                ),
              ),
            ),
          ]),
        ),
        Container(width: 8,),
        Expanded(child:
          Stack(children: <Widget>[
            RoundedButton(label: 'Check',
              textColor: Styles().colors.fillColorPrimary,
              borderColor: Styles().colors.fillColorSecondary,
              backgroundColor: Styles().colors.white,
              fontFamily: Styles().fontFamilies.bold,
              fontSize: 16, borderWidth: 2, height: 42,
              onTap:() { _onCheckTEKs();  }
            ),
            Visibility(visible: (_checkingTEKs == true), child:
              Center(child:
                Padding(padding: EdgeInsets.only(top: 10.5), child:
                Container(width: 21, height: 21, child:
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],),
    ));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: content);
  }

  
  Widget _buildExposures() {
    List<Widget> content = <Widget>[];

    List<Widget> exposureWidgets = <Widget>[];
    if (_exposures != null) {
      for (ExposureRecord exposure in _exposures) {
        String time = AppDateTime.formatDateTime(exposure.dateUtc, format: 'MM/dd HH:mm:ss UTC');
        exposureWidgets.add(Row(children: <Widget>[Text("RPI: ${exposure.rpi} \nTime: $time | Duration: ${exposure.durationDisplayString}", style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 12, color: Color(0xff494949),),),],),);
      }
    }
    if (exposureWidgets.isEmpty) {
      exposureWidgets.add(Row(children: <Widget>[],),);
    }

    content.add(Text('Recorded Exposures:', style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),);
    content.add(Container(height: 100, decoration: BoxDecoration(border: Border.all(color: Styles().colors.fillColorPrimary, width: 1)), child:
      Stack(children: <Widget>[
        SingleChildScrollView(child:
          Padding(padding: EdgeInsets.all(4), child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: exposureWidgets)
          ),
        ),
        Align(alignment: Alignment.topRight,
          child: Semantics (button: true, label: 'Copy',
            child: GestureDetector(onTap: () { _onCopyExposures(); },
              child: Container(width: 36, height: 36,
                child: Align(alignment: Alignment.center,
                  child: Semantics( excludeSemantics: true, child: Image.asset('images/icon-copy.png')),
                ),
              ),
            ),
        )),
      ],),
    ));

    int exposuresCount = _exposures?.length ?? 0;

    content.add(Padding(padding: EdgeInsets.only(top: 8), child:
      Row(children: <Widget>[
        Expanded(child:
          Stack(children: <Widget>[
            RoundedButton(label: 'Check',
              textColor: (0 < exposuresCount) ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
              borderColor: (0 < exposuresCount) ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColor,
              backgroundColor: Styles().colors.white,
              fontFamily: Styles().fontFamilies.bold,
              fontSize: 16, borderWidth: 2, height: 42,
              onTap:() { _onCheckExposures();  }
            ),
            Visibility(visible: (_checkingExposures == true), child:
              Center(child:
                Padding(padding: EdgeInsets.only(top: 10.5), child:
                Container(width: 21, height: 21, child:
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                  ),
                ),
              ),
            ),
          ]),
        ),
        Container(width: 16,),
        Expanded(child:
          RoundedButton(label: 'Clear',
            textColor: (0 < exposuresCount) ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
            borderColor: (0 < exposuresCount) ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColor,
            backgroundColor: Styles().colors.white,
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16, borderWidth: 2, height: 42,
            onTap:() { _onClearExposures();  }
          ),
        ),
      ],),

    ));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: content);
  }

  void _loadTEKs() {
    Exposure().loadTeks().then((List<ExposureTEK> teks) {
      setState(() {
        _teks = teks;
      });
    });
  }

  void _loadExposures() {
    Exposure().loadLocalExposures(timestamp: Exposure.thresholdTimestamp).then((List<ExposureRecord> exposures) {
      setState(() {
        _exposures = exposures;
      });
    });
  }

  void _updateConnection(Map<dynamic, dynamic> exposure) {

    String rpi = (exposure != null) ? exposure['rpi'] : null;
    int timestamp = (exposure != null) ? exposure['timestamp'] : null;
    int rssi = (exposure != null) ? exposure['rssi'] : null;
    String time = (timestamp != null) ? AppDateTime.formatDateTime(DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true), format: 'MM/dd HH:mm:ss UTC') : null;
    setState(() {
      _connection = Exposure().isStarted ? "RPI: $rpi\nTime: $time | RSSI: $rssi" : '';
    });

  }

  void _onStart() {

    int minDuration = int.tryParse(_minDurationSettingController.text);
    if (minDuration == null) {
      AppAlert.showDialogResult(context, "Please enter an integer minimum duration").then((_) {
        _minDurationSettingFocusNode.requestFocus();
      });
      return;
    }

    int minRssi = int.tryParse(_minRSSISettingController.text);
    if (minRssi == null) {
      AppAlert.showDialogResult(context, "Please enter an integer minimum RSSI value").then((_) {
        _minRSSISettingFocusNode.requestFocus();
      });
      return;
    }

    //_startSettings['covid19ExposureServiceMinDuration'] = minDuration;
    Exposure().exposureMinDuration = minDuration;
    _startSettings['covid19ExposureServiceMinRSSI'] = minRssi;

    Exposure().start(settings: _startSettings);
  }

  void _onStop() {
    Exposure().stop();
  }

  void _onPullTEKs() {
    setState(() {
      _poolingTEKs = true;
    });
    Exposure().loadReportedTEKs(timestamp: Exposure.thresholdTimestamp).then((List<ExposureTEK> result) {
      setState(() {
        _poolingTEKs = false;
      });
      
      String copy = "";
      int copied;
      if (result != null) {
        copied = 0;
        for (ExposureTEK tek in result) {
          String time = AppDateTime.formatDateTime(tek.dateUtc, format: 'MM/dd HH:mm:ss UTC');
          copy += "${tek.tek} | $time\n";
          copied++;
        }
        Clipboard.setData(ClipboardData(text: copy));
      }
      if (copied == null) {
        AppAlert.showDialogResult(context, "Failed to pull reported.");
      } else {
        AppAlert.showDialogResult(context, (0 < copied) ? "$copied entries copied to Clipboard." : "No entries copied to Clipboard.");
      }
    });
  }

  void _onReportTEKs() {
    setState(() {
      _reportingTEKs = true;
    });
    Exposure().reportTEKs(_teks).then((bool result) {
      setState(() {
        _reportingTEKs = false;
      });
      _loadTEKs();
      AppAlert.showDialogResult(context, result ? "Successfully reported" : "Failed to report");
    });
  }

  void _onCheckTEKs() {
    setState(() {
      _checkingTEKs = true;
    });
    Exposure().checkReport().then((int result) {
      setState(() {
        _checkingTEKs = false;
      });
      String message;
      if (result == null) {
        message = 'Failed to report TEKs';
      }
      else if (result == 0) {
        message = "No TEKs reported";
      }
      else {
        message = "$result ${(1 < result) ? 'TEKs' : 'TEK'} reported";
      }
      
      AppAlert.showDialogResult(context, message);
    });
  }

  void _onCopyTEKs() {
    String copy = "";
    int copied = 0;
    if (_teks != null) {
      for (ExposureTEK tek in _teks) {
        String time = AppDateTime.formatDateTime(tek.dateUtc, format: 'MM/dd HH:mm:ss UTC');
        copy += "${tek.tek} | $time\n";
        copied++;
      }
      Clipboard.setData(ClipboardData(text: copy));
    }
    AppAlert.showDialogResult(context, (0 < copied) ? "$copied entries copied to Clipboard" : "No entries copied to Clipboard.");
  }

  void _onCheckExposures() {
    setState(() {
      _checkingExposures = true;
    });
    Exposure().checkExposures().then((int detectedCount) {
      setState(() {
        _checkingExposures = false;
      });
      String message;
      if (detectedCount == null) {
        message = "Failed to check exposures.";
      }
      else if (detectedCount == 0) {
        message = "No exposures detected";
      }
      else {
        message = "Detected $detectedCount ${ (detectedCount != 1) ? 'exposures' : 'exposure' }.";
      }

      AppAlert.showDialogResult(context, message);
    });
  }

  void _onClearExposures() {
    Exposure().clearLocalExposures();
  }

  void _onCopyExposures() {
    String copy = "";
    int copied = 0;
    if (_exposures != null) {
      for (ExposureRecord exposure in _exposures) {
        String time = AppDateTime.formatDateTime(exposure.dateUtc, format: 'MM/dd HH:mm:ss UTC');
        copy += "${exposure.rpi} | Time: $time | Duration: ${exposure.durationDisplayString}\n";
        copied++;
      }
      Clipboard.setData(ClipboardData(text: copy));
    }
    AppAlert.showDialogResult(context, (0 < copied) ? "$copied entries copied to Clipboard" : "No entries copied to Clipboard.");
  }
}
