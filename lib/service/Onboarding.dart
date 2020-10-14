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
import 'package:illinois/service/NotificationService.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingConsentPanel.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingFinalPanel.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingHowItWorks.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingIntroPanel.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingQrCodePanel.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingResidentInfoPanel.dart';
import 'package:illinois/ui/health/onboarding/Covid19OnBoardingReviewScanPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingAuthBluetoothPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingLoginPhoneConfirmPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingGetStartedPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingAuthLocationPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingLoginNetIdPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingLoginPhonePanel.dart';
import 'package:illinois/ui/onboarding/OnboardingAuthNotificationsPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingRolesPanel.dart';
import 'package:illinois/ui/onboarding/OnboardingLoginPhoneVerifyPanel.dart';

class Onboarding {

  static const String notifyFinished  = "edu.illinois.rokwire.onboarding.finished";

  static const List<String> _contentPanels = [
    "OnboardingGetStartedPanel",
    
    "OnboardingAuthNotificationsPanel",
    "OnboardingAuthLocationPanel",
    "OnboardingAuthBluetoothPanel",
    
    "OnboardingRolesPanel",
    
    "OnboardingLoginNetIdPanel",

    "OnboardingLoginPhonePanel",
    "OnboardingLoginPhoneVerifyPanel",
    "OnboardingLoginPhoneConfirmPanel",

    "Covid19OnBoardingResidentInfoPanel",
    "Covid19OnBoardingReviewScanPanel",

    "Covid19OnBoardingIntroPanel",
    "Covid19OnBoardingHowItWorks",
    "Covid19OnBoardingConsentPanel",
    "Covid19OnBoardingQrCodePanel",
    "Covid19OnBoardingFinalPanel"
  ];

  // Singleton Factory

  Onboarding._internal();
  static final Onboarding _instance = Onboarding._internal();

  factory Onboarding() {
    return _instance;
  }

  Onboarding get instance {
    return _instance;
  }

  // Implementation

  Widget get startPanel {
    for (int index = 0; index < _contentPanels.length; index++) {
      OnboardingPanel nextPanel = _createPanel(name: _contentPanels[index], context: {});
      if ((nextPanel != null) && nextPanel.onboardingCanDisplay) {
        return nextPanel as Widget;
      }
    }
    return null;
  }

  Future<void> next(BuildContext context, OnboardingPanel panel, {bool replace = false}) async {
    dynamic nextPanel = await _nextPanel(panel);
    if (nextPanel is Widget) {
      if (replace) {
        Navigator.pushReplacement(context, CupertinoPageRoute(builder: (context) => nextPanel));
      }
      else {
        Navigator.push(context, CupertinoPageRoute(builder: (context) => nextPanel));
      }
    }
    else if ((nextPanel is bool) && !nextPanel) {
      finish(context);
    }
  }

  void finish(BuildContext context) {
    NotificationService().notify(notifyFinished, context);
  }

  Future<dynamic> _nextPanel(OnboardingPanel panel) async {
    int nextPanelIndex;
    if (panel == null) {
      nextPanelIndex = 0;
    }
    else {
      String panelName = panel.runtimeType.toString();
      int panelIndex = _contentPanels.indexOf(panelName);
      if (0 <= panelIndex) {
        nextPanelIndex = panelIndex + 1;
      }
    }

    if (nextPanelIndex != null) {
      while (nextPanelIndex < _contentPanels.length) {
        String nextPanelName = _contentPanels[nextPanelIndex];
        OnboardingPanel nextPanel = _createPanel(name: nextPanelName, context: panel?.onboardingContext ?? {});
        if ((nextPanel != null) && nextPanel.onboardingCanDisplay && await nextPanel.onboardingCanDisplayAsync) {
          return nextPanel as Widget;
        }
        else {
          nextPanelIndex++;
        }
      }
      return false;
    }
    return null;
  }

  OnboardingPanel _createPanel({String name, Map<String, dynamic> context}) {
    switch (name) {
      case "OnboardingGetStartedPanel": return OnboardingGetStartedPanel(onboardingContext: context);

      case "OnboardingAuthNotificationsPanel": return OnboardingAuthNotificationsPanel(onboardingContext: context);
      case "OnboardingAuthLocationPanel": return OnboardingAuthLocationPanel(onboardingContext: context);
      case "OnboardingAuthBluetoothPanel": return OnboardingAuthBluetoothPanel(onboardingContext: context);

      case "OnboardingRolesPanel": return OnboardingRolesPanel(onboardingContext: context);

      case "OnboardingLoginNetIdPanel": return OnboardingLoginNetIdPanel(onboardingContext: context);

      case "OnboardingLoginPhonePanel": return OnboardingLoginPhonePanel(onboardingContext: context);
      case "OnboardingLoginPhoneVerifyPanel": return OnboardingLoginPhoneVerifyPanel(onboardingContext: context);
      case "OnboardingLoginPhoneConfirmPanel": return OnboardingLoginPhoneConfirmPanel(onboardingContext: context);

      case "Covid19OnBoardingResidentInfoPanel": return Covid19OnBoardingResidentInfoPanel(onboardingContext: context);
      case "Covid19OnBoardingReviewScanPanel": return Covid19OnBoardingReviewScanPanel(onboardingContext: context);

      case "Covid19OnBoardingIntroPanel": return Covid19OnBoardingIntroPanel(onboardingContext: context);
      case "Covid19OnBoardingHowItWorks": return Covid19OnBoardingHowItWorks(onboardingContext: context);
      case "Covid19OnBoardingConsentPanel": return Covid19OnBoardingConsentPanel(onboardingContext: context);
      case "Covid19OnBoardingQrCodePanel": return Covid19OnBoardingQrCodePanel(onboardingContext: context);
      case "Covid19OnBoardingFinalPanel": return Covid19OnBoardingFinalPanel(onboardingContext: context);
    }
    return null;
  }
}

abstract class OnboardingPanel {
  
  Map<String, dynamic> get onboardingContext {
    return null;
  }
  
  bool get onboardingCanDisplay {
    return true;
  }

  Future<bool> get onboardingCanDisplayAsync async {
    return true;
  }
}