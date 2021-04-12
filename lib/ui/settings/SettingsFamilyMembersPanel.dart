import 'package:flutter/material.dart';
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/Health.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class SettingsFamilyMembersPanel extends StatefulWidget {

  @override
  _SettingsFamilyMembersPanelState createState() => _SettingsFamilyMembersPanelState();
}

class _SettingsFamilyMembersPanelState extends State<SettingsFamilyMembersPanel> implements NotificationsListener {

  bool _refreshing;

  @override
  void initState() {
    super.initState();
    NotificationService().subscribe(this, [
      Health.notifyFamilyMembersChanged,
    ]);
    
    _refreshing = true;
    Health().refreshFamilyMembers().then((_) {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
        
        NotificationService().notify(Health.notifyCheckPendingFamilyMember);
      }
    });
  }

  @override
  void dispose() {
    NotificationService().unsubscribe(this);
    super.dispose();
  }

  // NotificationsListener

  @override
  void onNotification(String name, dynamic param) {
    if (name == Health.notifyFamilyMembersChanged) {
      if (mounted && (_refreshing != true)) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Styles().colors.background,
      appBar: SimpleHeaderBarWithBack(context: context,
        titleWidget: Text(Localization().getStringEx('panel.settings.family_members.heading.title', 'Family Members'),
          style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),),),
      body: SafeArea(child: //_buildContent()
        Stack(children: [
          _buildContent(),
          _buildProgress()
        ],),
      )
    );
  }

  Widget _buildContent() {
    if (Health().familyMembers == null) {
      return _buildStatusText(Localization().getStringEx('panel.settings.family_members.label.load_failed', 'Failed to load family members'));
    }
    else if (Health().familyMembers.length == 0) {
      return _buildStatusText(Localization().getStringEx('panel.settings.family_members.label.empty', 'No family members'));
    }
    else {
      return _buildMembers();
    }
  }

  Widget _buildProgress() {
    return Visibility(visible: (_refreshing == true), child:
      Padding(padding: EdgeInsets.all(30), child:
        Column(children: [
          Expanded(flex: 1, child: Container()),
          Align(alignment: Alignment.center, child:
            CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), strokeWidth: 3,),
          ),
          Expanded(flex: 2, child: Container()),
        ],),
      ),
    );
  }

  Widget _buildStatusText(String statusText) {
    return Padding(padding: EdgeInsets.all(30), child:
      Column(children: [
        Expanded(flex: 1, child: Container()),
        Text(statusText, textAlign: TextAlign.center, style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20, fontFamily: Styles().fontFamilies.bold),),
        Expanded(flex: 2, child: Container()),
      ],)
    );
  }

  Widget _buildMembers() {
    List<Widget> content = <Widget>[];
    for (HealthFamilyMember member in Health().familyMembers) {
      content.add(Padding(padding: EdgeInsets.only(top: content.isNotEmpty ? 8 : 0), child: _FamilyMemberWidget(member: member),));
    }
    return SingleChildScrollView(child: 
      Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 32), child:
        Column(children: content),
      ),);
  }

}

class _FamilyMemberWidget extends StatefulWidget {
  final HealthFamilyMember member;
  _FamilyMemberWidget({this.member});
  
  @override
  _FamilyMemberWidgetState createState() => _FamilyMemberWidgetState();
}

class _FamilyMemberWidgetState extends State<_FamilyMemberWidget> {

