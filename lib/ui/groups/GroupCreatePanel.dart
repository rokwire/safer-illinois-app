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

import 'dart:collection';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:illinois/model/Groups.dart';
import 'package:illinois/service/Groups.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';

class GroupCreatePanel extends StatefulWidget {
  _GroupCreatePanelState createState() => _GroupCreatePanelState();
}

class _GroupCreatePanelState extends State<GroupCreatePanel> {
  final _groupTitleController = TextEditingController();

  Group _group;

  LinkedHashSet<String> _groupsNames;

  bool _nameIsValid = true;
  bool _groupNamesLoading = false;
  bool _groupCategoeriesLoading = false;
  bool _creating = false;
  bool get _loading => _groupCategoeriesLoading || _groupNamesLoading;

  @override
  void initState() {
    _group = Group();
    _initGroupNames();
    super.initState();
  }

  //Init
  void _initGroupNames(){
    _groupNamesLoading = true;
    Groups().loadGroups().then((groups){
      _groupsNames = groups?.map((group) => group?.title?.toLowerCase()?.trim())?.toSet();
    }).catchError((error){
      print(error);
    }).whenComplete((){
      setState(() {
        _groupNamesLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(
          children: <Widget>[
            _loading
            ? Expanded(child:
                Center(child:
                  Container(
                    child: Align(alignment: Alignment.center,
                      child: SizedBox(height: 24, width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), )
                      ),
                    ),
                  ),
                )
              )
            : Expanded(
              child: Container(
                color: Colors.white,
                child: CustomScrollView(
                  scrollDirection: Axis.vertical,
                  slivers: <Widget>[
                    SliverHeaderBar(
                      context: context,
                      backIconRes: "images/close-white.png",
                      titleWidget: Text(
                        Localization().getStringEx("panel.groups_create.label.heading", "Create a group"),
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildListDelegate([
                        Container(
                          color: Styles().colors.background,
                          child: Column(children: <Widget>[
                            _buildNameField(),
                            _buildNameError(),
                            Container(height: 24,),
                        ],),)

                      ]),
                    ),
                  ],
                ),
              ),
            ),
            _buildButtonsLayout(),
          ],
        ),
        backgroundColor: Styles().colors.background);
  }

  //Name
  Widget _buildNameField() {
    String title = Localization().getStringEx("panel.groups_create.name.title", "NAME YOUR GROUP");
    String fieldTitle = Localization().getStringEx("panel.groups_create.name.field", "NAME FIELD");
    String fieldHint = Localization().getStringEx("panel.groups_create.name.field.hint", "");

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
         _buildSectionTitle(title,null),
          Container(
            height: 48,
            padding: EdgeInsets.only(left: 12,right: 12, top: 12, bottom: 16),
            decoration: BoxDecoration(border: Border.all(color: Styles().colors.fillColorPrimary, width: 1),color: Styles().colors.white),
            child: Semantics(
                label: fieldTitle,
                hint: fieldHint,
                textField: true,
                excludeSemantics: true,
                child: TextField(
                  controller: _groupTitleController,
                  onChanged: onNameChanged,
                  decoration: InputDecoration(border: InputBorder.none,),
                  style: TextStyle(color: Styles().colors.textBackground, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
                )),
          ),
        ],
      ),

    );
  }

  Widget _buildNameError(){
    String errorMessage = Localization().getStringEx("panel.groups_create.name.error.message", "A group with this name already exists. Please try a different name.");

    return Visibility(visible: !_nameIsValid,
        child: Container( padding: EdgeInsets.only(left:16, right:16,top: 6),
          child:Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
              color: Styles().colors.fillColorSecondaryVariant,
              border: Border.all(
                  color: Styles().colors.fillColorSecondary,
                  width: 1),
              borderRadius:
              BorderRadius.all(Radius.circular(4))),
            child: Row(
              children: <Widget>[
                Image.asset('images/warning-orange.png'),
                Expanded(child:
                    Container(
                        padding: EdgeInsets.only(left: 12, right: 4),
                        child:Text(errorMessage,
                              style: TextStyle(color: Styles().colors.textBackground, fontSize: 14, fontFamily: Styles().fontFamilies.regular))
                ))
              ],
            ),
        )
    ));
  }

  //Buttons
  Widget _buildButtonsLayout() {
    return
      Stack(alignment: Alignment.center, children: <Widget>[
        Container( color: Styles().colors.white,
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Center(
            child: ScalableRoundedButton(
              label: Localization().getStringEx("panel.groups_create.button.create.title", "Create Group"),
              backgroundColor: Colors.white,
              borderColor: Styles().colors.fillColorSecondary,
              textColor: Styles().colors.fillColorPrimary,
              onTap: _onCreateTap,
            ),
          )
          ,),
        Visibility(visible: _creating,
          child: Container(
            child: Align(alignment: Alignment.center,
              child: SizedBox(height: 24, width: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorPrimary), )
              ),
            ),
          ),
        ),
      ],);
  }

  void _onCreateTap(){
    setState(() {
      _creating = true;
    });
    Groups().createGroup(_group).then((detail){
      if(detail!=null){
        //ok
        setState(() {
          _creating = false;
        });

        Navigator.pop(context);
      }
    }).catchError((_){
      //error
      setState(() {
        _creating = false;
      });
    });
  }
  //
  // Common
  Widget _buildSectionTitle(String title, String description){
    return Container(
      padding: EdgeInsets.only(bottom: 8, top:16),
      child:
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
        Semantics(
          label: title,
          hint: title,
          header: true,
          excludeSemantics: true,
          child:
          Text(
            title,
            style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 12, fontFamily: Styles().fontFamilies.bold),
          ),
        ),
        description==null? Container():
            Container(
              padding: EdgeInsets.only(top: 2),
              child: Text(
                description,
                style: TextStyle(color: Styles().colors.textBackground, fontSize: 14, fontFamily: Styles().fontFamilies.regular),
              ),
            )
      ],)
    );
  }

  /*Widget _buildTitle(String title, String iconRes){
    return
      Container(
        padding: EdgeInsets.only(left: 16),
        child:
          Semantics(
            label: title,
            hint: title,
            header: true,
            excludeSemantics: true,
            child:
            Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Image.asset(iconRes, color: Styles().colors.fillColorSecondary,),
              Expanded(child:
              Container(
                  padding: EdgeInsets.only(left: 14, right: 4),
                  child:Text(
                    title,
                    style: TextStyle(color: Styles().colors.fillColorPrimary, fontSize: 16, fontFamily: Styles().fontFamilies.bold,),
                  )
              ))
      ],)));
  }*/

  void onNameChanged(String name){
    _group.title = name;
     validateName(name);
  }

  void validateName(String name){
    LinkedHashSet<String> takenNames = _groupsNames ?? [];
    setState(() {
      _nameIsValid = !(takenNames?.contains(name?.toLowerCase()?.trim())??false);
    });
  }
}
