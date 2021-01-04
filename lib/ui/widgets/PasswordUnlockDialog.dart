

import 'package:flutter/material.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class PasswordUnlockDialog extends StatefulWidget{

  _PasswordUnlockDialogState createState() => _PasswordUnlockDialogState();
}

class _PasswordUnlockDialogState extends State<PasswordUnlockDialog>{

  bool _isLoadingPrivateKey = false;

  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    _passwordFocusNode.dispose();
    _passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setStateEx){
        return ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(8)),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
                child:Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Styles().colors.fillColorPrimary,
                              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Center(
                                      child: Text(
                                        Localization().getStringEx("panel.health.covid19.qr_code.dialog.load_from_server_password.title", "Load my COVID-19 Secret from server"),
                                        style: TextStyle(fontSize: 20, color: Colors.white),
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
                        Localization().getStringEx("panel.health.covid19.qr_code.dialog.load_from_server_password.description", "Please enter your password that you used last time to encrypt the secret"),

                        textAlign: TextAlign.left,
                        style: TextStyle(fontFamily: Styles().fontFamilies.medium, fontSize: 16, color: Colors.black),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextField(
                        controller: _passwordController,
                        focusNode: _passwordFocusNode,
                        textAlign: TextAlign.center,
                        obscureText: true,
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.black, width: 1.0)
                            )
                        ),
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
                            child: Stack(
                              alignment: Alignment.center,
                              children: <Widget>[
                                ScalableRoundedButton(
                                    onTap: () => _onConfirmLoadFromServer(context, setStateEx),
                                    backgroundColor: Colors.transparent,
                                    borderColor: Styles().colors.fillColorSecondary,
                                    textColor: Styles().colors.fillColorPrimary,
                                    label: Localization().getStringEx("panel.health.covid19.qr_code.dialog.button.load_from_server_password.title", "Load from server")),
                                _isLoadingPrivateKey ? Center(child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary),)) : Container()
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
            ),
          ),
        );
      },
    );
  }

  void _onConfirmLoadFromServer(BuildContext context, Function setStateEx){
    setStateEx(() {
      _isLoadingPrivateKey = true;
    });

    Health().decryptUserPrivateKey(_passwordController.text).then((_) {
      if (mounted) {
        setStateEx((){
          _isLoadingPrivateKey = false;
        });

        if(Health().isUserLoggedIn && Health().hasPrivateKey) {
          Navigator.pop(context, true);
        }
        else {
          AppAlert.showDialogResult(context, Localization().getStringEx("panel.health.covid19.qr_code.dialog.load_from_server_password.error", "Unable to load the secret. Please revise the password or use another option to restore your secret"));
        }
      }
    });
  }
}