  bool _buttonsEnabled = true;
  bool _hasProgress = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String status;
    List<Widget> buttons = <Widget>[];
    if (widget.member.isAcepted) {
      status = Localization().getStringEx('panel.settings.family_members.label.status.accepted', 'ACCEPTED');
      buttons.add(_buildCommandButton(Localization().getStringEx('panel.settings.family_members.button.revoke.title', 'Revoke'), _onRevoke));
    }
    else if (widget.member.isRevoked) {
      status = Localization().getStringEx('panel.settings.family_members.label.status.revoked', 'REVOKED');
      buttons.add(_buildCommandButton(Localization().getStringEx('panel.settings.family_members.button.accept.title', 'Accept'), _onAccept));
    }
    else if (widget.member.isPending) {
      status = Localization().getStringEx('panel.settings.family_members.label.status.pending', 'PENDING');
      buttons.addAll(<Widget>[
        _buildCommandButton(Localization().getStringEx('panel.settings.family_members.button.accept.title', 'Accept'), _onAccept),
        Container(width: 8,),
        _buildCommandButton(Localization().getStringEx('panel.settings.family_members.button.revoke.title', 'Revoke'), _onRevoke),
      ]);
    }
    else {
      status = widget.member.status?.toUpperCase() ?? Localization().getStringEx('panel.settings.family_members.label.status.unknown', 'UNKNOWN');
    }

    buttons.addAll(<Widget>[
      Expanded(child: Container()),
      _buildProgress(),
    ]);


    return Container(
      decoration: BoxDecoration(
        color: Styles().colors.white,
        borderRadius: BorderRadius.all(Radius.circular(4)),
        boxShadow: [BoxShadow(color: Styles().colors.blackTransparent018, spreadRadius: 2.0, blurRadius: 6.0, offset: Offset(2, 2))],),
      child: Stack(children: [
        Visibility(visible: (status != null), child: 
          Align(alignment: Alignment.topRight, child:
            Padding(padding: EdgeInsets.only(top: 8, right: 8), child:
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: Styles().colors.fillColorPrimary, borderRadius: BorderRadius.all(Radius.circular(2)),),
                child: Text(status ?? '', style: TextStyle(color: Styles().colors.textColorPrimary, fontSize: 12, fontFamily: Styles().fontFamilies.bold),),    
              ),
            ),
          ),
        ),
        Padding(padding: EdgeInsets.all(12), child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(widget.member.applicantFullName ?? '', style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 20, fontFamily: Styles().fontFamilies.bold),),
              Text(widget.member.applicantEmailOrPhone ?? '', style: TextStyle(color: Styles().colors.fillColorPrimaryVariant, fontSize: 16, fontFamily: Styles().fontFamilies.medium),),
              Padding(padding: EdgeInsets.only(top: 8), child:
                Row(mainAxisAlignment: MainAxisAlignment.start, children: buttons),
              ),
            ],),
        ),
      ],)
    );
  }

  Widget _buildCommandButton(String title, handler) {
    return Stack(children: <Widget>[
        RoundedButton(
          label: title,
          hint: '',
          fontSize: 18,
          height: 42,
          padding: EdgeInsets.symmetric(horizontal: 12),
          textColor: _buttonsEnabled ? Styles().colors.fillColorPrimary : Styles().colors.surfaceAccent,
          borderColor: _buttonsEnabled ? Styles().colors.fillColorPrimary : Styles().colors.surfaceAccent,
          backgroundColor: Styles().colors.surface,
          onTap: handler,
        ),
    ]);
  }

  Widget _buildProgress() {
    return Visibility(visible: (_hasProgress == true), child:
      Container(width: 42, height: 42, child:
        Center(child: 
          Container(width: 21, height: 21, child:
            CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary)),
          ),
        ),
      ),
    );
  }


  void _onAccept() {
    _submit(HealthFamilyMember.StatusAccepted);
  }

  void _onRevoke() {
    _submit(HealthFamilyMember.StatusRevoked);
  }

  void _submit(String status) {
    setState(() {
      _hasProgress = true;
      _buttonsEnabled = false;
    });
    Health().applyFamilyMemberStatus(widget.member, status).then((dynamic result) {
      if (mounted) {
        if (result == true) {
          setState(() {
            _hasProgress = false;
            _buttonsEnabled = true;
            widget.member.status = status;
          });
        }
        else {
          setState(() {
            _hasProgress = false;
          });
          String errorMessage = (result is String) ? result : Localization().getStringEx('panel.settings.family_members.label.submit_failed', 'Failed to update status');
          AppAlert.showDialogResult(context, errorMessage).then((_) {
            setState(() {
              _buttonsEnabled = true;
            });
          });
        }
      }
    });
  }
}