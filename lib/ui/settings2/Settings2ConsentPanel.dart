

import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

class Settings2ConsentPanel extends StatefulWidget{
  Settings2ConsentPanel();
  _Settings2ConsentPanelState createState() => _Settings2ConsentPanelState();
}

class _Settings2ConsentPanelState extends State<Settings2ConsentPanel> implements NotificationsListener{

  bool _isDisabling = false;
  bool _isEnabling = false;

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [Health.notifyUserUpdated]);
  }

  @override
  void dispose() {
    super.dispose();
    NotificationService().unsubscribe(this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: SimpleHeaderBarWithBack(
          context: context,
          titleWidget: Text(
            'Automatic Test Results',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: Styles().fontFamilies.extraBold,
              letterSpacing: 1.0,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(22),
            child: Column(
              children: <Widget>[
                Text('This feature allows you to receive COVID-19 test results from your healthcare provider directly in the app. Results are encrypted, so only you can see them.',
                  style: TextStyle(
                    color: Styles().colors.fillColorPrimary,
                    fontFamily: Styles().fontFamilies.regular,
                    fontSize: 16,
                  ),
                ),
                Container(height: 18,),
                Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ToggleRibbonButton(
                      label: "I consent to connect test results from my healthcare provider with the Safer Illinois app.",
                      style: TextStyle(
                          color: Styles().colors.fillColorPrimary,
                          fontFamily: Styles().fontFamilies.medium,
                          fontSize: 14
                      ),
                      height: null,
                      border: Border.all(width: 1, color: Styles().colors.surfaceAccent),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      toggled: Health().healthUser.consent,
                      onTap: (){
                        if(!Health().healthUser.consent){
                          _onConsentEnabled();
                        }
                        else{
                          showDialog(context: context, builder: (context) => _buildConsentDialog(context));
                        }
                      },
                    ),
                    _isEnabling ? Align(alignment: Alignment.center, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), strokeWidth: 2,)) : Container()
                  ],
                ),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildConsentDialog(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState){
        return Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(8.0))
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Styles().colors.fillColorPrimary,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(8))
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: Center(
                                child: Text(
                                  "Automatic Test Results",
                                  style: TextStyle(fontFamily: Styles().fontFamilies.bold, fontSize: 24, color: Colors.white),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                height: 30,
                                width: 30,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.all(Radius.circular(15)),
                                  border: Border.all(color: Styles().colors.white, width: 2),
                                ),
                                child: Center(
                                  child: Text(
                                    '\u00D7',
                                    style: TextStyle(
                                      fontSize: 24,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                height: 26,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Text(
                  "By removing your consent, you will no longer receive automatic test results from your health provider.\n\nPrevious test results will remain in your COVID-19 event history. You can delete them by accessing Your COVID-19 Event History in the Privacy Center.",
                  textAlign: TextAlign.left,
                  style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                ),
              ),
              Container(
                height: 26,
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: RoundedButton(
                          onTap: () {
                            Analytics.instance.logAlert(text: "Consent", selection: "No");
                            Navigator.pop(context);
                          },
                          backgroundColor: Colors.transparent,
                          borderColor: Styles().colors.fillColorPrimary,
                          textColor: Styles().colors.fillColorPrimary,
                          label: "No"),
                    ),
                    Container(
                      width: 10,
                    ),
                    Expanded(
                      child: Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          RoundedButton(
                              onTap: () => _onConsentDisabled(context, setState),
                              backgroundColor: Styles().colors.fillColorSecondaryVariant,
                              borderColor:  Styles().colors.fillColorSecondaryVariant,
                              textColor: Styles().colors.surface,
                              label: 'Remove Consent'),
                          _isDisabling ? Align(alignment: Alignment.center, child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), strokeWidth: 2,)) : Container()
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onConsentDisabled(BuildContext context, StateSetter _setState){
    if(_isDisabling){
      return;
    }
    _setState((){
      _isDisabling = true;
    });
    Health().loginUser(consent: false, exposureNotification: (Health()?.healthUser?.exposureNotification ?? false)).whenComplete((){
      _setState((){
        _isDisabling = false;
      });
      Navigator.pop(context);
    });
  }

  void _onConsentEnabled(){
    if(_isEnabling){
      return;
    }
    setState((){
      _isEnabling = true;
    });
    Health().loginUser(consent: true , exposureNotification: (Health()?.healthUser?.exposureNotification ?? false)).whenComplete((){
      setState((){
        _isEnabling = false;
      });
    });
  }

  @override
  void onNotification(String name, param) {
    if(name == Health.notifyUserUpdated){
      setState(() {});
    }
  }
}