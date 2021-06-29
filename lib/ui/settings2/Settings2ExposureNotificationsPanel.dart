

import 'package:flutter/material.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RibbonButton.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

class Settings2ExposureNotificationsPanel extends StatefulWidget{
  Settings2ExposureNotificationsPanel();
  _Settings2ExposureNotificationsPanelState createState() => _Settings2ExposureNotificationsPanelState();
}

class _Settings2ExposureNotificationsPanelState extends State<Settings2ExposureNotificationsPanel> implements NotificationsListener{

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
            'Exposure Notificaitons',
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
                Text('If you opt in to exposure notifications, you allow your phone to send an anonymous Bluetooth signal to nearby Safer Illinois app users who are also using this feature. Your phone will receive and record a signal from their phones as well. If one of those users tests positive for COVID-19 in the next 14 days, the app will alert you to your potential exposure and advise you on next steps.\n\nYour identity and health status will remain anonymous, as will the identity and health status of all other users.',
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
                      label: "I opt in to participate in the Exposure Notification System (requires Bluetooth to be ON)",
                      style: TextStyle(
                          color: Styles().colors.fillColorPrimary,
                          fontFamily: Styles().fontFamilies.medium,
                          fontSize: 14
                      ),
                      height: null,
                      border: Border.all(width: 1, color: Styles().colors.surfaceAccent),
                      borderRadius: BorderRadius.all(Radius.circular(4)),
                      toggled: Health().user.consentExposureNotification,
                      onTap: (){
                        if(!Health().user.consentExposureNotification){
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
                                  "Exposure Notifications",
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
                  "By opting out of exposure notifications, your phone will no longer send and recieve anonymous Bluetooth signals to alert you or others of potential exposure to COVID-19.",
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
                            Analytics.instance.logAlert(text: "Remove My Information", selection: "No");
                            Navigator.pop(context);
                          },
                          backgroundColor: Colors.transparent,
                          borderColor: Styles().colors.fillColorPrimary,
                          textColor: Styles().colors.fillColorPrimary,
                          label: Localization().getStringEx("panel.profile_info.dialog.remove_my_information.no.title", "No")),
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
                              label: 'Opt-Out'),
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
    Health().loginUser(consentExposureNotification: false).whenComplete((){
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
    Health().loginUser(consentExposureNotification: true).whenComplete((){
      setState((){
        _isEnabling = false;
      });
    });
  }

  @override
  void onNotification(String name, param) {
    if(name == Health.notifyUserUpdated){
      setState(() {

      });
    }
  }
}