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
import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart';
import 'package:intl/intl.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Auth.dart';
import 'package:illinois/service/Config.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Network.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/utils/Crypt.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';

class DebugCreateEventPanel extends StatefulWidget {

  DebugCreateEventPanel();

  @override
  _DebugCreateEventPanelState createState() => _DebugCreateEventPanelState();
}

class _DebugCreateEventPanelState extends State<DebugCreateEventPanel> {

  TextEditingController _blobController;
  String _headerStatus;
  
  bool _loadingPublicKey;
  bool _refreshingPublicKey;

  LinkedHashMap<String, HealthServiceProvider> _providers;
  String _selectedProviderId;
  DateTime _selectedDate;


  bool _submitting;
  
  @override
  void initState() {
    super.initState();
    
    _blobController = TextEditingController(text: this._sampleTestNegativeBlob);

    _selectedProviderId = Storage().lastHealthProvider?.id;
    
    _loadingPublicKey = true;
    Health().refreshUser().then((_) {
      if (mounted) {
        setState(() {
          _loadingPublicKey = false;
          _headerStatus = (Health().user?.publicKey != null) ? "User's public RSA key loaded." : "Failed to load user's public RSA key.";
        });
      }
    });

      Health().loadProviders().then((List<HealthServiceProvider> providers){
        if (mounted) {
          setState(() {
            try {
              _providers = (providers != null) ? Map<String,HealthServiceProvider>.fromIterable(providers, key: ((provider) => provider.id)): null;
            }
            catch(e) {}
          });
        }
      });

  }

