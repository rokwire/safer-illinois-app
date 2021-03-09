
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html/style.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:sprintf/sprintf.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsPendingFamilyMemberPanel extends StatefulWidget {
  final HealthFamilyMember pendingMember;

  SettingsPendingFamilyMemberPanel({this.pendingMember});

  @override
  _SettingsPendingFamilyMemberPanelState createState() => _SettingsPendingFamilyMemberPanelState();
}

class _SettingsPendingFamilyMemberPanelState extends State<SettingsPendingFamilyMemberPanel> {

  bool _hasProgress = false;
  bool _buttonsEnabled = true;
  bool _termsAccepted = false;
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
    String termsText = Localization().getStringEx('panel.health.covid19.pending_family_member.label.text.terms.title', 'Terms and Conditions');
    String checkImageText = _termsAccepted ? '\u2611' : '\u2610';

    Color termsColor = Styles().colors.fillColorSecondary, errorColor = Colors.yellow;
    TextStyle textStyle = TextStyle(color: Styles().colors.textColorPrimary, fontFamily: Styles().fontFamilies.bold, fontSize: 18);
    TextStyle termsTextStyle = TextStyle(color: termsColor, fontFamily: Styles().fontFamilies.bold, fontSize: 18, decoration: TextDecoration.underline);
    TextStyle termsImageStyle = TextStyle(color: termsColor, fontFamily: Styles().fontFamilies.bold, fontSize: 28);
    TextStyle errorTextStyle = TextStyle(color: errorColor, fontFamily: Styles().fontFamilies.regular, fontSize: 16);

    List<Widget> statements = <Widget>[
      Text(statement1Text, style: textStyle, ),
      Container(height: 18),
      Text(statement2Text, style: textStyle, ),
      InkWell(onTap: _onTerms, child: Column(children:<Widget>[
        Container(height: 9),
        Row(children:<Widget>[
          Text(checkImageText, style: termsImageStyle),
          Container(width: 9,),
          Text(termsText, style: termsTextStyle),
        ] ),
        Container(height: 9),
      ],),),
    ];

    if (_errorMessage != null) {
      statements.addAll(<Widget>[
        Text(_errorMessage, style: errorTextStyle, ),
        Container(height: 9),
      ]);
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
        borderColor: _buttonsEnabled ? Styles().colors.fillColorSecondary : Styles().colors.surfaceAccent,
        backgroundColor: Styles().colors.surface,
        onTap: handler,
      ),
    ]);
  }

  Widget _buildProgressIndicator() {
    return Visibility(visible: _hasProgress, child:
      CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 3,));
  }

  Widget _buildTermsDialog(BuildContext context) {
    String termsHtml = Localization().getStringEx('panel.health.covid19.pending_family_member.label.text.terms.html', """
<p>The person named above has self-identified as a family or household member (“Family Member”) and has requested access to the COVID-19 testing services provided by the University of Illinois (“University”). By touching the “AGREE” button below, you agree that:</p>
<p>
1. You are a University employee currently eligible for COVID-19 testing by the University;<br>
2. Family Member is a family member in your household; and<br>
3. You are responsible for any unpaid fees incurred by Family Member in obtaining COVID-19 testing services from the University.
</p>
<p>You also agree that you are accepting responsibility on behalf of the Family Member if the Family Member is a minor under age 18 and you are the parent or legal guardian of the Family Member.</p>
<p>If you believe the person named above is improperly requesting access and/or has improperly obtained your University Identification Number (UIN), please contact [E-MAIL].</p>""");
    Style htmlStyle = Style(color: Styles().colors.fillColorPrimary, fontFamily: Styles().fontFamilies.bold, fontSize: FontSize(16));
    return ClipRRect(borderRadius: BorderRadius.all(Radius.circular(8)), child:
      Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8),), child:
        Stack(children: [
          Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16), child:
            SingleChildScrollView(child: 
              Html(data: termsHtml, style: { 'body': htmlStyle }, onLinkTap: (url) => launch(url)),
            ),
          ),
          Container(alignment: Alignment.topRight, height: 42, child: InkWell(onTap: _onCloseTerms, child: Container(width: 42, height: 42, alignment: Alignment.center, child: Image.asset('images/close-blue.png')))),
        ],),
      ),
    );

  }

  void _onTerms() {
    Analytics.instance.logSelect(target: "Terms");
    if (!_termsAccepted) {
      showDialog(context: context, builder: (context) => _buildTermsDialog(context) ).then((_) {
        setState(() {
          _termsAccepted = _buttonsEnabled = true;
        });
      });
    }
    setState(() {
      _termsAccepted = _buttonsEnabled = false;
    });
  }

  void _onCloseTerms() {
    Analytics.instance.logSelect(target: "Close Terms");
    Navigator.of(context).pop();
  }

  void _onClose() {
    Analytics.instance.logSelect(target: "Close");
    Navigator.of(context).pop(false);
  }

  void _onApprove() {
    Analytics.instance.logSelect(target: "Approve");
    _submit(HealthFamilyMember.StatusAccepted);
  }

  void _onDisapprove() {
    Analytics.instance.logSelect(target: "Disapprove");
    _submit(HealthFamilyMember.StatusRevoked);
  }

  void _submit(String status) {
    if (_buttonsEnabled) {
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
}