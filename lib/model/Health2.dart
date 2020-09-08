
import 'package:illinois/model/Health.dart';
import 'package:illinois/service/AppDateTime.dart';
import 'package:illinois/service/Auth.dart';

///////////////////////////////
// HealthRulesSet2

class HealthRulesSet2 {
  final HealthTestRulesSet2 tests;
  final HealthSymptomsRulesSet2 symptoms;
  final HealthContactTraceRulesSet2 contactTrace;
  final HealthActionRulesSet2 actions;
  final HealthDefaultsSet2 defaults;

  HealthRulesSet2({this.tests, this.symptoms, this.contactTrace, this.actions, this.defaults});

  factory HealthRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRulesSet2(
      tests: HealthTestRulesSet2.fromJson(json['tests']),
      symptoms: HealthSymptomsRulesSet2.fromJson(json['symptoms']),
      contactTrace: HealthContactTraceRulesSet2.fromJson(json['contact_trace']),
      actions: HealthActionRulesSet2.fromJson(json['actions']),
      defaults: HealthDefaultsSet2.fromJson(json['defaults']),
    ) : null;
  }
}

///////////////////////////////
// HealthDefaultsSet2

class HealthDefaultsSet2 {
  final _HealthRuleStatus2 status;

  HealthDefaultsSet2({this.status});

  factory HealthDefaultsSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthDefaultsSet2(
      status: _HealthRuleStatus2.fromJson(json['status']),
    ) : null;
  }
}



///////////////////////////////
// HealthTestRulesSet2

class HealthTestRulesSet2 {
  final List<HealthTestRule2> rules;
  final Map<String, _HealthRuleStatus2> statuses;

  HealthTestRulesSet2({this.rules, this.statuses});

  factory HealthTestRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRulesSet2(
      rules: HealthTestRule2.listFromJson(json['rules']),
      statuses: _HealthRuleStatus2.mapFromJson(json['statuses']),
    ) : null;
  }

  HealthTestRuleResult2 matchRuleResult({ Covid19HistoryBlob blob }) {
    if ((rules != null) && (blob != null)) {
      for (HealthTestRule2 rule in rules) {
        if ((rule?.testType != null) && (rule?.testType?.toLowerCase() == blob?.testType?.toLowerCase()) && (rule.results != null)) {
          for (HealthTestRuleResult2 ruleResult in rule.results) {
            if ((ruleResult?.testResult != null) && (ruleResult.testResult.toLowerCase() == blob?.testResult?.toLowerCase())) {
              return ruleResult;
            }
          }
        }
      }
    }
    return null;
  }
}


///////////////////////////////
// HealthTestRule2

class HealthTestRule2 {
  final String testType;
  final String category;
  final List<HealthTestRuleResult2> results;

  HealthTestRule2({this.testType, this.category, this.results});

  factory HealthTestRule2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRule2(
      testType: json['test_type'],
      category: json['category'],
      results: HealthTestRuleResult2.listFromJson(json['results']),
    ) : null;
  }

  static List<HealthTestRule2> listFromJson(List<dynamic> json) {
    List<HealthTestRule2> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthTestRule2.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }
}

///////////////////////////////
// HealthTestRuleResult2

class HealthTestRuleResult2 {
  final String testResult;
  final String category;
  final _HealthRuleStatus2 status;

  HealthTestRuleResult2({this.testResult, this.category, this.status});

  factory HealthTestRuleResult2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRuleResult2(
      testResult: json['result'],
      category: json['category'],
      status: _HealthRuleStatus2.fromJson(json['status']),
    ) : null;
  }

  static List<HealthTestRuleResult2> listFromJson(List<dynamic> json) {
    List<HealthTestRuleResult2> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthTestRuleResult2.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static HealthTestRuleResult2 matchRuleResult(List<HealthTestRuleResult2> results, { Covid19HistoryBlob blob }) {
    if (results != null) {
      for (HealthTestRuleResult2 result in results) {
        if (result._matchBlob(blob)) {
          return result;
        }
      }
    }
    return null;
  }

  bool _matchBlob(Covid19HistoryBlob blob) {
    return ((testResult != null) && (testResult.toLowerCase() == blob?.testResult?.toLowerCase()));
  }
}

///////////////////////////////
// HealthSymptomsRulesSet2

class HealthSymptomsRulesSet2 {
  final List<HealthSymptomsRule2> rules;
  final List<HealthSymptomsGroup> groups;

