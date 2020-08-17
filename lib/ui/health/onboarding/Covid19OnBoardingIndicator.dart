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

import 'package:flutter/material.dart';
import 'package:illinois/service/Localization.dart';
import 'package:illinois/service/Styles.dart';

class Covid19OnBoardingIndicator extends StatelessWidget {
  final double progress;

  Covid19OnBoardingIndicator({@required this.progress});

  @override
  Widget build(BuildContext context) {
    return Padding(padding: EdgeInsets.only(left: 2, right: 2, top: 2),
        child: LinearProgressIndicator(
          value: progress, valueColor: AlwaysStoppedAnimation<Color>(Styles().colors.fillColorSecondary), backgroundColor: Styles().colors.surfaceAccent,
          semanticsLabel: Localization().getStringEx("widget.health.onboarding.indicator9.label.hint","Covid-19 Onboarding process"),),);
  }
}