  @override
  void dispose() {
    super.dispose();
    _blobController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text("COVID-19 Event", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: SafeArea(child:
        Column(children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _buildHeading(),
                  _buildContent(),
                ],
              ),
            ),
          ),
          _buildSubmit(),
        ],),
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildHeading() {
    String input;
    if (_loadingPublicKey == true) {
      input = Localization().getStringEx("panel.health.covid19.debug.create.loading.user_key","Loading user's public RSA key...");
    }
    else if (_refreshingPublicKey == true) {
      input = Localization().getStringEx("panel.health.covid19.debug.create.loading.refresh_keys","Refreshing RSA Keys...");
    }
    else if (_headerStatus != null) {
      input = _headerStatus;
    }
    else {
      input = '';
    }


    return Semantics(container: true, child:
      Container(color:Colors.white,
      child: Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children:<Widget>[
            Semantics(label: Localization().getStringEx("panel.health.covid19.debug.create.label.description.hint","status: "), child: Text(input, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Color(0xff494949)))),
            _buildRefresh(),
          ]),
      ),
    ));
  }

  Widget _buildRefresh() {
    bool loading = (_loadingPublicKey == true) || (_refreshingPublicKey == true);
    return Padding(padding: EdgeInsets.only(top: 8), child:
      Row(children: <Widget>[
        Stack(children: <Widget>[
          RoundedButton(label:Localization().getStringEx("panel.health.covid19.debug.create.button.refresh.title", "Refresh RSA Keys"),
            textColor: !loading ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
            borderColor: !loading ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColorTwo,
            backgroundColor: Styles().colors.white,
            fontFamily: Styles().fontFamilies.bold,
            fontSize: 16,
            borderWidth: 2,
            width: 200,
            height: 42,
            onTap:() { _onRefreshRSAKeys();  }
          ),
          Visibility(visible:  loading, child:
            Padding(padding: EdgeInsets.only(left: (200 - 21) / 2), child:
              Center(child:
                Padding(padding: EdgeInsets.only(top: 10.5), child:
                Container(width: 21, height:21, child:
                    CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                  ),
                ),
              ),
            ),
          ),
        ],),
      ],),
    );
  }

  Widget _buildContent() {
    String dateText = (_selectedDate != null) ? AppDateTime.formatDateTime(_selectedDate, format: 'MM/dd/yyyy') : "-";
    return Padding(padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children: <Widget>[

        Semantics(container: true, child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Padding(padding: EdgeInsets.only(bottom: 4),
              child: Text(Localization().getStringEx("panel.health.covid19.debug.create.label.provider","Provider"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
            ),
            Container(decoration: BoxDecoration(color: Styles().colors.white, border: Border.all(color: Colors.black, width: 1), borderRadius: BorderRadius.all(Radius.circular(4))),
              child: Padding(padding: EdgeInsets.only(left: 12, right: 16),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton(
                    icon: Image.asset('images/icon-down-orange.png', excludeFromSemantics: true,),
                    isExpanded: true,
                    style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                    hint: Text(_selectedProvider?.name ?? "Select a provider...",style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),),
                    items: _buildProviderDropDownItems(_providers?.values),
                    onChanged: (value) { setState(() {
                      Storage().lastHealthProvider =  value;
                      _selectedProviderId = value?.id;
                    });}
                  ),
                ),
              ),
            )
          ],),
        ),

        Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Padding(padding: EdgeInsets.only(bottom: 4),
              child: Text("Date (Exempt):", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
            ),
            GestureDetector(onTap: _onTapPickDate,
              child: Container(height: 48, 
                decoration: BoxDecoration(border: Border.all(color: Styles().colors.surfaceAccent, width: 1), borderRadius: BorderRadius.all(Radius.circular(4))),
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: <Widget>[
                  Text(dateText, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.medium),),
                  Image.asset('images/icon-down-orange.png')
                ],),
              ),
            ),
          ],)
        ),

        Padding(padding: EdgeInsets.symmetric(vertical: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Padding(padding: EdgeInsets.only(bottom: 4),
              child: Text(Localization().getStringEx("panel.health.covid19.debug.create.label.blob","Blob"), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
            ),
            Stack(children: <Widget>[
              Semantics(textField: true, child:Container(color: Styles().colors.white,
                child: TextField(
                  maxLines: 4,
                  controller: _blobController,
                  decoration: InputDecoration(border: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 1.0))),
                  style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textBackground,),
                ),
              )),
              Align(alignment: Alignment.topRight,
                child: Semantics (button: true, label: Localization().getStringEx("panel.health.covid19.debug.create.hint.provider","Clear"),
                  child: GestureDetector(onTap: () { _clearBlob(); },
                    child: Container(width: 36, height: 36,
                      child: Align(alignment: Alignment.center,
                        child: Semantics( excludeSemantics: true,child:Text('X', style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.fillColorPrimary,),)),
                      ),
                    ),
                  ),
              )),
            ]),
          ]),
        ),


        Padding(padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Padding(padding: EdgeInsets.only(bottom: 4),
              child: Text("Populate", style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 12, color: Styles().colors.fillColorPrimary),),
            ),

            Row(children: <Widget>[
              Expanded(child:
                RoundedButton(label: "Negative Test",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleTestNegativeBlob);  }
                ),
              ),
              Container(width: 4,),
              Expanded(child:
                RoundedButton(label: "Positive Test",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleTestPositiveBlob);  }
                ),
              ),
            ],),

            Container(height: 16,),

            Row(children: <Widget>[
              Expanded(child:
                RoundedButton(label: "Quarantine ON",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionQuarantineOnBlob);  }
                ),
              ),
              Container(width: 4,),
              Expanded(child:
                RoundedButton(label: "Quarantine OFF",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionQuarantineOffBlob);  }
                ),
              ),
            ],),

            Container(height: 4,),

            Row(children: <Widget>[
              Expanded(child:
                RoundedButton(label: "Exempt ON",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionExemptOnBlob);  }
                ),
              ),
              Container(width: 4,),
              Expanded(child:
                RoundedButton(label: "Exempt OFF",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionExemptOffBlob);  }
                ),
              ),
            ],),

            Container(height: 4,),

            Row(children: <Widget>[
              Expanded(child:
                RoundedButton(label: "Out Of Compliance",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionOutOfComplianceBlob);  }
                ),
              ),
              Container(width: 4,),
              Expanded(child:
                RoundedButton(label: "Pending Test",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionTestPendingBlob);  }
                ),
              ),
            ],),

            Container(height: 4,),

            Row(children: <Widget>[
              Expanded(child:
                RoundedButton(label: "Force Test",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionForceTestBlob);  }
                ),
              ),
              Container(width: 4,),
              Expanded(child:
                RoundedButton(label: "Release",
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorSecondary,
                  backgroundColor: Styles().colors.white,
                  fontFamily: Styles().fontFamilies.bold,
                  fontSize: 16, borderWidth: 2, height: 42,
                  onTap:() { _onPopulate(this._sampleActionReleaseBlob); }
                ),
              ),
            ],),

          ],),
        ),

      ]),
    );
  }

  Widget _buildSubmit() {
    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Stack(children: <Widget>[
          Row(children: <Widget>[
            Expanded(child: Container(),),
            RoundedButton(label: "Submit Event",
              textColor: (Health().user?.publicKey != null) ? Styles().colors.fillColorPrimary : Styles().colors.disabledTextColor,
              borderColor: (Health().user?.publicKey != null) ? Styles().colors.fillColorSecondary : Styles().colors.disabledTextColor,
              backgroundColor: Styles().colors.white,
              fontFamily: Styles().fontFamilies.bold,
              fontSize: 16,
              padding: EdgeInsets.symmetric(horizontal: 32, ),
              borderWidth: 2,
              height: 42,
              onTap:() { _onSubmit();  }
            ),
            Expanded(child: Container(),),
          ],),
          Visibility(visible: (_submitting == true), child:
            Center(child:
              Padding(padding: EdgeInsets.only(top: 10.5), child:
               Container(width: 21, height:21, child:
                  CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 2,)
                ),
              ),
            ),
          ),
        ],),
      );
  }

  // Provider

  HealthServiceProvider get _selectedProvider {
    return (_providers != null) ? _providers[_selectedProviderId] : null;
  }

  List<DropdownMenuItem<dynamic>> _buildProviderDropDownItems(Iterable<HealthServiceProvider> items) {
    return (items != null) ? items.map((HealthServiceProvider item) {
      return DropdownMenuItem<dynamic>(value: item, child: Text(item.name),);
    }).toList() : null;
  }

  // Encryption

  void _clearBlob() {
    _blobController.text = '';
  }

  void _onRefreshRSAKeys() {
    setState(() {
      _refreshingPublicKey = true;
    });
    Health().resetUserKeys().then((_) {
      if (mounted) {
        setState(() {
          _refreshingPublicKey = false;
          _headerStatus = (Health().user?.publicKey != null) ?
            Localization().getStringEx("panel.health.covid19.debug.create.label.status.refreshed","User's public RSA key refreshed.") :
            Localization().getStringEx("panel.health.covid19.debug.create.label.status.error","Failed to refresh user's public RSA key.");
        });

      }
    });
  }

  String get _sampleTestNegativeBlob {
    DateTime nowLocal = DateTime.now();
    String dateString = healthDateTimeToString(nowLocal.toUtc());
    String localString = DateFormat("MMMM d, yyyy HH:mm").format(nowLocal);
    String orderNumber = Random().nextInt(999999).toString().padLeft(6, '0');
    return '''{
  "Date": "$dateString",
  "TestName": "COVID-19 PCR",
  "Result": "negative",
  "Extra": [
    {"display_name": "Collected", "display_value": "$localString"},
    {"display_name": "Resulted", "display_value": "$localString"},
    {"display_name": "Order #", "display_value": "CU$orderNumber"}
  ]
}''';}

  String get _sampleTestPositiveBlob {
    DateTime nowLocal = DateTime.now();
    String dateString = healthDateTimeToString(nowLocal.toUtc());
    String localString = DateFormat("MMMM d, yyyy HH:mm").format(nowLocal);
    String orderNumber = Random().nextInt(999999).toString().padLeft(6, '0');
    return '''{
  "Date": "$dateString",
  "TestName": "COVID-19 PCR",
  "Result": "positive",
  "Extra": [
    {"display_name": "Collected", "display_value": "$localString"},
    {"display_name": "Resulted", "display_value": "$localString"},
    {"display_name": "Order #", "display_value": "CU$orderNumber"}
  ]
}''';}

  String get _sampleActionQuarantineOnBlob {
    DateTime nowLocal = DateTime.now();
    String dateString = healthDateTimeToString(nowLocal.toUtc());
    String orderNumber = Random().nextInt(999999).toString().padLeft(6, '0');
    return '''{
  "Date": "$dateString",
  "ActionType": "quarantine-on",
  "ActionTitle": {
    "en": "Quarantined",
    "es": "En cuarentena",
    "zh": "隔離區"
  },
  "ActionText": {
    "en": "You are in quarantine",
    "es": "Estas en cuarentena",
    "zh": "您正在隔離"
  },
  "Extra": [
    {
      "display_name": {"en": "Issued", "es": "Emitido", "zh": "發布" },
      "display_value": {
        "en": "${DateFormat("MMMM d, yyyy HH:mm", "en").format(nowLocal)}",
        "es": "${DateFormat("MMMM d, yyyy HH:mm", "es").format(nowLocal)}",
        "zh": "${DateFormat("MMMM d, yyyy HH:mm", "zh").format(nowLocal)}"
      }
    },
    {
      "display_name": {"en": "Order #", "es": "Orden #", "zh": "命令 ＃" },
      "display_value": "CU$orderNumber"
    }
  ]
}''';}

  String get _sampleActionQuarantineOffBlob {
    DateTime nowLocal = DateTime.now();
    String dateString = healthDateTimeToString(nowLocal.toUtc());
    String orderNumber = Random().nextInt(999999).toString().padLeft(6, '0');
    return '''{
  "Date": "$dateString",
  "ActionType": "quarantine-off",
  "ActionTitle": {
    "en": "Released from Quarantine",
    "es": "Liberado de cuarentena",
    "zh": "從隔離區釋放"
  },
  "ActionText": {
    "en": "You are out of quarantine",
    "es": "Estas fuera de cuarentena",
    "zh": "你沒隔離"
  },
  "Extra": [
    {
      "display_name": {"en": "Issued", "es": "Emitido", "zh": "發布" },
      "display_value": {
        "en": "${DateFormat("MMMM d, yyyy HH:mm", "en").format(nowLocal)}",
        "es": "${DateFormat("MMMM d, yyyy HH:mm", "es").format(nowLocal)}",
        "zh": "${DateFormat("MMMM d, yyyy HH:mm", "zh").format(nowLocal)}"
      }
    },
    {
      "display_name": {"en": "Order #", "es": "Orden #", "zh": "命令 ＃" },
      "display_value": "CU$orderNumber"
    }
  ]
}''';}

  String get _sampleActionExemptOnBlob {
    String date = healthDateTimeToString(DateTime.now().toUtc());
    DateTime dateMidnight = AppDateTime.midnight(_selectedDate);
    DateTime nowMidnight = AppDateTime.midnight(DateTime.now());
    int duration = dateMidnight?.difference(nowMidnight)?.inDays ?? -1;
    int exemptInterval = (0 <= duration) ? duration : null;

    DateTime exemptDate = (exemptInterval != null) ? nowMidnight.add(Duration(days: exemptInterval)) : null;
    String exemptDateString = (exemptDate != null) ? AppDateTime.formatDateTime(exemptDate, format: 'EEEE, MMM d') : null;
    String actionText = (exemptDateString != null) ? "You are exempt from testing until $exemptDateString" : "You are exempt from testing";

    return '''{
  "Date": "$date",
  "ActionType": "exempt-on",
  "ActionTitle": "Exempt",
  "ActionText": "$actionText",
  "ActionParams": { "ExemptInterval": $exemptInterval }
}''';}

  String get _sampleActionExemptOffBlob {
    String date = healthDateTimeToString(DateTime.now().toUtc());
    return '''{
  "Date": "$date",
  "ActionType": "exempt-off",
  "ActionTitle": "Exempt Canceled"
  "ActionText": "Your exempt from testing status is canceled"
 }''';}

  String get _sampleActionOutOfComplianceBlob {
    String date = healthDateTimeToString(DateTime.now().toUtc());
    return '''{
  "Date": "$date",
  "ActionType": "out-of-test-compliance",
  "ActionTitle": "Out of Compliance",
  "ActionText": "You are out of test compliance"
}''';}

  String get _sampleActionTestPendingBlob {
    String date = healthDateTimeToString(DateTime.now().toUtc());
    return '''{
  "Date": "$date",
  "ActionType": "test_pending",
  "ActionTitle": "Pending Test",
  "ActionText": "Your test is pending"
}''';}

  String get _sampleActionForceTestBlob {
    String date = healthDateTimeToString(DateTime.now().toUtc());
    return '''{
  "Date": "$date",
  "ActionType": "force-test",
  "ActionTitle": "Test Required",
  "ActionText": "You are required to have 2 tests separated by 3 days"
}''';}

  String get _sampleActionReleaseBlob {
    String date = healthDateTimeToString(DateTime.now().toUtc());
    return '''{
  "Date": "$date",
  "ActionType": "release",
  "ActionTitle": "Release",
  "ActionText": "You are required to to take a test"
}''';}

  void _onPopulate(String content) {
    _blobController.text = content;
  }

  void _onTapPickDate() {
    DateTime initialDate = (_selectedDate != null) ? _selectedDate : DateTime.now();
    DateTime firstDate = initialDate.subtract(new Duration(days: 365 * 5));
    DateTime lastDate = initialDate.add(new Duration(days: 365 * 5));
    showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      builder: (BuildContext context, Widget child) {
        return Theme(data: ThemeData.light(), child: child,);
      },
    ).then((DateTime result) {
      if (mounted && (result != null)) {
        setState(() {
          _selectedDate = result;
        });
      }
    });
  }

  Future<String> _postEvent({String blob, String providerId}) async {
    String aesKey = AESCrypt.randomKey();
    String encryptedBlob = AESCrypt.encrypt(blob, keyString: aesKey);
    String encryptedKey = RSACrypt.encrypt(aesKey, Health().user?.publicKey);
    String userUin = (Health().userAccount?.isDefault != false) ? Auth().authUser?.uin : Health().userAccount.externalId;

    //PointyCastle.PrivateKey privateKey = await Health().userPrivateKey;
    //String decryptedKey = ((privateKey != null) && (encryptedKey != null)) ? RSACrypt.decrypt(encryptedKey, privateKey) : null;
    //String decryptedBlob = ((decryptedKey != null) && (encryptedBlob != null)) ? AESCrypt.decrypt(encryptedBlob, keyString: decryptedKey) : null;


    String url = "${Config().healthUrl}/covid19/ctests";
    String post = AppJson.encode({
      'provider_id': providerId,
      'uin': userUin,
      'encrypted_key': encryptedKey,
      'encrypted_blob': encryptedBlob
    });
    
    Response response = await Network().post(url, body:post, headers: { Network.RokwireHSApiKey : Config().healthApiKey });
    if (response == null) {
      return Localization().getStringEx("panel.health.covid19.debug.create.label.error.timeout","Request Timeout");
    }
    else if (response.statusCode == 200) {
      return null;
    }
    else {
      return response.body ?? Localization().getStringEx("panel.health.covid19.debug.create.label.error.unknown","Unknwon Error Occured");
    }
  }

  void _onSubmit() {
    if ((Health().user?.publicKey != null) && (_submitting != true) && (_loadingPublicKey != true)) {
      setState(() {
        _submitting = true;
      });
      _postEvent(blob: _blobController.text, providerId: _selectedProviderId).then((String error) {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
          if (error == null) {
            Navigator.of(context).pop();
          }
          else {
            Analytics.instance.logAlert(text: error);
            AppAlert.showDialogResult(context, error);
          }
        }
      });
    }
  }
}
