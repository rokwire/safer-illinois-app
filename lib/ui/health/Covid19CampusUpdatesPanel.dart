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
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/ui/health/Covid19NewsPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';

class Covid19CampusUpdatesPanel extends StatefulWidget {
  @override
  _Covid19CampusUpdatesPanelState createState() => _Covid19CampusUpdatesPanelState();
}

class _Covid19CampusUpdatesPanelState extends State<Covid19CampusUpdatesPanel> {
  List<Covid19News> _covid19News;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadNews() {
    _setLoading(true);
    Health().loadCovid19News().then((covid19News) {
      _covid19News = covid19News;
      _setLoading(false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.covid19_campus_updates.header.title", "Campus updates"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      backgroundColor: Styles().colors.background,
      body: (_loading ? Center(child: CircularProgressIndicator(),) : SingleChildScrollView(
        child: Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24), child: Column(crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Padding(padding: EdgeInsets.only(bottom: 24),
              child: Text(Localization().getStringEx("panel.covid19_campus_updates.sub_title.title", "University of Illinois COVID-19 updates"),
                textAlign: TextAlign.center,
                style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.regular),),),
            _newsItems()
          ],),),
      )),
    );
  }

  Widget _newsItems() {
    if (AppCollection.isCollectionEmpty(_covid19News)) {
      return Container();
    }
    return ListView.separated(physics: NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        separatorBuilder: (context, index) => Container(height: 24),
        itemCount: _covid19News.length,
        itemBuilder: (BuildContext context, int index) {
          Covid19News news = _covid19News[index];
          return Covid19NewsCard(news: news,);
        });
  }

  void _setLoading(bool loading) {
    if (mounted) {
      setState(() {
        _loading = loading;
      });
    }
  }
}
