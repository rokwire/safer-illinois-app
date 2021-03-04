
import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:sprintf/sprintf.dart';

class SettingsPendingFamilyMemberPanel extends StatefulWidget {
  final HealthFamilyMember pendingMember;

  SettingsPendingFamilyMemberPanel({this.pendingMember});

  @override
  _SettingsPendingFamilyMemberPanelState createState() => _SettingsPendingFamilyMemberPanelState();
}

class _SettingsPendingFamilyMemberPanelState extends State<SettingsPendingFamilyMemberPanel> {

  bool _hasProgress = false;
  bool _buttonsEnabled = true;
  String _errorMessage;
  HealthRulesSet _rules;

  @override
  void initState() {
    Health().loadRules2().then((HealthRulesSet rules) {
      if (mounted) {
        setState(() {
          _rules = rules;
        });
      }
    });
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    return Scaffold(backgroundColor: Styles().colors.fillColorPrimary.withOpacity(0.3), body:
      SafeArea(child:
        Padding(padding: EdgeInsets.only(left: screenWidth / 12, right: screenWidth / 12, top: kToolbarHeight), child:
          Column(children: [
            Expanded(flex: 1, child: Container()),
            Container(decoration: BoxDecoration(color: Styles().colors.fillColorPrimary, border:Border.all(color: Styles().colors.fillColorSecondary, width: 1)), child:
              Stack(children: <Widget>[
                _buildContent(),
                Container(alignment: Alignment.topRight, child: _buildCloseButton()),
                Container(alignment: Alignment.center, padding: EdgeInsets.only(top: 96), child: _buildProgressIndicator()),
              ]),
            ),
            Expanded(flex: 2, child: Container()),
          ],),
    )));
  }

  Widget _buildContent() {
    String statement1Text = sprintf(Localization().getStringEx('panel.health.covid19.pending_family_member.label.text.statement1', '%s seeks your authorization to participate in Shield CU COVID-19 testing.'), [widget.pendingMember.applicantFullName]);
    String statement2Text = sprintf(Localization().getStringEx('panel.health.covid19.pending_family_member.label.text.statement2', 'If you approve, your University account will be billed %s for each test taken.'), [_rules?.familyMemberTestPrice ?? '\$xx']);

    TextStyle textStyle = TextStyle(color: Styles().colors.textColorPrimary, fontFamily: Styles().fontFamilies.bold, fontSize: 18);
    TextStyle errorTextStyle = TextStyle(color: Colors.yellow, fontFamily: Styles().fontFamilies.regular, fontSize: 16);

    List<Widget> statements = <Widget>[
      Text(statement1Text, style: textStyle, ),
      Container(height: 18),
      Text(statement2Text, style: textStyle, ),
    ];

    if (_errorMessage != null) {
      statements.addAll(<Widget>[
        Container(height: 9),
        Text(_errorMessage, style: errorTextStyle, ),
        Container(height: 9),
      ]);
    }
    else {
      statements.add(
        Container(height: 18),
      );
    }

    return Padding(padding: EdgeInsets.all(20), child:
      Column(crossAxisAlignment: CrossAxisAlignment.start, children:<Widget>[
        Padding(padding: EdgeInsets.only(right: 10), child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children:
            statements
          ),
        ),
        Align(alignment: Alignment.center, child: 
          Wrap(runSpacing: 8, spacing: 12, children: <Widget>[
            _buildCommandButton(Localization().getStringEx('panel.health.covid19.pending_family_member.button.approve.title', 'I Approve'), _onApprove),
            _buildCommandButton(Localization().getStringEx('panel.health.covid19.pending_family_member.button.disapprove.title', 'I Disapprove'), _onDisapprove),
          ]),
        ),
    ]));
  }

  Widget _buildCloseButton() {
    return Semantics(label: Localization().getStringEx('dialog.close.title', 'Close'), button: true, excludeSemantics: true, child:
      InkWell(onTap : _onClose, child:
        Container(width: 48, height: 48, alignment: Alignment.center, child:
          Image.asset('images/close-white.png')
    )));
  }

  Widget _buildCommandButton(String title, handler) {
    return Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      RoundedButton(
        label: title,
        hint: '',
        fontSize: 18,
        padding: EdgeInsets.symmetric(horizontal: 12),
        textColor: _buttonsEnabled ? Styles().colors.fillColorPrimary : Styles().colors.surfaceAccent,
        borderColor: Styles().colors.fillColorSecondary,
        backgroundColor: Styles().colors.surface,
        onTap: handler,
      ),
    ]);
  }

  Widget _buildProgressIndicator() {
    return Visibility(visible: _hasProgress, child:
      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 3,));
  }

  void _onClose() {
    Navigator.of(context).pop(false);
  }

  void _onApprove() {
    _submit(HealthFamilyMember.StatusAccepted);
  }

  void _onDisapprove() {
    _submit(HealthFamilyMember.StatusRevoked);
  }

  void _submit(String status) {
    setState(() {
      _hasProgress = true;
      _buttonsEnabled = false;
      _errorMessage = (_errorMessage != null) ? '' : null;
    });
    Health().applyFamilyMemberStatus(widget.pendingMember, status).then((dynamic result) {
      if (mounted) {
        if (result == true) {
          setState(() {
            _hasProgress = false;
          });
          Navigator.of(context).pop(true);
        }
        else {
          setState(() {
            _hasProgress = false;
            _buttonsEnabled = true;
            _errorMessage = (result is String) ? result : Localization().getStringEx('panel.health.covid19.pending_family_member.label.text.error', 'Failed to submit.');
          });
        }
      }
    });
  }
}