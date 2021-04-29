
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:url_launcher/url_launcher.dart';

class HealthWellnessCenterPanel extends StatelessWidget{

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles().colors.background,
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text(Localization().getStringEx("panel.covid19_wellness_center.header.title", "COVID-19 Wellness Center"),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                Localization().getStringEx("panel.covid19_wellness_center.label.description", "If you having issues with the app or getting a test result, contact the COVID Wellness Answer Center for assistance."),
                style: TextStyle(
                  fontFamily: Styles().fontFamilies.regular,
                  fontSize: 16,
                  color: Styles().colors.textSurface
                ),
              ),
              Container(height: 20,),
              RichText(
                textScaleFactor: MediaQuery.textScaleFactorOf(context),
                textAlign: TextAlign.start,
                text: TextSpan(
                  text: Localization().getStringEx("panel.covid19_wellness_center.label.email", "Email the Covid Wellness Answer Center at "),
                  style: TextStyle(
                      fontFamily: Styles().fontFamilies.regular,
                      fontSize: 16,
                      color: Styles().colors.textSurface
                  ),
                  children: [
                    TextSpan(
                      text: 'covidwellness@illinois.edu',
                      style: TextStyle(
                          fontFamily: Styles().fontFamilies.regular,
                          fontSize: 16,
                          color: Styles().colors.fillColorSecondary,
                          decoration: TextDecoration.underline,
                      ),
                      recognizer: TapGestureRecognizer()..onTap = ()=>onEmailTapped(),
                    ),
                  ]
                ),
              ),
              Container(height: 20,),
              RichText(
                textScaleFactor: MediaQuery.textScaleFactorOf(context),
                textAlign: TextAlign.start,
                text: TextSpan(
                    text: Localization().getStringEx("panel.covid19_wellness_center.label.phone", "Phone the Answer Center at "),
                    style: TextStyle(
                        fontFamily: Styles().fontFamilies.regular,
                        fontSize: 16,
                        color: Styles().colors.textSurface
                    ),
                    children: [
                      TextSpan(
                        text: '217 333-1900',
                        style: TextStyle(
                          fontFamily: Styles().fontFamilies.regular,
                          fontSize: 16,
                          color: Styles().colors.fillColorSecondary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()..onTap = ()=>onCallTapped(),
                      ),
                    ]
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void onEmailTapped(){
    launch('mailto:covidwellness@illinois.edu');
  }

  void onCallTapped(){
    launch('tel:+12173331900');
  }
}