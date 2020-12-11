import 'package:flutter/material.dart';
import 'package:illinois/service/NativeCommunicator.dart';
import 'package:illinois/service/Storage.dart';
import 'package:illinois/service/Styles.dart';
import 'package:illinois/ui/widgets/HeaderBar.dart';
import 'package:illinois/ui/widgets/RoundedButton.dart';
import 'package:illinois/utils/Utils.dart';

class DebugDirectionsPanel extends StatefulWidget{
  _DebugDirectionsPanelState createState() => _DebugDirectionsPanelState();
}

class _DebugDirectionsPanelState extends State<DebugDirectionsPanel> {

  final TextEditingController _latitudeController = TextEditingController();
  final FocusNode _latitudeFocusNode = FocusNode();

  final TextEditingController _longitudeController = TextEditingController();
  final FocusNode _longitudeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _latitudeController.text = Storage()['debug_latitude'] ?? '';
    _longitudeController.text = Storage()['debug_longitude'] ?? '';
  }

  @override
  void dispose() {
    super.dispose();
    _latitudeController.dispose();
    _latitudeFocusNode.dispose();
    _longitudeController.dispose();
    _longitudeFocusNode.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Styles().colors.surface,
      appBar: SimpleHeaderBarWithBack(
        context: context,
        titleWidget: Text("Directions", style: TextStyle(color: Colors.white, fontSize: 16, fontFamily: Styles().fontFamilies.extraBold),
        ),
      ),
      body: SingleChildScrollView(child: 
        Padding( padding: EdgeInsets.all(32), child: 
          Column(crossAxisAlignment: CrossAxisAlignment.start , children: [
            Padding(padding: EdgeInsets.only(bottom: 12), child: 
              Text('Destination: ', style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.bold, color: Styles().colors.fillColorPrimary),),
            ),
            Padding(padding: EdgeInsets.only(bottom: 12), child: 
              Semantics(excludeSemantics: true, label: "Latitude", hint: '', value: _latitudeController.text, child:
                TextField(controller: _latitudeController, focusNode: _latitudeFocusNode,
                  autofocus: false,
                  cursorColor: Styles().colors.textBackground,
                  keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                  style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),
                  decoration: InputDecoration(
                    labelText: "Latitude",
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2.0, style: BorderStyle.solid),),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2.0),),
                  ),
                ),
              )),
            Padding(padding: EdgeInsets.only(bottom: 24), child: 
              Semantics( excludeSemantics: true, label: "Longitude", hint: '', value: _longitudeController.text,
                child: TextField(controller: _longitudeController, focusNode: _longitudeFocusNode,
                  autofocus: false,
                  cursorColor: Styles().colors.textBackground,
                  keyboardType: TextInputType.numberWithOptions(signed: true, decimal: true),
                  style: TextStyle(fontSize: 16, fontFamily: Styles().fontFamilies.regular, color: Styles().colors.textBackground),
                  decoration: InputDecoration(
                    labelText: "Longitude",
                    enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2.0, style: BorderStyle.solid),),
                    focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.black, width: 2.0),),
                  ),
                ),
              )),
              RoundedButton(
                  label: "Go",
                  backgroundColor: Styles().colors.background,
                  fontSize: 16.0,
                  textColor: Styles().colors.fillColorPrimary,
                  borderColor: Styles().colors.fillColorPrimary,
                  onTap: ()=> _onTapDirections(context))
            ],),
          ),
        ),
    );
  }
  
  void _onTapDirections(BuildContext context){
    double latitude = double.tryParse(_latitudeController.text);
    if (latitude == null) {
      AppAlert.showDialogResult(context, "Please enter a valid latitude value.").then((_) {
        _latitudeFocusNode.requestFocus();
      });
      return;
    }

    double longitude = double.tryParse(_longitudeController.text);
    if (longitude == null) {
      AppAlert.showDialogResult(context, "Please enter a valid longitude value.").then((_) {
        _longitudeFocusNode.requestFocus();
      });
      return;
    }

    Storage()['debug_latitude'] = _latitudeController.text;
    Storage()['debug_longitude'] = _longitudeController.text;

    _latitudeFocusNode.unfocus();
    _longitudeFocusNode.unfocus();

    NativeCommunicator().launchMapDirections(
      target: {
        'latitude': latitude,
        'longitude': longitude,
        'zoom': 17,
        'title': 'Debug Location',
        'description': '(${_latitudeController.text}, ${_longitudeController.text})',
      },
    );
  }
}
