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
import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:http/http.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:illinois/model/Exposure.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Exposure.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class Covid19DebugExposureLogsPanel extends StatefulWidget {
  Covid19DebugExposureLogsPanel();

  @override
  _Covid19DebugExposureLogsPanelState createState() =>
      _Covid19DebugExposureLogsPanelState();
}

class _Covid19DebugExposureLogsPanelState extends State<Covid19DebugExposureLogsPanel>
    implements NotificationsListener {
  TextEditingController _minDurationSettingController;
  FocusNode _minDurationSettingFocusNode;

  TextEditingController _minRSSISettingController;
  FocusNode _minRSSISettingFocusNode;

  List<ExposureTEK> _teks;
  List<ExposureRecord> _exposures;

  bool _poolingTEKs;
  bool _reportingTEKs;
  bool _checkingTEKs;
  bool _checkingExposures;
  String _connection;

  // testing framework variables
  static const String Url =
      "http://ec2-18-191-37-235.us-east-2.compute.amazonaws.com:8003/";
  static const String QueryUrl =
      "http://ec2-18-191-37-235.us-east-2.compute.amazonaws.com:8003/SessionReport?";
  TextEditingController _sessionIDTextController;
  TextEditingController _additionalDetailTextController;
  TextEditingController _querySessionTextController;
  TextEditingController _queryDeviceIndexTextController;
  //String _currentTestingSessionID = "";
  bool _processingSessionID = false; // circling animation and on tap event
  bool _isInSession =
      false; // first row button color, onTap event and endSession button
  String _executionStatus = "None";
  int _currentSession;
  bool _isAndroid;
  String _deviceID;
  String _thisDeviceIndex; // always shown as this device Index

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
    _minDurationSettingController =
        TextEditingController(text: minDuration?.toString() ?? '');
    _minDurationSettingFocusNode = FocusNode();

    int minRssi = _startSettings['covid19ExposureServiceMinRSSI'];
    _minRSSISettingController =
        TextEditingController(text: minRssi?.toString() ?? '');
    _minRSSISettingFocusNode = FocusNode();

    _sessionIDTextController = TextEditingController();
    _additionalDetailTextController = TextEditingController();
    _querySessionTextController = TextEditingController();
    _queryDeviceIndexTextController = TextEditingController();

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

    // testing Framework: dispose text controller
    _sessionIDTextController.dispose();
    _additionalDetailTextController.dispose();
    _querySessionTextController.dispose();
    _queryDeviceIndexTextController.dispose();

    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Exposure.notifyStartStop) {
      _updateConnection(null);
    } else if (name == Exposure.notifyTEKsUpdated) {
      _loadTEKs();
    } else if (name == Exposure.notifyExposureUpdated) {
      _loadExposures();
    } else if (name == Exposure.notifyExposureThick) {
      _updateConnection(param);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          "COVID-19 Exposure Logs",
          style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeading(),
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          _buildTEKs(),
                          Container(
                            height: 32,
                          ),
                          _buildExposures(),
                          Container(
                            height: 32,
                          ),
                          _buildTesting(),
                        ]),
                  ),
                ],
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
    } else {
      status = Exposure().isStarted ? 'started' : 'stopped';
      canStart = !Exposure().isStarted;
      canStop = Exposure().isStarted;
      canEdit = !Exposure().isStarted;
    }

    return Container(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <
            Widget>[
          Row(
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  'Status: ',
                  style: TextStyle(
                      fontFamily: Styles().fontFamilies.bold,
                      fontSize: 16,
                      color: Styles().colors.fillColorPrimary),
                ),
              ),
              Text(
                status,
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.regular,
                  fontSize: 16,
                  color: Color(0xff494949),
                ),
              ),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text(
                  'Conn: ',
                  style: TextStyle(
                      fontFamily: Styles().fontFamilies.bold,
                      fontSize: 16,
                      color: Styles().colors.fillColorPrimary),
                ),
              ),
              Text(
                _connection ?? '',
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.regular,
                  fontSize: 16,
                  color: Color(0xff494949),
                ),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        "Min RSSI",
                        style: TextStyle(
                            fontFamily: Styles().fontFamilies.bold,
                            fontSize: 12,
                            color: canEdit
                                ? Styles().colors.fillColorPrimary
                                : Styles().colors.disabledTextColor),
                      ),
                    ),
                    TextField(
                      controller: _minRSSISettingController,
                      focusNode: _minRSSISettingFocusNode,
                      enabled: canEdit,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 1.0)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      style: TextStyle(
                        fontFamily: Styles().fontFamilies.regular,
                        fontSize: 16,
                        color: canEdit
                            ? Styles().colors.textBackground
                            : Styles().colors.disabledTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 16,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Text(
                        "Min Duration",
                        style: TextStyle(
                            fontFamily: Styles().fontFamilies.bold,
                            fontSize: 12,
                            color: canEdit
                                ? Styles().colors.fillColorPrimary
                                : Styles().colors.disabledTextColor),
                      ),
                    ),
                    TextField(
                      controller: _minDurationSettingController,
                      focusNode: _minDurationSettingFocusNode,
                      enabled: canEdit,
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderSide:
                                  BorderSide(color: Colors.black, width: 1.0)),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                      style: TextStyle(
                        fontFamily: Styles().fontFamilies.regular,
                        fontSize: 16,
                        color: canEdit
                            ? Styles().colors.textBackground
                            : Styles().colors.disabledTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
          Padding(
            padding: EdgeInsets.only(top: 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: RoundedButton(
                      label: "Start",
                      textColor: canStart
                          ? Styles().colors.fillColorPrimary
                          : Styles().colors.disabledTextColor,
                      borderColor: canStart
                          ? Styles().colors.fillColorSecondary
                          : Styles().colors.disabledTextColorTwo,
                      backgroundColor: Styles().colors.white,
                      fontFamily: Styles().fontFamilies.bold,
                      fontSize: 16,
                      borderWidth: 2,
                      height: 42,
                      onTap: () {
                        _onStart();
                      }),
                ),
                Container(
                  width: 16,
                ),
                Expanded(
                  child: RoundedButton(
                      label: "Stop",
                      textColor: canStop
                          ? Styles().colors.fillColorPrimary
                          : Styles().colors.disabledTextColor,
                      borderColor: canStop
                          ? Styles().colors.fillColorSecondary
                          : Styles().colors.disabledTextColorTwo,
                      backgroundColor: Styles().colors.white,
                      fontFamily: Styles().fontFamilies.bold,
                      fontSize: 16,
                      borderWidth: 2,
                      height: 42,
                      onTap: () {
                        _onStop();
                      }),
                )
              ],
            ),
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
        tekWidgets.add(
          Row(
            children: <Widget>[
              Text(
                "${tek.tek} | start: $time | expire: $expiretime",
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.regular,
                  fontSize: 12,
                  color: Color(0xff494949),
                ),
              ),
            ],
          ),
        );
      }
    }

    if (tekWidgets.isEmpty) {
      tekWidgets.add(
        Row(
          children: <Widget>[],
        ),
      );
    }

    List<Widget> content = <Widget>[];
    content.add(
      Text(
        'Local TEKs:',
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );
    content.add(Container(
      height: 100,
      decoration: BoxDecoration(
          border:
              Border.all(color: Styles().colors.fillColorPrimary, width: 1)),
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: tekWidgets)),
          ),
          Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: 'Copy',
                child: GestureDetector(
                  onTap: () {
                    _onCopyTEKs();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    child: Align(
                      alignment: Alignment.center,
                      child: Semantics(
                          excludeSemantics: true,
                          child: Image.asset('images/icon-copy.png')),
                    ),
                  ),
                ),
              )),
        ],
      ),
    ));

    int teksCount = _teks?.length ?? 0;

    content.add(Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Pull',
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  borderWidth: 2,
                  height: 42,
                  onTap: () {
                    _onPullTEKs();
                  }),
              Visibility(
                visible: (_poolingTEKs == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            width: 8,
          ),
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Report',
                  textColor: (0 < teksCount)
                      ? Styles().colors.fillColorPrimary
                      : Styles().colors.disabledTextColor,
                  borderColor: (0 < teksCount)
                      ? Styles().colors.fillColorSecondary
                      : Styles().colors.disabledTextColor,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  borderWidth: 2,
                  height: 42,
                  onTap: () {
                    _onReportTEKs();
                  }),
              Visibility(
                visible: (_reportingTEKs == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            width: 8,
          ),
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Check',
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  borderWidth: 2,
                  height: 42,
                  onTap: () {
                    _onCheckTEKs();
                  }),
              Visibility(
                visible: (_checkingTEKs == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
        ],
      ),
    ));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: content);
  }

  Widget _buildExposures() {
    List<Widget> content = <Widget>[];

    List<Widget> exposureWidgets = <Widget>[];
    if (_exposures != null) {
      for (ExposureRecord exposure in _exposures) {
        String time = AppDateTime.formatDateTime(exposure.dateUtc, format: 'MM/dd HH:mm:ss UTC');
        exposureWidgets.add(
          Row(
            children: <Widget>[
              Text(
                "RPI: ${exposure.rpi} \nTime: $time | Duration: ${exposure.durationDisplayString}",
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.regular,
                  fontSize: 12,
                  color: Color(0xff494949),
                ),
              ),
            ],
          ),
        );
      }
    }
    if (exposureWidgets.isEmpty) {
      exposureWidgets.add(
        Row(
          children: <Widget>[],
        ),
      );
    }

    content.add(
      Text(
        'Recorded Exposures:',
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );
    content.add(Container(
      height: 100,
      decoration: BoxDecoration(
          border:
              Border.all(color: Styles().colors.fillColorPrimary, width: 1)),
      child: Stack(
        children: <Widget>[
          SingleChildScrollView(
            child: Padding(
                padding: EdgeInsets.all(4),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: exposureWidgets)),
          ),
          Align(
              alignment: Alignment.topRight,
              child: Semantics(
                button: true,
                label: 'Copy',
                child: GestureDetector(
                  onTap: () {
                    _onCopyExposures();
                  },
                  child: Container(
                    width: 36,
                    height: 36,
                    child: Align(
                      alignment: Alignment.center,
                      child: Semantics(
                          excludeSemantics: true,
                          child: Image.asset('images/icon-copy.png')),
                    ),
                  ),
                ),
              )),
        ],
      ),
    ));

    int exposuresCount = _exposures?.length ?? 0;

    content.add(Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Check',
                  textColor: (0 < exposuresCount)
                      ? Styles().colors.fillColorPrimary
                      : Styles().colors.disabledTextColor,
                  borderColor: (0 < exposuresCount)
                      ? Styles().colors.fillColorSecondary
                      : Styles().colors.disabledTextColor,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16,
                  borderWidth: 2,
                  height: 42,
                  onTap: () {
                    _onCheckExposures();
                  }),
              Visibility(
                visible: (_checkingExposures == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            width: 16,
          ),
          Expanded(
            child: RoundedButton(
                label: 'Clear',
                textColor: (0 < exposuresCount)
                    ? Styles().colors.fillColorPrimary
                    : Styles().colors.disabledTextColor,
                borderColor: (0 < exposuresCount)
                    ? Styles().colors.fillColorSecondary
                    : Styles().colors.disabledTextColor,
                backgroundColor: Styles().colors.white,
                fontFamily: Styles().fontFamilies.bold,
                fontSize: 16,
                borderWidth: 2,
                height: 42,
                onTap: () {
                  _onClearExposures();
                }),
          ),
        ],
      ),
    ));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: content);
  }

  void _loadTEKs() {
    Exposure().loadTeks().then((List<ExposureTEK> teks) {
      setState(() {
        _teks = teks;
      });
    });
  }

  void _loadExposures() {
    Exposure()
        .loadLocalExposures(timestamp: Exposure.thresholdTimestamp)
        .then((List<ExposureRecord> exposures) {
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
      _connection =
          Exposure().isStarted ? "RPI: $rpi\nTime: $time | RSSI: $rssi" : '';
    });
  }

  void _onStart() {
    int minDuration = int.tryParse(_minDurationSettingController.text);
    if (minDuration == null) {
      AppAlert.showDialogResult(
              context, "Please enter an integer minimum duration")
          .then((_) {
        _minDurationSettingFocusNode.requestFocus();
      });
      return;
    }

    int minRssi = int.tryParse(_minRSSISettingController.text);
    if (minRssi == null) {
      AppAlert.showDialogResult(
              context, "Please enter an integer minimum RSSI value")
          .then((_) {
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
    Exposure()
        .loadReportedTEKs(timestamp: Exposure.thresholdTimestamp)
        .then((List<ExposureTEK> result) {
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
        AppAlert.showDialogResult(
            context,
            (0 < copied)
                ? "$copied entries copied to Clipboard."
                : "No entries copied to Clipboard.");
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
      AppAlert.showDialogResult(
          context, result ? "Successfully reported" : "Failed to report");
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
      } else if (result == 0) {
        message = "No TEKs reported";
      } else {
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
    AppAlert.showDialogResult(
        context,
        (0 < copied)
            ? "$copied entries copied to Clipboard"
            : "No entries copied to Clipboard.");
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
      } else if (detectedCount == 0) {
        message = "No exposures detected";
      } else {
        message =
            "Detected $detectedCount ${(detectedCount != 1) ? 'exposures' : 'exposure'}.";
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
        copy +=
            "${exposure.rpi} | Time: $time | Duration: ${exposure.durationDisplayString}\n";
        copied++;
      }
      Clipboard.setData(ClipboardData(text: copy));
    }
    AppAlert.showDialogResult(
        context,
        (0 < copied)
            ? "$copied entries copied to Clipboard"
            : "No entries copied to Clipboard.");
  }

// testing related widget builder and functions
  Widget _buildTesting() {
    List<Widget> content = <Widget>[];

    content.add(
      Text(
        'Available Session ID:',
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );
    content.add(Container(
      height: 50,
      child: TextField(
        controller: _sessionIDTextController,
        // keyboardType: TextInputType.multiline,
        // maxLines: null,
        maxLines: 1,
        enabled: _isInSession == false, // can not change once in session
        decoration: new InputDecoration.collapsed(
            hintText: 'press Get Session ID or Type here'),
      ),
    ));

    // buttons
    content.add(Padding(
      padding: EdgeInsets.only(top: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Get Session ID',
                  backgroundColor: Styles().colors.white,
                  textColor: (_isInSession != true)
                      ? Styles().colors.fillColorPrimary
                      : Styles().colors.disabledTextColor,
                  borderColor: (_isInSession != true)
                      ? Styles().colors.fillColorSecondary
                      : Styles().colors.disabledTextColor,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 10,
                  borderWidth: 2,
                  height: 42,
                  onTap: _isInSession
                      ? null
                      : () {
                          _onSessionGet();
                        }),
              Visibility(
                visible: (_processingSessionID == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            width: 16,
          ),
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Create Session',
                  backgroundColor: Styles().colors.white,
                  textColor: (_isInSession != true)
                      ? Styles().colors.fillColorPrimary
                      : Styles().colors.disabledTextColor,
                  borderColor: (_isInSession != true)
                      ? Styles().colors.fillColorSecondary
                      : Styles().colors.disabledTextColor,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 10,
                  borderWidth: 2,
                  height: 42,
                  onTap: _isInSession
                      ? null
                      : () {
                          _onSessionCreate();
                        }),
              Visibility(
                visible: (_processingSessionID == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            width: 16,
          ),
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'Join Session',
                  backgroundColor: Styles().colors.white,
                  textColor: (_isInSession != true)
                      ? Styles().colors.fillColorPrimary
                      : Styles().colors.disabledTextColor,
                  borderColor: (_isInSession != true)
                      ? Styles().colors.fillColorSecondary
                      : Styles().colors.disabledTextColor,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 10,
                  borderWidth: 2,
                  height: 42,
                  onTap: _isInSession
                      ? null
                      : () {
                          _onSessionJoin();
                        }),
              Visibility(
                visible: (_processingSessionID == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
          Container(
            width: 16,
          ),
        ],
      ),
    ));

    content.add(
      Text(
        'Execution Status: $_executionStatus',
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );
    content.add(Container(
      height: 32,
    ));
    // add additional text input field
    content.add(
      Text(
        "additional details",
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );
    content.add(Container(
      height: 100,
      child: TextField(
        controller: _additionalDetailTextController,
        keyboardType: TextInputType.multiline,
        textInputAction: TextInputAction.done,
        maxLines: null,
        // onSubmitted: (String value) async {
        //   await showDialog<void>(
        //     context: context,
        //     builder: (BuildContext context) {
        //       return AlertDialog(
        //         title: const Text('Thanks!'),
        //         content: Text('You typed "$value".'),
        //         actions: <Widget>[
        //           FlatButton(
        //             onPressed: () {
        //               Navigator.pop(context);
        //             },
        //             child: const Text('OK'),
        //           ),
        //         ],
        //       );
        //     },
        //   );
        // },
        decoration: new InputDecoration.collapsed(
            hintText: 'add additional detail before ending session'),
      ),
    ));

    content.add(Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(children: <Widget>[
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                  label: 'End Session',
                  backgroundColor: Styles().colors.white,
                  textColor: (_isInSession == true)
                      ? Styles().colors.fillColorPrimary
                      : Styles().colors.disabledTextColor,
                  borderColor: (_isInSession == true)
                      ? Styles().colors.fillColorSecondary
                      : Styles().colors.disabledTextColor,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 10,
                  borderWidth: 2,
                  height: 42,
                  onTap: _isInSession
                      ? () {
                          _onEndSession();
                        }
                      : null),
              Visibility(
                visible: (_processingSessionID == true),
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.5),
                    child: Container(
                        width: 21,
                        height: 21,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                              Styles().colors.fillColorSecondary),
                          strokeWidth: 2,
                        )),
                  ),
                ),
              ),
            ]),
          ),
        ])));

    content.add(
      Container(
        height: 70,
      ),
    );

    content.add(
      Text(
        'Query Session ID: ',
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );

    content.add(Container(
      height: 50,
      child: TextField(
        controller: _querySessionTextController,
        // keyboardType: TextInputType.multiline,
        // maxLines: null,
        decoration:
            new InputDecoration.collapsed(hintText: 'query session id '),
      ),
    ));

    content.add(
      Text(
        'Query Device Index:     --(note: this device index is: $_thisDeviceIndex)',
        style: TextStyle(
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            color: Styles().colors.fillColorPrimary),
      ),
    );

    content.add(Container(
      height: 50,
      child: TextField(
        controller: _queryDeviceIndexTextController,
        // keyboardType: TextInputType.multiline,
        // maxLines: null,
        decoration:
            new InputDecoration.collapsed(hintText: 'query device Index'),
      ),
    ));
    content.add(Padding(
        padding: EdgeInsets.only(top: 8),
        child: Row(children: <Widget>[
          Expanded(
            child: Stack(children: <Widget>[
              RoundedButton(
                label: 'Query Session Report',
                backgroundColor: Styles().colors.white,
                textColor: Styles().colors.fillColorPrimary,
                borderColor: Styles().colors.fillColorSecondary,
                fontFamily: Styles().fontFamilies.bold,
                fontSize: 10,
                borderWidth: 2,
                height: 42,
                onTap: () {
                  _onSessionReport();
                },
              )
            ]),
          ),
        ])));

    return Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: content);
  }

  // testing framework functions

  void _onSessionGet() async {
    if (_processingSessionID) {
      return;
    }
    setState(() {
      _processingSessionID = true; // block all buttons
      _executionStatus = "querying for session ID";
    });

    Map<String, String> headers = {"Content-type": "application/json"};

    Response response = await Network().post(Url + "GetSessionID",
        headers: headers, body: null, auth: NetworkAuth.App);
    String body = response.body;
    if (response.statusCode == HttpStatus.ok) {
      // update text field
      setState(() {
        _executionStatus = "available session id is " + body;
        _processingSessionID = false;
        _sessionIDTextController.text = body;
        _querySessionTextController.text = body;
      });
    } else {
      setState(() {
        _executionStatus = "error ";
        _processingSessionID = false;
      });
    }

    return;
  }

  /*
  * _onSessionCreate() async:
  * step0: check if there is a sessionID in the textfield
  * step1: get device info and save to a struct.
  * step2: attempt to upload device info to server
  * step3: attempt to create new session
  *  */
  void _onSessionCreate() async {
    if (_processingSessionID) {
      return;
    }
    // step 0: check for sessionID
    try {
      _currentSession = int.parse(_sessionIDTextController.text);
    } catch (e) {
      setState(() {
        _executionStatus = "failed, please enter a valid session ID or get one";
      });
      return;
    }
    // step1: get device info and save to a struct.
    try {
      await _gettingDeviceInfo();
    } catch (e) {
      print(e);
      return;
    }
    // step2: attempt to upload device info to server
    // step3: and create a new session with this device in it.
    setState(() {
      _executionStatus = "Uploading Device Info";
    });
    Map<String, String> headers = {"Content-type": "application/json"};
    String req =
        '{"isAndroid": $_isAndroid, "deviceID": "$_deviceID", "sessionID":$_currentSession}';
    print("" + req);
    Response response = await Network().post(Url + "CreateSession",
        headers: headers, body: req, auth: NetworkAuth.App);

    // statusCode:
    if (response.statusCode == HttpStatus.ok) {
      var parsed = json.decode(response.body);
      _isInSession = true;
      // display parsed["message"]
      // save parsed["deviceIndex"]
      _thisDeviceIndex = parsed["deviceIndex"];
      _queryDeviceIndexTextController.text = _thisDeviceIndex;
      _querySessionTextController.text = _sessionIDTextController.text;
      _executionStatus =
          response.statusCode.toString() + "" + parsed["message"];
    } else {
      _isInSession = false;
      _executionStatus = response.statusCode.toString() + " " + response.body;
    }
    setState(() {
      // should update _executaionStatus and _isInSession
      _processingSessionID = false;
    });

    if (_isInSession) {
      Exposure().startLogSession(_currentSession);
    }
    return;
  }

  /*
  * _onSessinJoin() async:
  * step0: check if there is a sessionID in the textfield
  * step1: get device info and save to a struct.
  * step2: attempt to upload device info to server
  * step3: attempt to join
  *  */
  void _onSessionJoin() async {
    // Response response = await Network()
    //     .post(Url + "getSessionID", body: post, auth: NetworkAuth.App);
    if (_processingSessionID) {
      return;
    }
    // step 0: check for sessionID
    try {
      _currentSession = int.parse(_sessionIDTextController.text);
    } catch (e) {
      setState(() {
        _executionStatus = "failed, please enter a valid session ID or get one";
      });
      return;
    }

    // step1: get device info and save to a struct.
    try {
      await _gettingDeviceInfo();
    } catch (e) {
      print(e);
      return;
    }
    // step2: attempt to upload device info to server
    // step3: and create a new session with this device in it.
    setState(() {
      _executionStatus = "Uploading Device Info";
    });
    Map<String, String> headers = {"Content-type": "application/json"};
    String req =
        '{"isAndroid": $_isAndroid, "deviceID": "$_deviceID", "sessionID":$_currentSession}';
    print("" + req);
    Response response = await Network().post(Url + "JoinSession",
        headers: headers, body: req, auth: NetworkAuth.App);
    // statusCode:
    // if ok, parse js
    // if not, print the value
    if (response.statusCode == HttpStatus.ok) {
      var parsed = json.decode(response.body);
      _isInSession = true;
      // display parsed["message"]
      // save parsed["deviceIndex"]
      _thisDeviceIndex = parsed["deviceIndex"];
      _queryDeviceIndexTextController.text = _thisDeviceIndex;
      _querySessionTextController.text = _sessionIDTextController.text;
      _executionStatus =
          response.statusCode.toString() + "" + parsed["message"];
    } else {
      _isInSession = false;
      _executionStatus = response.statusCode.toString() + " " + response.body;
    }
    setState(() {
      _processingSessionID = false;
    });

    if (_isInSession) {
      Exposure().startLogSession(_currentSession);
    }
    return;
  }

  /*
  _onEndSession:
  get current session id
  get additional details

  *  */
  void _onEndSession() async {
    if (_processingSessionID) {
      return;
    }
    setState(() {
      _processingSessionID = true;
      _executionStatus = "submitting additional detail and ending session";
    });

    try {
      _currentSession = int.parse(_sessionIDTextController.text);
    } catch (e) {
      setState(() {
        _executionStatus = "failed, please enter a valid session ID or get one";
      });
      return;
    }
    // post sessoin data first!!!
    Exposure().endLogSession(_deviceID, _isAndroid);
    Map<String, String> headers = {"Content-type": "application/json"};
    String req = '{"isAndroid": $_isAndroid, "deviceID": "$_deviceID",'
        ' "sessionID":$_currentSession, "additionalDetail":"${_additionalDetailTextController.text}" }';
    print("" + req);
    Response response = await Network().post(Url + "EndSession",
        headers: headers, body: req, auth: NetworkAuth.App);
    // update text field
    setState(() {
      if (response.statusCode == HttpStatus.ok) {
        _executionStatus = response.statusCode.toString() + " " + response.body;
        _processingSessionID = false;
        _isInSession = false;
      } else {
        _executionStatus = response.statusCode.toString() + " " + response.body;
      }
    });
    return;
  }

  Future<void> _gettingDeviceInfo() async {
    final DeviceInfoPlugin deviceInfoPlugin = new DeviceInfoPlugin();
    setState(() {
      _executionStatus = "Getting Device Info";
    });
    _isAndroid = Platform.isAndroid;
    if (_isAndroid) {
      var build = await deviceInfoPlugin.androidInfo;
      _deviceID = build.androidId;
    } else {
      var data = await deviceInfoPlugin.iosInfo;
      _deviceID = data.identifierForVendor;
    }
  }

  void _onSessionReport() async {
    // construct url for GET method
    String url = QueryUrl;
    // check for sessionID
    String sessionID = _querySessionTextController.text;
    String deviceIndex = _queryDeviceIndexTextController.text;
    bool a = sessionID.length == 0;
    bool b = deviceIndex.length == 0;

    if (a && b) {
      // both index and sessionID is empty
    } else if (a && (!b)) {
      // sessionID is empty and deviceIndex is nonzerok
      url += "deviceIndex=$deviceIndex";
    } else if ((!a) && b) {
      // sessionID is nonempty and deviceIndex is zero
      url += "sessionID=$sessionID";
    } else if ((!a) && (!b)) {
      // both sessionId and deviceIndex are specified
      url += "sessionID=$sessionID&deviceIndex=$deviceIndex";
    }
    if (await url_launcher.canLaunch(url)) {
      await url_launcher.launch(url);
    } else {
      throw 'Could not launch $url';
    }

    // await showDialog<void>(
    //   context: context,
    //   builder: (BuildContext context) {
    //     return AlertDialog(
    //       title: const Text('Thanks!'),
    //       content: Text(url),
    //       actions: <Widget>[
    //         FlatButton(
    //           onPressed: () {
    //             Navigator.pop(context);
    //           },
    //           child: const Text('OK'),
    //         ),
    //       ],
    //     );
    //   },
    // ); // showDialog
  }
}
