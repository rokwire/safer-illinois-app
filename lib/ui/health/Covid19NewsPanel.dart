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
import 'package:flutter_html/flutter_html.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';

class Covid19NewsPanel extends StatefulWidget {
  final Covid19News covid19news;

  Covid19NewsPanel({@required this.covid19news});

  @override
  _Covid19NewsPanelState createState() => _Covid19NewsPanelState();
}

class _Covid19NewsPanelState extends State<Covid19NewsPanel> implements NotificationsListener {
  
  @override
  void initState() {
    NotificationService().subscribe(this, [User.notifyFavoritesUpdated]);
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String displayDate = widget.covid19news?.displayDate;
    String title = widget.covid19news?.title;
    String htmlContent = widget.covid19news?.htmlContent;
    bool isFavorite = User().isFavorite(widget.covid19news);
    bool starVisible = User().favoritesStarVisible;
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(
          Localization().getStringEx("panel.covid19_news.header.title", "COVID-19"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: SingleChildScrollView(
        child: Stack(
          alignment: Alignment.topRight,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Visibility(
                    visible: AppString.isStringNotEmpty(displayDate),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        sprintf(Localization().getStringEx('panel.covid19_news.news.posted.label', 'Posted on %s'),
                            [AppString.getDefaultEmptyString(value: displayDate)]),
                        style: TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.bold, color: Styles().colors.textBackground),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: AppString.isStringNotEmpty(title),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 18),
                      child: Text(
                        AppString.getDefaultEmptyString(value: title),
                        style: TextStyle(fontSize: 28, color: Styles().colors.fillColorPrimary),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: AppString.isStringNotEmpty(htmlContent),
                    child: Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Html(
                        data: htmlContent,
                        onLinkTap: (url) => _onLinkTap(url),
                        defaultTextStyle: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),
                      ),
                    ),
                  )
                ],
              ),
            ),
            Visibility(
              visible: starVisible,
              child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _onTapNewsCardStar(widget.covid19news),
                  child: Semantics(
                      label: isFavorite
                          ? Localization().getStringEx('widget.card.button.favorite.off.title', 'Remove From Favorites')
                          : Localization().getStringEx('widget.card.button.favorite.on.title', 'Add To Favorites'),
                      hint: isFavorite
                          ? Localization().getStringEx('widget.card.button.favorite.off.hint', '')
                          : Localization().getStringEx('widget.card.button.favorite.on.hint', ''),
                      button: true,
                      excludeSemantics: true,
                      child: Container(
                        padding: EdgeInsets.only(top: 12, right: 12),
                        height: 52,
                        width: 52,
                        child: Align(
                          alignment: Alignment.topRight,
                          child: Image.asset(isFavorite ? 'images/icon-star-selected.png' : 'images/icon-star.png', excludeFromSemantics: true,),
                        ),
                      ))),
            )
          ],
        ),
      ),
    );
  }

  void _onTapNewsCardStar(Covid19News news) {
    Analytics.instance.logSelect(target: "Favorite: Covid-19 News");
    User().switchFavorite(news);
  }

  void _onLinkTap(String url) {
    if (AppString.isStringEmpty(url)) {
      return;
    }
    if (AppUrl.launchInternal(url)) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => WebPanel(url: url)));
    } else {
      launch(url);
    }
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == User.notifyFavoritesUpdated) {
      setState(() {});
    }
  }
}

class Covid19NewsCard extends StatefulWidget {
  final Covid19News news;

  Covid19NewsCard({@required this.news});

  @override
  _Covid19NewsCardState createState() => _Covid19NewsCardState();
}

class _Covid19NewsCardState extends State<Covid19NewsCard> implements NotificationsListener {

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [User.notifyFavoritesUpdated]);
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  @override
  void onNotification(String name, param) {
    if (name == User.notifyFavoritesUpdated) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.news.title;
    String dateFormatted = widget.news.displayDate;
    bool isFavorite = User().isFavorite(widget.news);
    bool starVisible = User().favoritesStarVisible;
    return GestureDetector(
        onTap: () => _onTapNewsCard(widget.news), child: Padding(padding: EdgeInsets.only(bottom: 16), child: Stack(alignment: Alignment.topRight,
      children: <Widget>[
        Semantics(hint: Localization().getStringEx('widget.covid19_news_card.read_more.hint', "Double tap to read more"), child:

        Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(color: Styles().colors.white, borderRadius: BorderRadius.all(Radius.circular(4.0)),
              boxShadow: [BoxShadow(color: Styles().colors.fillColorPrimaryTransparent015, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(0, 2))],),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Padding(padding: EdgeInsets.only(bottom: 12, right: 42), child: Row(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Expanded(child: Text(AppString.getDefaultEmptyString(value: title), maxLines: 6, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 20, fontFamily: Styles().fontFamilies.extraBold, color: Styles().colors.fillColorPrimary),),)
                ],),),
              Row(mainAxisAlignment: MainAxisAlignment.start, children: <Widget>[
                Padding(padding: EdgeInsets.only(right: 8), child: Image.asset('images/icon-news.png', excludeFromSemantics: true,),),
                Text(AppString.getDefaultEmptyString(value: dateFormatted),
                  style: TextStyle(fontSize: 14, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),)
              ],)
            ],))),
        Visibility(visible: starVisible, child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTapNewsCardStar(widget.news),
            child: Semantics(
                label: isFavorite ? Localization().getStringEx('widget.card.button.favorite.off.title', 'Remove From Favorites') : Localization().getStringEx(
                    'widget.card.button.favorite.on.title', 'Add To Favorites'),
                hint: isFavorite ? Localization().getStringEx('widget.card.button.favorite.off.hint', '') : Localization().getStringEx(
                    'widget.card.button.favorite.on.hint', ''),
                button: true,
                excludeSemantics: true,
                child: Container(
                  padding: EdgeInsets.only(top: 16, right: 16), height: 52, width: 52,
                  child: Align(alignment: Alignment.topRight,
                    child: Image.asset(isFavorite ? 'images/icon-star-selected.png' : 'images/icon-star.png', excludeFromSemantics: true,),),)
            )),)
      ],),));
  }

  void _onTapNewsCardStar(Covid19News news) {
    Analytics.instance.logSelect(target: "Favorite: Covid-19 News");
    User().switchFavorite(news);
  }

  void _onTapNewsCard(Covid19News news) {
    Analytics.instance.logSelect(target: "Covid-19 News: ${news?.title}");
    if (news != null) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19NewsPanel(covid19news: news,)));
    }
  }
}