  HealthSymptomsRulesSet2({this.rules, this.groups});

  factory HealthSymptomsRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRulesSet2(
      rules: HealthSymptomsRule2.listFromJson(json['rules']),
      groups: HealthSymptomsGroup.listFromJson(json['groups']),
    ) : null;
  }

  HealthSymptomsRule2 matchRule({ Covid19HistoryBlob blob }) {
    if ((rules != null) && (groups != null) && (blob?.symptomsIds != null)) {
     Map<String, int> counts = HealthSymptomsGroup.getCounts(groups, blob.symptomsIds);
      for (HealthSymptomsRule2 rule in rules) {
        if (rule._matchCounts(counts)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthSymptomsRule2

class HealthSymptomsRule2 {
  final Map<String, _HealthRuleIntValue2> counts;
  final _HealthRuleStatus2 status;
  
  HealthSymptomsRule2({this.counts, this.status});

  factory HealthSymptomsRule2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRule2(
      counts: _countsFromJson(json['counts']),
      status: _HealthRuleStatus2.fromJson(json['status']),
    ) : null;
  }

  static List<HealthSymptomsRule2> listFromJson(List<dynamic> json) {
    List<HealthSymptomsRule2> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthSymptomsRule2.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  static Map<String, _HealthRuleIntValue2> _countsFromJson(Map<String, dynamic> json) {
    Map<String, _HealthRuleIntValue2> values;
    if (json != null) {
      values = Map<String, _HealthRuleIntValue2>();
      json.forEach((key, value) {
        values[key] = _HealthRuleIntValue2.fromJson(value);
      });
    }
    return values;
  }

  bool _matchCounts(Map<String, int> testCounts) {
    if (this.counts != null) {
      for (String groupName in this.counts.keys) {
        _HealthRuleIntValue2 value = this.counts[groupName];
        int count = (testCounts != null) ? testCounts[groupName] : null;
        if (!value.match(count)) {
          return false;
        }

      }
    }
    return true;
  }
}

///////////////////////////////
// HealthContactTraceRulesSet2

class HealthContactTraceRulesSet2 {
  final List<HealthContactTraceRule2> rules;

  HealthContactTraceRulesSet2({this.rules});

  factory HealthContactTraceRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRulesSet2(
      rules: HealthContactTraceRule2.listFromJson(json['rules']),
    ) : null;
  }

  HealthContactTraceRule2 matchRule({ Covid19HistoryBlob blob }) {
    if ((rules != null) && (blob != null)) {
      for (HealthContactTraceRule2 rule in rules) {
        if (rule._matchBlob(blob)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthContactTraceRule2

class HealthContactTraceRule2 {
  final _HealthRuleIntValue2 duration;
  final _HealthRuleStatus2 status;

  HealthContactTraceRule2({this.duration, this.status});

  factory HealthContactTraceRule2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRule2(
      duration: _HealthRuleIntValue2.fromJson(json['duration']),
      status: _HealthRuleStatus2.fromJson(json['status']),
    ) : null;
  }

  static List<HealthContactTraceRule2> listFromJson(List<dynamic> json) {
    List<HealthContactTraceRule2> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthContactTraceRule2.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  bool _matchBlob(Covid19HistoryBlob blob) {
    return (duration != null) && duration.match(blob?.traceDurationInMinutes);
  }
}

///////////////////////////////
// HealthActionRulesSet2

class HealthActionRulesSet2 {
  final List<HealthActionRule2> rules;

  HealthActionRulesSet2({this.rules});

  factory HealthActionRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthActionRulesSet2(
      rules: HealthActionRule2.listFromJson(json['rules']),
    ) : null;
  }

  HealthActionRule2 matchRule({ Covid19HistoryBlob blob }) {
    if (rules != null) {
      for (HealthActionRule2 rule in rules) {
        if (rule._matchBlob(blob)) {
          return rule;
        }
      }
    }
    return null;
  }
}

///////////////////////////////
// HealthActionRule2

class HealthActionRule2 {
  final String type;
  final _HealthRuleStatus2 status;

  HealthActionRule2({this.type, this.status});

  factory HealthActionRule2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthActionRule2(
      type: json['type'],
      status: _HealthRuleStatus2.fromJson(json['status']),
    ) : null;
  }

  static List<HealthActionRule2> listFromJson(List<dynamic> json) {
    List<HealthActionRule2> values;
    if (json != null) {
      values = [];
      for (dynamic entry in json) {
          try { values.add(HealthActionRule2.fromJson((entry as Map)?.cast<String, dynamic>())); }
          catch(e) { print(e?.toString()); }
      }
    }
    return values;
  }

  bool _matchBlob(Covid19HistoryBlob blob) {
    return (type != null) && (type.toLowerCase() == blob?.actionType?.toLowerCase());
  }
}

///////////////////////////////
// _HealthRuleIntValue2

abstract class _HealthRuleIntValue2 {
  _HealthRuleIntValue2();
  
  factory _HealthRuleIntValue2.fromJson(dynamic json) {
    if (json != null) {
      if (json is int) {
        return HealthRuleIntValue2.fromJson(json);
      }
      else if (json is Map) {
        return HealthRuleIntInterval2.fromJson(json.cast<String, dynamic>());
      }
    }
    return null;
  }

  bool match(int value);
  int get min;
  int get max;
  int get scope;
}

///////////////////////////////
// HealthRuleIntValue2

class HealthRuleIntValue2 extends _HealthRuleIntValue2 {
  final int value;
  
  HealthRuleIntValue2({this.value});

  factory HealthRuleIntValue2.fromJson(dynamic json) {
    return (json is int) ? HealthRuleIntValue2(value: json) : null;
  }

  bool match(int value) {
    return (this.value == value);
  }

  int get min { return value; }
  int get max { return value; }
  int get scope { return null; }
}

///////////////////////////////
// HealthRuleIntInterval2

class HealthRuleIntInterval2 extends _HealthRuleIntValue2 {
  final int min;
  final int max;
  final int scope;
  
  HealthRuleIntInterval2({this.min, this.max, this.scope});

  factory HealthRuleIntInterval2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleIntInterval2(
      min: json['min'],
      max: json['max'],
      scope: _scopeFromJson(json['scope']),
    ) : null;
  }

  bool match(int value) {
    return (value != null) &&
      ((min == null) || (min <= value)) &&
      ((max == null) || (max >= value));
  }

  static int _scopeFromJson(dynamic value) {
    if (value is String) {
      if (value == 'future') {
        return 1;
      }
      else if (value == 'past') {
        return -1;
      }
    }
    else if (value is int) {
      if (0 < value) {
        return 1;
      }
      else if (value < 0) {
        return -1;
      }
    }
    return null;
  }
}

///////////////////////////////
// _HealthRuleStatus2

abstract class _HealthRuleStatus2 {
  
  _HealthRuleStatus2();
  
  factory _HealthRuleStatus2.fromJson(dynamic json) {
    if (json is Map) {
      if (json['condition'] != null) {
        try { return HealthTestRuleConditionalStatus2.fromJson(json.cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      }
      else {
        try { return HealthRuleStatus2.fromJson(json.cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      }
    }
    else if (json is String) {
      return HealthRuleReferenceStatus2.fromJson(json);
    }
    return null;
  }

  static Map<String, _HealthRuleStatus2> mapFromJson(Map<String, dynamic> json) {
    Map<String, _HealthRuleStatus2> result;
    if (json != null) {
      result = Map<String, _HealthRuleStatus2>();
      json.forEach((String key, dynamic value) {
        try { result[key] =  _HealthRuleStatus2.fromJson((value as Map).cast<String, dynamic>()); }
        catch (e) { print(e?.toString()); }
      });
    }
    return result;
  }

  HealthRuleStatus2 eval({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules });
}

///////////////////////////////
// HealthRuleStatus2

class HealthRuleStatus2 extends _HealthRuleStatus2 {
  final String healthStatus;
  final int priority;

  final String nextStep;
  final String nextStepHtml;
  final int nextStepInterval;

  final String reason;
  final String warning;

  HealthRuleStatus2({this.healthStatus, this.priority, this.nextStep, this.nextStepHtml, this.nextStepInterval, this.reason, this.warning });

  factory HealthRuleStatus2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleStatus2(
      healthStatus: json['health_status'],
      priority: json['priority'],
      nextStep: json['next_step'],
      nextStepHtml: json['next_step_html'],
      nextStepInterval: json['next_step_interval'],
      reason: json['reason'],
      warning: json['warning'],
    ) : null;
  }

  HealthRuleStatus2 eval({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    return this;
  }

  bool canUpdateStatus({Covid19StatusBlob blob}) {
    int blobStatusWeight = covid19HealthStatusWeight(blob?.healthStatus);
    int newStatusWeight =  (this.healthStatus != null) ? covid19HealthStatusWeight(this.healthStatus) : blobStatusWeight;
    if (blobStatusWeight < newStatusWeight) {
      // status downgrade
      return true;
    }
    else {
      // status upgrade or preserve
      int blobStatusPriority = blob?.priority ?? 0;
      int newStatusPriority = this.priority ?? 0;
      return (newStatusPriority < 0) || (blobStatusPriority <= newStatusPriority);
    }
  }

  DateTime nextStepDateUtc(DateTime startDateUtc) {
    return ((startDateUtc != null) && (nextStepInterval != null)) ?
       startDateUtc.add(Duration(days: nextStepInterval)) : null;
  }
}

///////////////////////////////
// HealthRuleRefrenceStatus2

class HealthRuleReferenceStatus2 extends _HealthRuleStatus2 {
  final String reference;
  HealthRuleReferenceStatus2({this.reference});

  factory HealthRuleReferenceStatus2.fromJson(String json) {
    return (json != null) ? HealthRuleReferenceStatus2(
      reference: json,
    ) : null;
  }

  HealthRuleStatus2 eval({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    // Only test rules currently use reference status.
    _HealthRuleStatus2 status = rules?.tests?.statuses[reference];
    return status?.eval(history: history, historyIndex: historyIndex, rules: rules);
  }
}

///////////////////////////////
// HealthRuleConditionalStatus2

class HealthTestRuleConditionalStatus2 extends _HealthRuleStatus2 {
  final String condition;
  final Map<String, dynamic> params;
  final _HealthRuleStatus2 successStatus;
  final _HealthRuleStatus2 failStatus;

  HealthTestRuleConditionalStatus2({this.condition, this.params, this.successStatus, this.failStatus});

  factory HealthTestRuleConditionalStatus2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRuleConditionalStatus2(
      condition: json['condition'],
      params: json['params'],
      successStatus: _HealthRuleStatus2.fromJson(json['success']) ,
      failStatus: _HealthRuleStatus2.fromJson(json['fail']),
    ) : null;
  }

  HealthRuleStatus2 eval({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    _HealthRuleStatus2 result;
    if (condition == 'require-test') {
      result = _evalRequireTest(history: history, historyIndex: historyIndex, rules: rules);
    }
    else if (condition == 'require-symptoms') {
      result = _evalRequireSymptoms(history: history, historyIndex: historyIndex, rules: rules);
    }
    else if (condition == 'test-user') {
      result = _evalTestUser(history: history, historyIndex: historyIndex, rules: rules);
    }
    else if (condition == 'timeout') {
      result = _evalTimeout(history: history, historyIndex: historyIndex, rules: rules);
    }
    return result?.eval(history: history, historyIndex: historyIndex, rules: rules);
  }

  _HealthRuleStatus2 _evalRequireTest({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    
    Covid19History historyEntry = ((history != null) && (historyIndex != null) && (0 <= historyIndex) && (historyIndex < history.length)) ? history[historyIndex] : null;
    DateTime historyDateMidnightLocal = historyEntry?.dateMidnightLocal;
    if (historyDateMidnightLocal == null) {
      return null;
    }
    
    _HealthRuleIntValue2 interval = _HealthRuleIntValue2.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    dynamic category = params['category'];
    if (category is List) {
      category = Set.from(category);
    }

    int scope = interval.scope ?? 0;
    if (0 < scope) { // check only newer items than the current
      for (int index = historyIndex - 1; 0 <= index; index--) {
        if (_evalRequireTestEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval, rules: rules, category: category)) {
          return successStatus;
        }
      }
    }
    else if (0 < scope) { // check only older items than the current
      for (int index = historyIndex + 1; index < history.length; index++) {
        if (_evalRequireTestEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval, rules: rules, category: category)) {
          return successStatus;
        }
      }
    }
    else { // check all history items
      for (int index = 0; index < history.length; index++) {
        if ((index != historyIndex) && _evalRequireTestEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval, rules: rules, category: category)) {
          return successStatus;
        }
      }
    }

    // If positive time interval is not already expired - do not return failed status yet.
    _HealthRuleIntValue2 currentInterval = _HealthRuleIntValue2.fromJson(params['current_interval']);
    if ((currentInterval != null) && _evalCurrentIntervalFulfills(currentInterval, historyDateMidnightLocal: historyDateMidnightLocal)) {
      return successStatus;
    }

    return failStatus;
  }

  static bool _evalRequireTestEntryFulfills(Covid19History entry, { DateTime historyDateMidnightLocal,  _HealthRuleIntValue2 interval, HealthRulesSet2 rules, dynamic category }) {
    if (entry.isTest && entry.canTestUpdateStatus) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      final difference = entryDateMidnightLocal.difference(historyDateMidnightLocal).inDays;
      if (interval.match(difference)) {
        if (category == null) {
          return true; // any test matches
        }
        else {
          HealthTestRuleResult2 entryRuleResult = rules?.tests?.matchRuleResult(blob: entry?.blob);
          if ((entryRuleResult != null) && (entryRuleResult.category != null) &&
              (((category is String) && (category == entryRuleResult.category)) ||
                ((category is Set) && category.contains(entryRuleResult.category))))
          {
            return true; // only tests from given category matches
          }
        }
      }
    }
    return false;
  }

  _HealthRuleStatus2 _evalRequireSymptoms({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    Covid19History historyEntry = ((history != null) && (historyIndex != null) && (0 <= historyIndex) && (historyIndex < history.length)) ? history[historyIndex] : null;
    DateTime historyDateMidnightLocal = historyEntry?.dateMidnightLocal;
    if (historyDateMidnightLocal == null) {
      return null;
    }

    _HealthRuleIntValue2 interval = _HealthRuleIntValue2.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    int scope = interval.scope ?? 0;
    if (0 < scope) { // check only newer items than the current
      for (int index = historyIndex - 1; 0 <= index; index--) {
        if (_evalRequireSymptomsEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval)) {
          return successStatus;
        }
      }
    }
    else if (0 < scope) { // check only older items than the current
      for (int index = historyIndex + 1; index < history.length; index++) {
        if (_evalRequireSymptomsEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval)) {
          return successStatus;
        }
      }
    }
    else { // check all history items
      for (int index = 0; index < history.length; index++) {
        if ((index != historyIndex) && _evalRequireSymptomsEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval)) {
          return successStatus;
        }
      }
    }

    // If positive time interval is not already expired - do not return failed status yet.
    _HealthRuleIntValue2 currentInterval = _HealthRuleIntValue2.fromJson(params['current_interval']);
    if ((currentInterval != null) && _evalCurrentIntervalFulfills(currentInterval, historyDateMidnightLocal: historyDateMidnightLocal)) {
      return successStatus;
    }

    return failStatus;
  }

  static bool _evalRequireSymptomsEntryFulfills(Covid19History entry, { DateTime historyDateMidnightLocal,  _HealthRuleIntValue2 interval }) {
    if (entry.isSymptoms) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      final difference = entryDateMidnightLocal.difference(historyDateMidnightLocal).inDays;
      if (interval.match(difference)) {
        return true;
      }
    }
    return false;
  }

  _HealthRuleStatus2 _evalTestUser({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    dynamic roles = params['roles'];
    if ((roles != null) && !_matchUserRoles(roles: roles)) {
      return failStatus;
    }
    return successStatus;
  }

  static bool _matchUserRoles({dynamic roles}) {
    String userRole = Auth().authCard?.role?.toLowerCase();
    if (userRole != null) {
      if (roles is String) {
        return roles.toLowerCase() == userRole;
      }
      else if (roles is List) {
        for (dynamic role in roles) {
          if ((role is String) && (role.toLowerCase() == userRole)) {
            return true;
          }
        }
      }
    }
    return false;
  }

  _HealthRuleStatus2 _evalTimeout({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    Covid19History historyEntry = ((history != null) && (historyIndex != null) && (0 <= historyIndex) && (historyIndex < history.length)) ? history[historyIndex] : null;
    DateTime historyDateMidnightLocal = historyEntry?.dateMidnightLocal;
    if (historyDateMidnightLocal == null) {
      return null;
    }

    _HealthRuleIntValue2 interval = _HealthRuleIntValue2.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    return _evalCurrentIntervalFulfills(interval, historyDateMidnightLocal: historyDateMidnightLocal) ?
      failStatus : successStatus; // while current time is within interval 'timeout' condition fails
  }

  static bool _evalCurrentIntervalFulfills(_HealthRuleIntValue2 currentInterval, { DateTime historyDateMidnightLocal } ) {
    if (currentInterval != null) {
      final difference = AppDateTime.todayMidnightLocal.difference(historyDateMidnightLocal).inDays;
      if (currentInterval.match(difference)) {
        return true;
      }
    }
    return false;
  }


}

