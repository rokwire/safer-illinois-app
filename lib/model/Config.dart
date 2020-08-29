class SchoolConfig {

  final String clientID;
  final String name;
  final String iconURL;
  final String configAsset;

  SchoolConfig({this.clientID, this.name, this.iconURL, this.configAsset});

  factory SchoolConfig.fromJson(Map<String, dynamic> json) {
    return SchoolConfig(
      clientID: json['clientID'],
      name: json['name'],
      iconURL: json['icon_url'],
      configAsset: json['config_asset'],
    );
  }

  toJson() {
    return {
      'clientID': clientID,
      'name': name,
      'icon_url': iconURL,
      'config_asset': configAsset,
    };
  }

  bool operator ==(o) =>
      o is SchoolConfig &&
          o.clientID == clientID &&
          o.name == name &&
          o.iconURL == iconURL &&
          o.configAsset == configAsset;

  int get hashCode =>
      clientID.hashCode ^
      name.hashCode ^
      iconURL.hashCode ^
      configAsset.hashCode;
}