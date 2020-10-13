
import 'package:illinois/service/Service.dart';
import 'package:firebase_core/firebase_core.dart' as GoogleFirebase;

class Firebase extends Service{
  static final Firebase _instance = new Firebase._internal();

  factory Firebase() {
    return _instance;
  }
  Firebase._internal();


  @override
  Future<void> initService() async{
    await super.initService();

    await GoogleFirebase.Firebase.initializeApp();
  }
}