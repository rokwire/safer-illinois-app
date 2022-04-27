# Safer Illinois App
The official COVID-19 app of the University of Illinois. Powered by the [Rokwire Platform](https://rokwire.org/).

For academic references, please cite our formal release on Zenodo.
[![doi/10.5281/zenodo.4619823](https://zenodo.org/badge/doi/10.5281/zenodo.4619823.svg)](https://doi.org/10.5281/zenodo.4619823)

## Requirements

### [Flutter](https://flutter.dev/docs/get-started/install) v2.2.2

### [Android Studio](https://developer.android.com/studio) 3.6+

### [Xcode](https://apps.apple.com/us/app/xcode/id497799835) 12.5

### [CocoaPods](https://guides.cocoapods.org/using/getting-started.html) 1.9.3+


## Build


### Clone this repo

### Supply the following private configuration files:

#### • /.travis.yml
[No description available]


#### • /secrets.tar.enc
[No description available]

#### • /assets/configs.json.enc
1. JSON data with the following format:
```
{
  "production": {
    "config_url": "https://api.rokwire.illinois.edu/app/configs",
    "api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
  },
  "dev": {
    "config_url": "https://api-dev.rokwire.illinois.edu/app/configs",
    "api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
  },
  "test": {
    "config_url": "https://api-test.rokwire.illinois.edu/app/configs",
    "api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
  }
}
```
2. Generate random 16-bytes AES128 key.
3. AES encrypt the JSON string, CBC mode, PKCS7 padding, using the AES.
4. Create a data blob contains the AES key at the beginning followed by the encrypted data.
5. Get a base64 encoded string of the data blob and save it as /assets/configs.json.enc.

Alternatively, you can use AESCrypt.encode from /lib/utils/Crypt.dart to generate content of /assets/configs.json.enc.

NB: For versions prior to 2.8.

#### • /assets/organizations.hook.json.enc
1. JSON data with the following format:
```
{
	"url": "https://api-dev.rokwire.illinois.edu/assets/buckets/items/organizations",
	"api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
}
```
2. Generate random 16-bytes AES128 key.
3. AES encrypt the JSON string, CBC mode, PKCS7 padding, using the AES.
4. Create a data blob contains the AES key at the beginning followed by the encrypted data.
5. Get a base64 encoded string of the data blob and save it as /assets/organizations.hook.json.enc.

Alternatively, you can use AESCrypt.encode from /lib/utils/Crypt.dart to generate content of /assets/organizations.hook.json.enc.

NB: For version 2.8 and later.

#### • /assets/organizations.json.enc
1. JSON data with the following format:
```
[
	{
		"id": "uiuc",
		"name": "UIUC",
		"icon_url": "https://upload.wikimedia.org/wikipedia/commons/7/7c/Illinois_Block_I.png",
		"default": true,
		"environments": {
			"production": {
				"url": "https://api.rokwire.illinois.edu/covid/app/configs",
				"api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX",
				"default": "release"
			},
			"dev": {
				"url": "https://api-dev.rokwire.illinois.edu/covid/app/configs",
				"api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX",
				"default": "debug"
			},
			"test": {
				"url": "https://api-test.rokwire.illinois.edu/covid/app/configs",
				"api_key": "XXXXXXXX-XXXX-XXXX-XXXXXXXXXXXXXXXXX"
			}
		}
	},
  ...
]
```
2. Generate random 16-bytes AES128 key.
3. AES encrypt the JSON string, CBC mode, PKCS7 padding, using the AES.
4. Create a data blob contains the AES key at the beginning followed by the encrypted data.
5. Get a base64 encoded string of the data blob and save it as /assets/organizations.json.enc.

Alternatively, you can use AESCrypt.encode from /lib/utils/Crypt.dart to generate content of /assets/organizations.json.enc.

NB: Optional way to supply statically embeded organizations in appication bundle. If the list contains single organization definition the application switches to single organization mode. "/assets/organizations.hook.json.enc" must be omited from application assets in order to "/assets/organizations.json.enc" to take efect.

NB: For version 2.8 and later.


#### • /ios/Runner/GoogleService-Info-Debug.plist
#### • /ios/Runner/GoogleService-Info-Release.plist

The Firebase configuration file for iOS generated from Google Firebase console.

#### • /android/keys.properties
Contains a GoogleMaps and Android Backup API keys.
```
googleMapsApiKey=XXXXXXXXXXXXXXXXXXXXXX-XXXXXXXXXXXXXXXX
androidBackupApiKey=XXXXXXXXXXXXXXXXXXXXXX-XXXXXXXXXXXXXXXXXXXXXXXXXXX
```

#### • /android/app/src/debug/google-services.json
#### • /android/app/src/release/google-services.json
#### • /android/app/src/profile/google-services.json
The Firebase configuration file for Android generated from Google Firebase console.

### Build the project

```
$ flutter build apk
$ flutter build ios
```
NB: You may need to update singing & capabilities content for Runner project by opening /ios/Runner.xcworkspace from Xcode
