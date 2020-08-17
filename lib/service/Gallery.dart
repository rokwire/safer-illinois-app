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

import 'dart:typed_data';
import 'package:flutter/services.dart';


class Gallery{

  static const MethodChannel _channel = const MethodChannel("edu.illinois.covid/gallery");

  static const String _storeMethodName  = 'store';

  static const String _bytesParamName   = 'bytes';
  static const String _nameParamName    = 'name';

  static final Gallery _instance = Gallery._internal();

  factory Gallery() {
    return _instance;
  }

  Gallery._internal();

  Future<bool> storeImage({Uint8List imageBytes, String name}) async{
    return await _channel.invokeMethod(_storeMethodName,{
      _bytesParamName: imageBytes,
      _nameParamName: name
    });
  }
}