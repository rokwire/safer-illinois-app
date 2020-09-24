
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
  final Map<String, _HealthRuleStatus2> statuses;
  final Map<String, dynamic> constants;

  HealthRulesSet2({this.tests, this.symptoms, this.contactTrace, this.actions, this.defaults, this.statuses, Map<String, dynamic> constants}) :
    this.constants = constants ?? Map<String, dynamic>();

  factory HealthRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRulesSet2(
      tests: HealthTestRulesSet2.fromJson(json['tests']),
      symptoms: HealthSymptomsRulesSet2.fromJson(json['symptoms']),
      contactTrace: HealthContactTraceRulesSet2.fromJson(json['contact_trace']),
      actions: HealthActionRulesSet2.fromJson(json['actions']),
      defaults: HealthDefaultsSet2.fromJson(json['defaults']),
      statuses: _HealthRuleStatus2.mapFromJson(json['statuses']),
      constants: json['constants'],
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
  final List<HealthTestRule2> _rules;

  HealthTestRulesSet2({List<HealthTestRule2> rules}) : _rules = rules;

  factory HealthTestRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthTestRulesSet2(
      rules: HealthTestRule2.listFromJson(json['rules'])
    ) : null;
  }

  HealthTestRuleResult2 matchRuleResult({ Covid19HistoryBlob blob, HealthRulesSet2 rules }) {
    if ((_rules != null) && (blob != null)) {
      for (HealthTestRule2 rule in _rules) {
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
  final List<HealthSymptomsRule2> _rules;
  final List<HealthSymptomsGroup> groups;

  HealthSymptomsRulesSet2({List<HealthSymptomsRule2> rules, this.groups}) : _rules = rules;

  factory HealthSymptomsRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthSymptomsRulesSet2(
      rules: HealthSymptomsRule2.listFromJson(json['rules']),
      groups: HealthSymptomsGroup.listFromJson(json['groups']),
    ) : null;
  }

  HealthSymptomsRule2 matchRule({ Covid19HistoryBlob blob, HealthRulesSet2 rules }) {
    if ((_rules != null) && (groups != null) && (blob?.symptomsIds != null)) {
     Map<String, int> counts = HealthSymptomsGroup.getCounts(groups, blob.symptomsIds);
      for (HealthSymptomsRule2 rule in _rules) {
        if (rule._matchCounts(counts, rules: rules)) {
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
  final Map<String, _HealthRuleIntInterval2> counts;
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

  static Map<String, _HealthRuleIntInterval2> _countsFromJson(Map<String, dynamic> json) {
    Map<String, _HealthRuleIntInterval2> values;
    if (json != null) {
      values = Map<String, _HealthRuleIntInterval2>();
      json.forEach((key, value) {
        values[key] = _HealthRuleIntInterval2.fromJson(value);
      });
    }
    return values;
  }

  bool _matchCounts(Map<String, int> testCounts, { HealthRulesSet2 rules }) {
    if (this.counts != null) {
      for (String groupName in this.counts.keys) {
        _HealthRuleIntInterval2 value = this.counts[groupName];
        int count = (testCounts != null) ? testCounts[groupName] : null;
        if (!value.match(count, rules: rules)) {
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
  final List<HealthContactTraceRule2> _rules;

  HealthContactTraceRulesSet2({List<HealthContactTraceRule2> rules}) : _rules = rules;

  factory HealthContactTraceRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRulesSet2(
      rules: HealthContactTraceRule2.listFromJson(json['rules']),
    ) : null;
  }

  HealthContactTraceRule2 matchRule({ Covid19HistoryBlob blob, HealthRulesSet2 rules }) {
    if ((_rules != null) && (blob != null)) {
      for (HealthContactTraceRule2 rule in _rules) {
        if (rule._matchBlob(blob, rules: rules)) {
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
  final _HealthRuleIntInterval2 duration;
  final _HealthRuleStatus2 status;

  HealthContactTraceRule2({this.duration, this.status});

  factory HealthContactTraceRule2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthContactTraceRule2(
      duration: _HealthRuleIntInterval2.fromJson(json['duration']),
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

  bool _matchBlob(Covid19HistoryBlob blob, { HealthRulesSet2 rules }) {
    return (duration != null) && duration.match(blob?.traceDurationInMinutes, rules: rules);
  }
}

///////////////////////////////
// HealthActionRulesSet2

class HealthActionRulesSet2 {
  final List<HealthActionRule2> _rules;

  HealthActionRulesSet2({List<HealthActionRule2> rules}) : _rules = rules;

  factory HealthActionRulesSet2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthActionRulesSet2(
      rules: HealthActionRule2.listFromJson(json['rules']),
    ) : null;
  }

  HealthActionRule2 matchRule({ Covid19HistoryBlob blob, HealthRulesSet2 rules }) {
    if (_rules != null) {
      for (HealthActionRule2 rule in _rules) {
        if (rule._matchBlob(blob, rules: rules)) {
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

  bool _matchBlob(Covid19HistoryBlob blob, {HealthRulesSet2 rules}) {
    return (type != null) && (type.toLowerCase() == blob?.actionType?.toLowerCase());
  }
}

///////////////////////////////
// _HealthRuleIntInterval2

abstract class _HealthRuleIntInterval2 {
  _HealthRuleIntInterval2();
  
  factory _HealthRuleIntInterval2.fromJson(dynamic json) {
    if (json is int) {
      return HealthRuleIntValue2.fromJson(json);
    }
    else if (json is String) {
      return HealthRuleIntReference2.fromJson(json);
    }
    else if (json is Map) {
      return HealthRuleIntInterval2.fromJson(json.cast<String, dynamic>());
    }
    else {
      return null;
    }
  }

  bool match(int value, { HealthRulesSet2 rules });
  int  value({ HealthRulesSet2 rules });
  bool valid({ HealthRulesSet2 rules });
  int  scope({ HealthRulesSet2 rules });
  bool current({ HealthRulesSet2 rules });
}

///////////////////////////////
// HealthRuleIntValue2

class HealthRuleIntValue2 extends _HealthRuleIntInterval2 {
  final int _value;
  
  HealthRuleIntValue2({int value}) :
    _value = value;

  factory HealthRuleIntValue2.fromJson(dynamic json) {
    return (json is int) ? HealthRuleIntValue2(value: json) : null;
  }

  @override
  bool match(int value, { HealthRulesSet2 rules }) {
    return (_value == value);
  }

  @override int  value({ HealthRulesSet2 rules })   { return _value; }
  @override bool valid({ HealthRulesSet2 rules })   { return (_value != null); }
  @override int  scope({ HealthRulesSet2 rules })   { return null; }
  @override bool current({ HealthRulesSet2 rules }) { return null; }
}

///////////////////////////////
// HealthRuleIntInterval2

class HealthRuleIntInterval2 extends _HealthRuleIntInterval2 {
  final _HealthRuleIntInterval2 _min;
  final _HealthRuleIntInterval2 _max;
  final int _scope;
  final bool _current;
  
  HealthRuleIntInterval2({_HealthRuleIntInterval2 min, _HealthRuleIntInterval2 max, int scope, bool current}) :
    _min = min,
    _max = max,
    _scope = scope,
    _current = current;
    

  factory HealthRuleIntInterval2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleIntInterval2(
      min: _HealthRuleIntInterval2.fromJson(json['min']) ,
      max: _HealthRuleIntInterval2.fromJson(json['max']),
      scope: _scopeFromJson(json['scope']),
      current: json['current']
    ) : null;
  }

  @override
  bool match(int value, { HealthRulesSet2 rules }) {
    if (value != null) {
      if (_min != null) {
        int minValue = _min.value(rules: rules);
        if ((minValue == null) || (minValue > value)) {
          return false;
        }
      }
      if (_max != null) {
        int maxValue = _max.value(rules: rules);
        if ((maxValue == null) || (maxValue < value)) {
          return false;
        }
      }
      return true;
    }
    return false;
  }

  @override bool valid({ HealthRulesSet2 rules })   {
    return ((_min == null) || _min.valid(rules: rules)) &&
           ((_max == null) || _max.valid(rules: rules));
  }

  @override int  value({ HealthRulesSet2 rules }) { return null; }
  @override int  scope({ HealthRulesSet2 rules }) { return _scope; }
  @override bool current({ HealthRulesSet2 rules }) { return _current; }

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
// HealthRuleIntReference2

class HealthRuleIntReference2 extends _HealthRuleIntInterval2 {
  final String _reference;
  _HealthRuleIntInterval2 _referenceValue;

  HealthRuleIntReference2({String reference}) :
    _reference = reference;

  factory HealthRuleIntReference2.fromJson(dynamic json) {
    return (json is String) ? HealthRuleIntReference2(reference: json) : null;
  }

  _HealthRuleIntInterval2 referenceValue({ HealthRulesSet2 rules }) {
    if (_referenceValue == null) {
      dynamic value = (rules?.constants != null) ? rules.constants[_reference] : null;
      _referenceValue = _HealthRuleIntInterval2.fromJson(value);
    }
    return _referenceValue;
  }

  @override
  bool match(int value, { HealthRulesSet2 rules }) {
    return referenceValue(rules: rules)?.match(value, rules: rules) ?? false;
  }
  
  @override bool valid({ HealthRulesSet2 rules })   { return referenceValue(rules: rules)?.valid(rules: rules) ?? false; }
  @override int  value({ HealthRulesSet2 rules })   { return referenceValue(rules: rules)?.value(rules: rules); }
  @override int  scope({ HealthRulesSet2 rules })   { return referenceValue(rules: rules)?.scope(rules: rules); }
  @override bool current({ HealthRulesSet2 rules }) { return referenceValue(rules: rules)?.current(rules: rules); }
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
        try { result[key] =  _HealthRuleStatus2.fromJson(value); }
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
  final _HealthRuleIntInterval2 nextStepInterval;

  final String reason;
  final String warning;

  HealthRuleStatus2({this.healthStatus, this.priority, this.nextStep, this.nextStepHtml, this.nextStepInterval, this.reason, this.warning });

  factory HealthRuleStatus2.fromJson(Map<String, dynamic> json) {
    return (json != null) ? HealthRuleStatus2(
      healthStatus: json['health_status'],
      priority: json['priority'],
      nextStep: json['next_step'],
      nextStepHtml: json['next_step_html'],
      nextStepInterval: _HealthRuleIntInterval2.fromJson(json['next_step_interval']),
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

  DateTime nextStepDateUtc(DateTime startDateUtc, { HealthRulesSet2 rules }) {
    int numberOfDays = nextStepInterval?.value(rules: rules);
    return ((startDateUtc != null) && (numberOfDays != null)) ?
       startDateUtc.add(Duration(days: numberOfDays)) : null;
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
    _HealthRuleStatus2 status = (rules?.statuses != null) ? rules?.statuses[reference] : null;
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
    else if (condition == 'timeout') {
      result = _evalTimeout(history: history, historyIndex: historyIndex, rules: rules);
    }
    else if (condition == 'test-user') {
      result = _evalTestUser(rules: rules);
    }
    else if (condition == 'test-interval') {
      result = _evalTestInterval(rules: rules);
    }
    return result?.eval(history: history, historyIndex: historyIndex, rules: rules);
  }

  _HealthRuleStatus2 _evalRequireTest({ List<Covid19History> history, int historyIndex, HealthRulesSet2 rules }) {
    
    Covid19History historyEntry = ((history != null) && (historyIndex != null) && (0 <= historyIndex) && (historyIndex < history.length)) ? history[historyIndex] : null;
    DateTime historyDateMidnightLocal = historyEntry?.dateMidnightLocal;
    if (historyDateMidnightLocal == null) {
      return null;
    }
    
    _HealthRuleIntInterval2 interval = _HealthRuleIntInterval2.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    dynamic category = params['category'];
    if (category is List) {
      category = Set.from(category);
    }

    int scope = interval.scope(rules: rules) ?? 0;
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
    if ((interval.current(rules: rules) == true) && _evalCurrentIntervalFulfills(interval, historyDateMidnightLocal: historyDateMidnightLocal, rules: rules)) {
      return successStatus;
    }

    return failStatus;
  }

  static bool _evalRequireTestEntryFulfills(Covid19History entry, { DateTime historyDateMidnightLocal,  _HealthRuleIntInterval2 interval, HealthRulesSet2 rules, dynamic category }) {
    if (entry.isTest && entry.canTestUpdateStatus) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      final difference = entryDateMidnightLocal.difference(historyDateMidnightLocal).inDays;
      if (interval.match(difference, rules: rules)) {
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

    _HealthRuleIntInterval2 interval = _HealthRuleIntInterval2.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    int scope = interval.scope(rules: rules) ?? 0;
    if (0 < scope) { // check only newer items than the current
      for (int index = historyIndex - 1; 0 <= index; index--) {
        if (_evalRequireSymptomsEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval, rules: rules)) {
          return successStatus;
        }
      }
    }
    else if (0 < scope) { // check only older items than the current
      for (int index = historyIndex + 1; index < history.length; index++) {
        if (_evalRequireSymptomsEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval, rules: rules)) {
          return successStatus;
        }
      }
    }
    else { // check all history items
      for (int index = 0; index < history.length; index++) {
        if ((index != historyIndex) && _evalRequireSymptomsEntryFulfills(history[index], historyDateMidnightLocal: historyDateMidnightLocal, interval: interval, rules: rules)) {
          return successStatus;
        }
      }
    }

    // If positive time interval is not already expired - do not return failed status yet.
    if ((interval.current(rules: rules) == true) && _evalCurrentIntervalFulfills(interval, historyDateMidnightLocal: historyDateMidnightLocal, rules: rules)) {
      return successStatus;
    }

    return failStatus;
  }

  static bool _evalRequireSymptomsEntryFulfills(Covid19History entry, { DateTime historyDateMidnightLocal,  _HealthRuleIntInterval2 interval, HealthRulesSet2 rules }) {
    if (entry.isSymptoms) {
      DateTime entryDateMidnightLocal = entry.dateMidnightLocal;
      final difference = entryDateMidnightLocal.difference(historyDateMidnightLocal).inDays;
      if (interval.match(difference, rules: rules)) {
        return true;
      }
    }
    return false;
  }

  _HealthRuleStatus2 _evalTestUser({ HealthRulesSet2 rules }) {
    dynamic role = params['role'];
    if ((role != null) && !_matchStringTarget(target: Auth().authCard?.role, source: role)) {
      return failStatus;
    }
    dynamic studentLevel = params['student_level'];
    if ((studentLevel != null) && !_matchStringTarget(target: Auth().authCard?.studentLevel, source: studentLevel)) {
      return failStatus;
    }
    return successStatus;
  }

  _HealthRuleStatus2 _evalTestInterval({ HealthRulesSet2 rules }) {
    dynamic interval = _HealthRuleIntInterval2.fromJson(params['interval']);
    return (interval?.valid(rules: rules) ?? false) ? successStatus : failStatus;
  }

  static bool _matchStringTarget({dynamic source, String target}) {
    if (target != null) {
      if (source is String) {
        return source.toLowerCase() == target.toLowerCase();
      }
      else if (source is List) {
        for (dynamic sourceEntry in source) {
          if ((sourceEntry is String) && (sourceEntry.toLowerCase() == target.toLowerCase())) {
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

    _HealthRuleIntInterval2 interval = _HealthRuleIntInterval2.fromJson(params['interval']);
    if (interval == null) {
      return null;
    }

    return _evalCurrentIntervalFulfills(interval, historyDateMidnightLocal: historyDateMidnightLocal, rules: rules) ?
      failStatus : successStatus; // while current time is within interval 'timeout' condition fails
  }

  static bool _evalCurrentIntervalFulfills(_HealthRuleIntInterval2 currentInterval, { DateTime historyDateMidnightLocal, HealthRulesSet2 rules } ) {
    if (currentInterval != null) {
      final difference = AppDateTime.todayMidnightLocal.difference(historyDateMidnightLocal).inDays;
      if (currentInterval.match(difference, rules: rules)) {
        return true;
      }
    }
    return false;
  }


}

