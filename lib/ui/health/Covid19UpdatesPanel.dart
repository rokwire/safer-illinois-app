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
import 'package:illinois/service/Assets.dart';

import 'package:illinois/service/Health.dart';
import 'package:illinois/service/FirebaseMessaging.dart';
import 'package:illinois/service/FlexUI.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/AppDateTime.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/health/Covid19NewsPanel.dart';
import 'package:illinois/ui/widgets/FlexContentWidget.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/SectionTitlePrimary.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:illinois/service/Styles.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';

class Covid19UpdatesPanel extends StatefulWidget {
  @override
  _Covid19UpdatesPanelState createState() => _Covid19UpdatesPanelState();
}

class _Covid19UpdatesPanelState extends State<Covid19UpdatesPanel> with TickerProviderStateMixin implements NotificationsListener {
  List<Covid19News> _covid19News;
  bool              _newsLoading = false;
  Covid19FAQ        _faq;
  bool              _faqLoading = false;
  List<AnimationController> _animationControllers = List();

  @override
  void initState() {
    NotificationService().subscribe(this, [
      FlexUI.notifyChanged,
      FirebaseMessaging.notifySettingUpdated,
      User.notifyFavoritesUpdated
    ]);
    _loadNews();
    _loadFAQs();
    super.initState();
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    if(_animationControllers!=null && _animationControllers.isNotEmpty){
      _animationControllers.forEach((controller){
        controller.dispose();
      });
    }
    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == FlexUI.notifyChanged) {
      setState(() {});
    } else if (name == FirebaseMessaging.notifySettingUpdated) {
      setState(() {});
    } else if (name == User.notifyFavoritesUpdated) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.covid19.header.title", "COVID-19"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      backgroundColor: Styles().colors.background,
      body: SingleChildScrollView(
        child: Column(
          children: _buildContent(),
        ),
      ),
    );
  }

  void _loadNews() {
    _newsLoading = true;
    Health().loadCovid19News().then((covid19News) {
      if (mounted) {
        setState(() {
          _newsLoading = false;
          _covid19News = covid19News;
        });
      }
    });
  }

  void _loadFAQs() {
    _faqLoading = true;
    Health().loadCovid19FAQs().then((Covid19FAQ faq) {
      if (mounted) {
        setState(() {
          _faqLoading = false;
          _faq = faq;
        });
      }
    });
  }

  List<Widget> _buildContent() {
    List<dynamic> contentCodes = FlexUI()['health.covid19'] ?? ['latest_update', 'stay_informed', 'news', 'resources', 'general', 'faq'];
    List<Widget> contentWidgets = List();
    for (String code in contentCodes) {
      Widget widget;
      if (code == 'latest_update') {
        widget = _buildLatestUpdate();
      }
      else if (code == 'stay_informed') {
        widget = _buildStayInformed();
      }
      else if (code == 'news') {
        widget = _buildNews();
      }
      else if (code == 'resources') {
        widget = _buildResources();
      }
      else if (code == 'general') {
        widget = _buildGeneralInfo();
      }
      else if (code == 'faq') {
        widget = _buildFaq();
      }
      else {
        dynamic data = Assets()[code];
        if (data is Map) {
          widget = FlexContentWidget(jsonContent: data);
        }
      }

      if (widget != null) {
        contentWidgets.add(widget);
      }
    }

    return contentWidgets;
  }

  Widget _buildLatestUpdate() {
    Widget latestUpdateContentWidget;
    if (_newsLoading) {
      latestUpdateContentWidget = CircularProgressIndicator();
    } else {
      Covid19News latestUpdateNews = _covid19News?.first;
      bool hasLatestUpdate = (latestUpdateNews != null);
      String dateFormatted = AppString.getDefaultEmptyString(
          value: AppDateTime().formatDateTime(latestUpdateNews?.date, format: AppDateTime.covid19UpdateDateFormat));
      String title = AppString.getDefaultEmptyString(value: latestUpdateNews?.title);
      String description = AppString.getDefaultEmptyString(value: latestUpdateNews?.description);
      bool isFavorite = User().isFavorite(latestUpdateNews);
      bool starVisible = User().favoritesStarVisible;
      latestUpdateContentWidget = Visibility(visible: hasLatestUpdate, child: GestureDetector(onTap: () => _onTapNewsCard(latestUpdateNews), child: Stack(
        alignment: Alignment.topRight, children: <Widget>[
        Stack(
          alignment: Alignment.bottomCenter, children: <Widget>[Container(
            height: 288,
            padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(color: Styles().colors.white, borderRadius: BorderRadius.all(Radius.circular(4.0)),
              boxShadow: [BoxShadow(color: Styles().colors.fillColorPrimaryTransparent015, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(0, 2))],),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
              Text(dateFormatted, style: TextStyle(fontSize: 12, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),),
              Padding(padding: EdgeInsets.only(top: 12),
                  child: Text(title, style: TextStyle(fontSize: 20, fontFamily: Styles().fontFamilies.extraBold, color: Styles().colors.fillColorPrimary),)),
              Expanded(child: Padding(padding: EdgeInsets.only(top: 16),
                child: Text(description, overflow: TextOverflow.ellipsis,
                  maxLines: 20,
                  style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),),),),
            ])),
          Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(color: Styles().colors.white,
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(4.0))),
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: <Widget>[
              Container(height: 1, color: Styles().colors.fillColorSecondary,),
              Expanded(child: Center(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Text(Localization().getStringEx('panel.covid19.latest_updates.read_more.title', 'Read more'), style: TextStyle(fontSize: 16,
                      fontFamily: Styles().fontFamilies.bold,
                      color: Styles().colors.fillColorPrimary),),
                  Padding(
                    padding: EdgeInsets.only(left: 7), child: Image.asset('images/icon-down-orange.png'),),
                ],),),)
            ],),),
        ],), Visibility(visible: starVisible, child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _onTapNewsCardStar(latestUpdateNews),
            child: Semantics(
                label: isFavorite ? Localization().getStringEx('widget.card.button.favorite.off.title', 'Remove From Favorites') : Localization().getStringEx(
                    'widget.card.button.favorite.on.title', 'Add To Favorites'),
                hint: isFavorite ? Localization().getStringEx('widget.card.button.favorite.off.hint', '') : Localization().getStringEx(
                    'widget.card.button.favorite.on.hint', ''),
                button: true,
                excludeSemantics: true,
                child: Container(
                  padding: EdgeInsets.only(top: 12, right: 12), height: 52, width: 52,
                  child: Align(alignment: Alignment.topRight, child: Image.asset(isFavorite ? 'images/icon-star-selected.png' : 'images/icon-star.png'),),)
            )),)
      ],),),);
    }

    return SectionTitlePrimary(
        title: Localization().getStringEx('panel.covid19.latest_update.title', 'Latest Update'),
        iconPath: 'images/happening.png',
        children: [latestUpdateContentWidget]);
  }

  void _onTapNewsCard(Covid19News news) {
    Analytics.instance.logSelect(target: "Covid-19 News: ${news?.title}");
    if (news != null) {
      Navigator.push(context, CupertinoPageRoute(builder: (context) => Covid19NewsPanel(covid19news: news,)));
    }
  }

  void _onTapNewsCardStar(Covid19News news) {
    Analytics.instance.logSelect(target: "Favorite: Covid-19 News");
    User().switchFavorite(news);
  }

  Widget _buildStayInformed() {
    return _StayInformed();
  }

  Widget _buildNews() {
    List<Covid19News> newsList;
    if (AppCollection.isCollectionNotEmpty(_covid19News)) {
      Covid19News firstNews = _covid19News.first;
      newsList = List.from(_covid19News); // Create copy so that we can modify it.
      if (firstNews != null) {
        newsList.remove(firstNews);
      }
    }
    return Padding(padding: EdgeInsets.only(top: 24), child: SectionTitlePrimary(
        title: Localization().getStringEx("panel.covid19.news.title", 'COVID-19 News'),
        iconPath: 'images/icon-news.png',
        children: _buildNewsItems(newsList)),);
  }

  List<Widget> _buildNewsItems(List<Covid19News> newsList) {
    List<Widget> widgets = List();
    if (_newsLoading) {
      widgets.add(CircularProgressIndicator());
    } else if (AppCollection.isCollectionNotEmpty(newsList)) {
      newsList.forEach((news) {
        widgets.add(Covid19NewsCard(news: news,));
      });
    }
    return widgets;
  }

  Widget _buildResources() {
    return Covid19Resources();
  }


  Widget _buildFaq() {
    return Column(
        children:[
          _buildFAQTitle(),
          Semantics(explicitChildNodes: true, child:
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child:Column(children: _constructFaqContent(),
        )))]);
  }

  List<Widget> _constructFaqContent(){
    List<Widget> widgets = new List();
    List<Covid19FAQSection> faqSections = _faq?.sections;

    if (_faqLoading) {
      widgets.add(Container(height: 10,));
      widgets.add(CircularProgressIndicator());
      return widgets;
    }

    widgets.add(_buildFAQDescription());
    if (AppCollection.isCollectionNotEmpty(faqSections)) {
      faqSections.forEach((Covid19FAQSection section) {
        widgets.add(_buildFAQSectionWidget(section));
        widgets.add(Container(height: 1,));
      });
      widgets.add(Container(height: 32,));
    }
    return widgets;
  }

  Widget _buildGeneralInfo(){
    List<Widget> widgets = List();
    List<Covid19FAQEntry> faqGeneralEntries= _faq?.general;
    if(AppCollection.isCollectionNotEmpty(faqGeneralEntries)) {
      faqGeneralEntries.forEach((entry) {
        TextStyle titleStyle = TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.extraBold, color: Styles().colors.textBackground);
        TextStyle descriptionStyle = TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground);
        widgets.add(_buildGeneralFaqEntry(entry, titleStyle, descriptionStyle));
      });
      widgets.add(Container(height: 32,));
      return Container(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child:Column(children: widgets,));
    }

    return Container();
  }

  Widget _buildFAQSectionWidget(Covid19FAQSection section) {
    final Animatable<double> _halfTween = Tween<double>(begin: 0.0, end: 0.5);
    final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);
    AnimationController _controller = AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _animationControllers.add(_controller);
    Animation<double> _iconTurns = _controller.drive(_halfTween.chain(_easeInTween));

    return Container(color: Styles().colors.fillColorPrimary,
        child: Theme(data: ThemeData(accentColor: Styles().colors.white,
            dividerColor: Colors.white,
            backgroundColor: Styles().colors.white,
            textTheme: TextTheme(subtitle1: TextStyle(color: Styles().colors.white, fontFamily: Styles().fontFamilies.bold, fontSize: 16))),
            child: ExpansionTile(
              title:
              Semantics(label: section.title,
              hint: Localization().getStringEx("panel.covid19.faq.question.hint","Double tap to show questions"),/*+(expanded?"Hide" : "Show ")+" questions",*/
              excludeSemantics:true,child:
              Container(child: Text(section.title, style: TextStyle(color: Styles().colors.white, fontFamily: Styles().fontFamilies.bold, fontSize: 16),))),
              backgroundColor: Styles().colors.fillColorPrimary,
              trailing: RotationTransition(
                  turns: _iconTurns,
                  child: Icon(Icons.arrow_drop_down, color: Styles().colors.white,)),
              children: _buildFagSectionEntries(section.questions),
              onExpansionChanged: (bool expand) {
                Analytics.instance.logSelect(target: "FAQ question:" + section?.title);
                if (expand) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
            )));
  }

  List<Widget> _buildFagSectionEntries(List<Covid19FAQEntry> questions) {
    List<Widget> widgets = List();
    if (AppCollection.isCollectionNotEmpty(questions)) {
      questions.forEach((Covid19FAQEntry entry) {
        TextStyle titleStyle = TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.bold, color: Styles().colors.fillColorPrimary);
        TextStyle descriptionStyle = TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground);
        Widget faqQuestionEntry = Container(
          padding: EdgeInsets.only(top: 16, left: 16, right: 16), color: Styles().colors.white, child: _buildGeneralFaqEntry(entry, titleStyle, descriptionStyle,question: true),);
        widgets.add(faqQuestionEntry);
      });
    }
    widgets.add(Container(height: 16, color: Styles().colors.white,));
    return widgets;
  }

  Widget _buildFAQTitle(){
    String title=Localization().getStringEx('panel.covid19.faq.title',"FAQ");
    String label=Localization().getStringEx('panel.covid19.faq.title.label',"Frequently asked questions");
    return Container(
        color: Styles().colors.fillColorPrimary,
        padding: EdgeInsets.only(left: 16, top: 20, right: 16, bottom: 20),
        child: Semantics(label:label, header: true, excludeSemantics: true, child:Row(
            children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Image.asset(
                "images/icon-news.png"),
        ),
        Text(
          title,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontFamily: Styles().fontFamilies.extraBold),
    )])));
  }

  Widget _buildFAQDescription(){
    String description = Localization().getStringEx('panel.covid19.faq.description',"Answers to your most common questions:");
    DateTime time =_faq?.dateUpdated;
    if(time==null)
      return Container();
    
    String formatedTimeText = AppDateTime().formatDateTime(time,format: "MMMM dd, yyyy");
    String updateTime = sprintf(Localization().getStringEx('panel.covid19.faq.update.text',"Updated %s"), [formatedTimeText]);
    return
    Semantics(container: true,child:Container(child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
      Padding(padding: EdgeInsets.only(top: 20),
          child: Text(description, style: TextStyle(fontSize: 20, fontFamily: Styles().fontFamilies.extraBold, color: Styles().colors.fillColorPrimary),)),
      Padding(padding: EdgeInsets.only(top: 5,bottom: 24),
        child: Text(updateTime, overflow: TextOverflow.ellipsis,
          maxLines: 20,
          style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),),),
    ])));
  }

  Widget _buildGeneralFaqEntry(Covid19FAQEntry entry, TextStyle titleStyle, TextStyle descriptionStyle,{bool question = false}) {
    if (entry == null) {
      return Container();
    }
    return Semantics(inMutuallyExclusiveGroup:true,container: true,child:Container(child:
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
//      Semantics(label:question? Localization().getStringEx('panel.covid19.faq.question.label',"Question: ") : " . ", child:
      Text(AppString.getDefaultEmptyString(value: entry.title),
        style: titleStyle,),
//    ),
//        Semantics(label: question? Localization().getStringEx('panel.covid19.faq.answer.label',"Answer: "): " . ", child:
      Padding(padding: EdgeInsets.only(top: 12),
        child: Html(data: AppString.getDefaultEmptyString(value: entry.description),
          defaultTextStyle: descriptionStyle,
          onLinkTap: (url) => _onLinkTap(url),),)
//    ),
    ])));
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
}

