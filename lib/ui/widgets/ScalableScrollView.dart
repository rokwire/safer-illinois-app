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
import 'package:illinois/ui/onboarding/OnboardingHealthConsentPanel.dart';

class ScalableScrollView extends StatefulWidget{
  final Widget bottomNotScrollableWidget;
  final Widget scrollableChild;

  const ScalableScrollView({Key key, this.bottomNotScrollableWidget, this.scrollableChild}) : super(key: key);

  @override
  _ScalableScrollViewState createState() => _ScalableScrollViewState();
}

class _ScalableScrollViewState extends State<ScalableScrollView>{
  Size _bottomWidgetSize;
  Size _scrollableChildSize;

  @override
  Widget build(BuildContext context) {
    bool needScroll = _scrollableChildSize!=null && _bottomWidgetSize!=null ? (_scrollableChildSize.height + _bottomWidgetSize.height > MediaQuery.of(context).size.height): false;
    double scrollableHeight = MediaQuery.of(context).size.height  - (_bottomWidgetSize?.height??0) ;
    int bottomWidgetFlex = (_bottomWidgetSize?.height ?? 0) > 1? (_bottomWidgetSize?.height??1).round() : 0;
    int scrollableWidgetFlex = scrollableHeight > 0? (scrollableHeight?.round()??1) : 0;
    return Container(
        child:Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            needScroll?
              Flexible(
                flex: scrollableWidgetFlex,
                child: SingleChildScrollView(
                  child: _buildScrollContent(),
                )
              ) : _buildScrollContent(),
            needScroll? Container() : Expanded(child: Container(),),
            needScroll?
              Flexible(
                flex: bottomWidgetFlex,
                child: _buildBottomWidget()
              ) : _buildBottomWidget(),
          ],
        )
    );
  }

  Widget _buildScrollContent(){
    return MeasureSize(
        onChange: (Size size){
          if(_scrollableChildSize != size){
            setState(() {
              _scrollableChildSize = size;
            });
          }
        },
        child:widget.scrollableChild ?? Container());
  }

  Widget _buildBottomWidget(){
    return MeasureSize(
        onChange: (Size size){
          if(_bottomWidgetSize!=size) {
            setState(() {
              _bottomWidgetSize = size;
            });
          }
        },
        child:
        Column(
//            key: bottomWidgetKey,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children:[
              widget.bottomNotScrollableWidget ?? Container()
            ]
        )
    );
  }
}