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
import 'package:illinois/service/Analytics.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';

class GroupCreatePostPanel extends StatefulWidget{
  
  final String groupId;

  const GroupCreatePostPanel({Key key, this.groupId,}) : super(key: key);

  @override
  State<StatefulWidget> createState() => _GroupCreatePostPanelState();
}

class _GroupCreatePostPanelState extends State<GroupCreatePostPanel>{
  //Member _member;
  
  TextEditingController _postController = new TextEditingController();

  @override
  void initState() {
    _initMember();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  _initMember(){
    //_member = Groups().getUserMembership(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          Expanded(
              child: CustomScrollView(
                slivers: <Widget>[
                  SliverAppBar(pinned: true,
                    floating: true,
                    primary: true,
                    forceElevated: true,
                    centerTitle: true,
                    leading: Semantics(
                        label: Localization().getStringEx('headerbar.back.title', 'Back'),
                        hint: Localization().getStringEx('headerbar.back.hint', ''),
                        button: true,
                        excludeSemantics: true,
                        child: IconButton(
                            icon: Image.asset('images/icon-circle-close.png', excludeFromSemantics: true,),
                            onPressed: _onTapBack)),
                    title: Text(
                      Localization().getStringEx('panel.group_create_post.label.title', 'New Post'),
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0),
                    ),
                    actions: <Widget>[
                      Semantics(
                          label: Localization().getStringEx('panel.group_create_post.label.post', 'post'),
                          hint: Localization().getStringEx('panel.group_create_post.label.post.hint', ''),
                          button: true,
                          excludeSemantics: true,
                          child: InkWell(
                              child: Container(
                                alignment: Alignment.center,
                                padding: EdgeInsets.symmetric(horizontal: 15),
                                child: Text(Localization().getStringEx('panel.group_create_post.label.post', 'Post'),
                                  style: TextStyle(
                                    color: _postEnabled?Styles().colors.white : Styles().colors.disabledTextColorTwo,
                                      fontSize: 16,
                                      fontFamily: Styles().fontFamilies.semiBold,
                                      decoration: TextDecoration.underline,
                                      decorationColor: Styles().colors.fillColorSecondary,
                                      decorationThickness: 1,
                                      decorationStyle: TextDecorationStyle.solid
                                  ),)),
                              onTap: _onTapPost))
                    ],
                  ),
                  SliverList(
                    delegate: SliverChildListDelegate([
                      Semantics(
                        explicitChildNodes: true,
                        child: Column(
                          children: [
                            _buildPostField()
                          ],
                        ))
                    ]),
                  )
                ],
              )
          ),
        ],
      ),
      backgroundColor: Styles().colors.background,
    );
  }

  Widget _buildPostField(){
    String fieldTitle = Localization().getStringEx("panel.group_create_post.post.field.description", "Write a comment");
    String fieldHint = Localization().getStringEx("panel.group_create_post.post.field.hint", "");
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Semantics(
          label: fieldTitle,
          hint: fieldHint,
          textField: true,
          excludeSemantics: true,
          child: TextField(
            controller: _postController,
            maxLines: 64,
            decoration: InputDecoration(
              hintText: fieldTitle,
              border: InputBorder.none,),
            style: TextStyle(color: Styles().colors.textBackground, fontSize: 16, fontFamily: Styles().fontFamilies.regular),
            onChanged: (text){
              setState(() {});
            },
          )),
    );
  }

  void _onTapPost(){
    Analytics.instance.logSelect(target: "Post");
    
    if(_isPostValid) {


    } else {
      //Invalid post
    }
  }

  void _onTapBack() {
    Analytics.instance.logSelect(target: "Back");
    Navigator.pop(context);
  }

  bool get _isPostValid{
    return _postController?.text?.toString()?.isNotEmpty??false;
  }

  bool get _postEnabled{
    return _isPostValid;
  }
}