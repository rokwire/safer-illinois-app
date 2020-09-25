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
import 'package:illinois/model/UserData.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/service/User.dart';
import 'package:illinois/ui/WebPanel.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/utils/Utils.dart';
import 'package:url_launcher/url_launcher.dart' as url_launcher;

class Covid19CareTeamPanel extends StatefulWidget {
  final Covid19Status status;

  Covid19CareTeamPanel({Key key, this.status}) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _Covid19CareTeamPanelState();
  }
}

class _Covid19CareTeamPanelState extends State<Covid19CareTeamPanel> with TickerProviderStateMixin{
  List<AnimationController> _animationControllers = List();
  //bool _moreInfoExpanded = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    if(_animationControllers!=null && _animationControllers.isNotEmpty){
      _animationControllers.forEach((controller){
        controller.dispose();
      });
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SimpleHeaderBarWithBack(
          context: context,
          titleWidget: Text(Localization().getStringEx("panel.health.covid19.care_team.heading.title", "Your Care Team"), style: TextStyle(color: Styles().colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),
        ),
        backgroundColor: Styles().colors.background,
        body: Container(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
              Semantics( container: true,
              child: Container(
              padding: EdgeInsets.symmetric(horizontal: 24),
              color: Styles().colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(height: 30,),
                  Text(Localization().getStringEx("panel.health.covid19.care_team.label.question", "We’re here to help."),textAlign: TextAlign.left, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20, fontFamily: Styles().fontFamilies.bold),),
                  Container(height: 8,),
                  Text(Localization().getStringEx("panel.health.covid19.care_team.label.description", "Reach out to someone on your COVID-19 care team - we're here to help."), style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.regular),),
                  Container(height: 23,),
                ],),)),
              Container(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(height: 23,),
                Semantics( container: true,
                child: Container(
                  child:Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(Localization().getStringEx("panel.health.covid19.care_team.label.emergency.text1", "In case of an emergency, "),textAlign: TextAlign.left, style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily:  Styles().fontFamilies.regular),),
                    Text(Localization().getStringEx("panel.health.covid19.care_team.label.emergency.text2", "always call 911."),textAlign: TextAlign.left, style: TextStyle(color: Styles().colors.textSurface, fontSize: 16, fontFamily: Styles().fontFamilies.bold),),
                  ],),),),
                Container(height: 16,),
                _buildActionsLayout(),
                Container(height: 26,),
                _buildMoreInfoLayout(),
                Container(height: 26,)
              ],),),

            ],),),
        ),
    );
  }

  Widget _buildActionsLayout() {
    return Container(
      child: Column(children: <Widget>[
        !_canMcKinley? Container():
        _buildAction(
          title: Localization().getStringEx("panel.health.covid19.care_team.team.title.mc_kinley", "Call McKinley Health"),
          description: Localization().getStringEx("panel.health.covid19.care_team.team.description.mc_kinley", "Reach out to someone on the “Dial a Nurse Line” to discuss your symptoms and options for clinical care."),
          contact: Localization().getStringEx("panel.health.covid19.care_team.team.contact.mc_kinley", "1-217-333-2700"),
          semanticContact: Localization().getStringEx("panel.health.covid19.care_team.team.semantic_contact.mc_kinley", "12173332700"),
          imageRes: "mc-kinley-gray.png"
        ),
        Container(height: 12,),
        _buildAction(
          description: Localization().getStringEx("panel.health.covid19.care_team.team.description.osf", "We’ve partnered with OSF HealthCare and its OSF OnCall Connect program and the Illinois Department of Healthcare and Family Services to support you getting through COVID-19. Call the Nurse Hotline at 1-833-OSF-KNOW (833-673-5669) to learn more about the program, which includes delivery of a care kit and digital visits to monitor you over a 16-day period."),
          contact: Localization().getStringEx("panel.health.covid19.care_team.team.contact.osf", "1-833-673-5669"),
          semanticContact: Localization().getStringEx("panel.health.covid19.care_team.team.semantic_contact.osf", "18336735669"),
          imageRes: "osf-logo-gray.png"
        )
      ],)
    );
  }

  Widget _buildAction({String title, String description, String imageRes, String contact, String semanticContact = ''}){
    bool _hasTitle = AppString.isStringNotEmpty(title);
    return Semantics( container: true,
    child: Container(
      decoration:  BoxDecoration(color: Styles().colors.white,
        borderRadius: BorderRadius.all(Radius.circular(4)), border: Border.all(color: Styles().colors.surfaceAccent,)),
      child: Column(children: <Widget>[
        Container(
        alignment: Alignment.centerLeft,
        padding: EdgeInsets.symmetric(horizontal: 16) ,
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(height: 10,),
          imageRes!=null ? Image.asset("images/"+imageRes, excludeFromSemantics: true,) : Container(),
          Visibility(visible:_hasTitle,
              child: Container(height: 6,)
          ),
          Visibility(visible:_hasTitle,
              child: Text(title??"",textAlign: TextAlign.left, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold),)
          ),
          Container(height: 6,),
          Text(description,textAlign: TextAlign.left, style: TextStyle(color: Styles().colors.textSurface, fontSize: 14, fontFamily: Styles().fontFamilies.regular),),
          Container(height: 14,),
          Container(color: Styles().colors.surfaceAccent, height: 1,),
        ],),),
        Semantics(explicitChildNodes: true,
        child: Container(child:
          Semantics(label: Localization().getStringEx("panel.health.covid19.care_team.label.call.hint","Call ") + semanticContact, button: true, excludeSemantics: true,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 22,vertical: 18),
            color: Styles().colors.surfaceAccent,
            child: InkWell(
              onTap:(){ _onTapContact(contact);},
              child:Row(children: <Widget>[
                Image.asset("images/icon-phone.png", excludeFromSemantics: true,),
                Container(width: 8,),
                Expanded(child:
                Text(contact,textAlign: TextAlign.left, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold),),
                ),
                Image.asset("images/chevron-right.png", excludeFromSemantics: true,),
            ],))
          )))),
      ],)
    ));
  }

  void _onTapContact(String contact) async{
    await url_launcher.launch("tel:"+contact);
  }

  Widget _buildMoreInfoLayout(){
    final Animatable<double> _halfTween = Tween<double>(begin: 0.0, end: 0.5);
    final Animatable<double> _easeInTween = CurveTween(curve: Curves.easeIn);
    AnimationController _controller = AnimationController(duration: Duration(milliseconds: 200), vsync: this);
    _animationControllers.add(_controller);
    Animation<double> _iconTurns = _controller.drive(_halfTween.chain(_easeInTween));

    return Container(
        decoration: BoxDecoration(color: Styles().colors.fillColorPrimary, borderRadius: BorderRadius.circular(4), border: Border.all(color: Styles().colors.surfaceAccent, width: 1)),
        child: Theme(data: ThemeData(accentColor: Styles().colors.white,
            dividerColor: Colors.white,
            backgroundColor: Styles().colors.white,
            textTheme: TextTheme(subtitle1: TextStyle(color: Styles().colors.white, fontFamily: Styles().fontFamilies.bold, fontSize: 16))),
            child: ExpansionTile(
              title:
              Semantics(label: Localization().getStringEx("panel.health.covid19.care_team.label.more_info.title", "More about the OSF OnCall Connect program"),
                  hint: Localization().getStringEx("panel.health.covid19.care_team.label.more_info.hint", "Double tap to show more info"),/*+(expanded?"Hide" : "Show ")+" questions",*/
                  excludeSemantics:true,child:
                  Container(child: Text(Localization().getStringEx("panel.health.covid19.care_team.label.more_info.title", "More about the OSF OnCall Connect program"), style: TextStyle(color: Styles().colors.white, fontFamily: Styles().fontFamilies.bold, fontSize: 16),))),
              backgroundColor: Styles().colors.fillColorPrimary,
              trailing: RotationTransition(
                  turns: _iconTurns,
                  child: Icon(Icons.arrow_drop_down, color: Styles().colors.white,)),
              children: [
                  Container(
                    color: Styles().colors.white,
                    padding: EdgeInsets.only(left: 13, right: 13, top: 20, bottom: 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(Localization().getStringEx("panel.health.covid19.care_team.label.more_info.description", "Members of the OSF OnCall Connect care team are trained OSF HealthCare Mission Partners who connect with you to provide support and work with you and health care providers as you recover from COVID-19, decreasing the risk of further exposure. OSF OnCall Connect team members check on you daily and should your condition worsen, you will be referred to the Acute COVID@Home program where you will receive monitoring equipment that allows us to evaluate your blood pressure, heart rate and pulse ox."),
                         style: TextStyle(color: Styles().colors.textSurface, fontSize: 14, fontFamily: Styles().fontFamilies.regular),),
                        GestureDetector(
                          onTap: _onLearnMoreTapped,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 0, right: 20, top: 20, bottom: 20),
                            child: Text(Localization().getStringEx("panel.health.covid19.care_team.label.more_info.link", "Learn more"),
                              style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 14, fontFamily: Styles().fontFamilies.bold, decoration: TextDecoration.underline),),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              onExpansionChanged: (bool expand) {
                Analytics.instance.logSelect(target: "More Info");
                if (expand) {
                  _controller.forward();
                } else {
                  _controller.reverse();
                }
              },
            )));
  }

  bool get _canMcKinley{
    return User().roles?.contains(UserRole.student) ?? false;
  }

  void _onLearnMoreTapped(){
    Navigator.push(context, CupertinoPageRoute(builder: (context)=>WebPanel(
      url: 'https://www.osfhealthcare.org/c/oncall-connect-uofi/?utm_source=student-app&utm_medium=app&utm_campaign=m-access-osf-oncall-connect-uofi',
    )));
  }
}