class Covid19Resources extends StatefulWidget {

  _Covid19ResourcesState createState() => _Covid19ResourcesState();
}

class _Covid19ResourcesState extends State<Covid19Resources> {

  List<Covid19Resource> _contentResources;

  bool _isLoading = false;

  @override
  void initState() {
    _loadContentResources();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadContentResources(){
    _isLoading = true;
    Health().loadCovid19Resources().then((List<Covid19Resource> contentResources){
      if(mounted) {
        _contentResources = contentResources;
      }
    }).whenComplete((){
      if(mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  Widget _buildCovidResource(BuildContext context, Covid19Resource resource) {
    GestureTapCallback onTap = () => _onTapResourcse(context, resource);

    return GestureDetector(
      onTap: onTap,
      child: Semantics(button: true,
        hint:  Localization().getStringEx("panel.covid19.resources.poor_accessibility.hint", "This link takes you to a website outside of the Safer Illinois app"),
        child:Container(
        decoration: BoxDecoration(
          color: Styles().colors.white,
        ),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                resource.title,
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.bold,
                  color: Styles().colors.fillColorPrimary,
                  fontSize: 16
                ),
              ),
            ),
            Image.asset('images/external-link.png')
          ],
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {

    List<Widget> rows = List();
    if(_isLoading){
      rows.add(Center(child: CircularProgressIndicator(),));
    }
    else {
      for (Covid19Resource resource in _contentResources) {
        Widget widget = _buildCovidResource(context, resource);
        if (widget != null) {
          if(rows.isNotEmpty){
            rows.add(Container(height: 1, color: Styles().colors.lightGray,));
          }
          rows.add(widget);
        }
      }
    }

    return Column(
      children: <Widget>[
        SectionTitlePrimary(
          title: Localization().getStringEx(
              'widget.home_campus_tools.label.campus_tools',
              'Campus Resources'),
          iconPath: 'images/campus-tools.png',
          children: [
            Container(
              decoration: BoxDecoration(
                  border: Border.all(color: Styles().colors.lightGray, width: 1),
                  borderRadius: BorderRadius.all(Radius.circular(4.0)),
                  boxShadow: [BoxShadow(color: Styles().colors.fillColorPrimaryTransparent015, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(0, 2))]
              ),
              child: Column(
                children: rows,
              ),
            )
          ],
        ),
        Container(height: 48,),
      ],
    );
  }


  // Actions
  void _onTapResourcse(BuildContext context, Covid19Resource resource) {
    Analytics.instance.logSelect(target: resource.title);
    Navigator.push(context, CupertinoPageRoute(builder: (context)=>WebPanel(url: resource.link, title: resource.title,)));
  }
}

class _StayInformed extends StatefulWidget{
  _StayInformedState createState() => _StayInformedState();
}

class _StayInformedState extends State<_StayInformed>{

  @override
  Widget build(BuildContext context) {
    return
      Semantics(container: true ,child:
      Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(Localization().getStringEx("widget.covid19.stay_informed.title", "Stay Informed"),
            textAlign: TextAlign.left,
            style: TextStyle(
              fontFamily: Styles().fontFamilies.extraBold,
              fontSize: 24,
              color: Styles().colors.fillColorPrimary
            ),
          ),
          Text(Localization().getStringEx("widget.covid19.stay_informed.description", "Receive notifications from the campus as soon as they happen."),
            textAlign: TextAlign.left,
            style: TextStyle(
                fontFamily: Styles().fontFamilies.regular,
                fontSize: 16,
                color: Styles().colors.textBackground
            ),
          ),
          Container(height: 10,),
          Semantics(container: true, child:
          ToggleRibbonButton(
              borderRadius: BorderRadius.all(Radius.circular(5)),
              label: Localization().getStringEx("widget.covid19.stay_informed.button.enable_covid19_notifications.title", "Enable COVID-19 notifications"),
              toggled: FirebaseMessaging().notifyCovid19,
              context: context,
              onTap: _onToggleNotify)
          )
        ],
      ),
    ));
  }

  void _onToggleNotify(){
    Analytics.instance.logSelect(target: "Enable COVID-19 notifications");
    setState(() {
      FirebaseMessaging().notifyCovid19 = FirebaseMessaging().notifyCovid19;
    });
  }
}
