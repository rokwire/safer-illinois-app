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
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/utils/AppDateTime.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';

class Covid19DebugPendingEventsPanel extends StatefulWidget {

  Covid19DebugPendingEventsPanel();

  @override
  _Covid19DebugPendingEventsPanelState createState() => _Covid19DebugPendingEventsPanelState();
}

class _Covid19DebugPendingEventsPanelState extends State<Covid19DebugPendingEventsPanel> {

  List<Covid19Event> _events;
  Map<String, HealthServiceProvider> _providers;
  bool _loadingEvents;
  bool _clearingEvents;
  bool _processingEvents;
  String _status;

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadProviders();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loadingEvents == true) {
      content = _buildLoading();
    }
    else if (_status != null) {
      content = _buildStatus(_status);
    }
    else if ((_events == null) || (_events.length == 0)) {
      content = _buildStatus("No pending events");
    }
    else {
      content = _buildContent();
    }

    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text("COVID-19 Events", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: SingleChildScrollView(
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    content
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

  Widget _buildLoading() {
    return Padding(padding:EdgeInsets.symmetric(vertical: 200), child:
        Align(alignment: Alignment.center, child:
          Container(width: 42, height: 42, child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), strokeWidth: 2,)
          ),
        ),
    );
  }

  Widget _buildStatus(String text) {
    return Padding(padding: EdgeInsets.only(left: 32, right:32, top: 200),
        child:Align(alignment: Alignment.center, child:
          Text(text, style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
        ),
      );
  }

  Widget _buildContent() {
    List<Widget> results = <Widget>[];
    for (Covid19Event event in _events) {
      results.add(_buildEvent(event));
    }
    results.add(_buildProcess());
    results.add(_buildClear());
    return Column(children: results,);
  }

  Widget _buildEvent(Covid19Event event) {
    DateTime date = event.dateUpdated ?? event.dateCreated;
    String displayDate = AppDateTime.formatDateTime(date, format: "MMM dd, HH:mma") ?? '';
    String providerName = (_providers != null) ? _providers[event.providerId]?.name : null;
    String providerLabel = (providerName != null) ? Localization().getStringEx("panel.health.covid19.debug.test.label.provider","Provider: ") :
                                                    Localization().getStringEx("panel.health.covid19.debug.test.label.provider_id","Provider Id: ");
    String providerValue = ((providerName != null) ? providerName : event.providerId) ?? '';

    return Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Semantics(container: true, child:
        Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Styles().colors.white,
            boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 1.0, blurRadius: 3.0, offset: Offset(1, 1))],
            borderRadius: BorderRadius.all(Radius.circular(4))
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
            Padding(padding:EdgeInsets.only(bottom: 4), child: Row(children: <Widget>[
              Text(providerLabel , style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
              Text(providerValue, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.fillColorPrimary),),
            ],)
            ),
            Row(children: <Widget>[
              Text(Localization().getStringEx("panel.health.covid19.debug.test.label.date","Date: "), style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 16, color: Styles().colors.fillColorPrimary),),
              Text(displayDate, overflow: TextOverflow.ellipsis, style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.fillColorPrimary),),
            ],),
            Padding(padding:EdgeInsets.only(top: 8), child:Semantics(label: "blob", child:Text("${AppJson.encode(event?.blob?.toJson())}", style: TextStyle(fontFamily: Styles().fontFamilies.regular, fontSize: 16, color: Styles().colors.textSurface),),)),
          ]),
        )
      )
    );
  }

  Widget _buildProcess() {
    return Padding(padding: EdgeInsets.only(top: 24, left: 24, right: 24),
      child: Stack(children: <Widget>[
        RoundedButton(label: Localization().getStringEx("panel.health.covid19.debug.test.button.process.title","Process"), hint: '', backgroundColor: Styles().colors.background, borderColor: Styles().colors.fillColorSecondary, textColor: Styles().colors.fillColorPrimary, onTap: () => _onProcess()),
          Visibility(visible: (_processingEvents == true),
            child: Container(height: 48,
              child: Align(alignment: Alignment.center,
                child: SizedBox(height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                ),
              ),
            ),
          ),
      ],),
    );
  }

  Widget _buildClear() {
    return Padding(padding: EdgeInsets.only(top: 24, bottom: 24, left: 24, right: 24),
      child: Stack(children: <Widget>[
        RoundedButton(label: Localization().getStringEx("panel.health.covid19.debug.test.button.clear.title","Clear"), hint: '', backgroundColor: Styles().colors.background, borderColor: Styles().colors.fillColorSecondary, textColor: Styles().colors.fillColorPrimary, onTap: () => _onClear()),
          Visibility(visible: (_clearingEvents == true),
            child: Container(height: 48,
              child: Align(alignment: Alignment.center,
                child: SizedBox(height: 24, width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), )
                ),
              ),
            ),
          ),
      ],),
    );
  }

  Future<void> _loadEvents() async {
    setState(() {
      _loadingEvents = true;
    });

    List<Covid19Event> events = await Health().loadCovid19Events(processed: false);
    setState(() {
      _loadingEvents = false;
      _events = events;
      if (events == null) {
        _status = "Failed to load events";
      }
    });
  }

  Future<void> _loadProviders() async {
    List<HealthServiceProvider> providers = await Health().loadHealthServiceProviders();
    setState(() {
      if (providers != null) {
        _providers = Map<String, HealthServiceProvider>();
        for (HealthServiceProvider provider in providers) {
          _providers[provider.id] = provider;
        }
      }
    });
  }

  Future<void> _clearEvents() async {
    setState(() {
      _clearingEvents = true;
    });
    bool result = await Health().clearCovid19Tests();
    setState(() {
      _clearingEvents = false;
    });
    if (result) {
      await _loadEvents();
    }
    else {
      AppAlert.showDialogResult(context, "Failed to clear COVID-19 events.");
    }
  }

  void _onClear() {
    Analytics.instance.logSelect(target: "Clear");
    _clearEvents();
  }

  Future<void> _processEvents() async {
    setState(() {
      _processingEvents = true;
    });
    await Health().currentCountyStatus.then((_){

      setState(() {
        _processingEvents = false;
        _loadingEvents = true;
      });

      Health().loadCovid19Events(processed: false).then((List<Covid19Event> events) {
        setState(() {
          _loadingEvents = false;
          _events = events;
          if (events == null) {
            _status = "Failed to load events";
          }
        });
        //if ((events?.length ?? 0) == 0) {
        //  Navigator.pop(context);
        //}
      });
    });
  }

  void _onProcess() {
    Analytics.instance.logSelect(target: "Process");
    _processEvents();
  }

}
