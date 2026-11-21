enum SignUpRole {
  user(label: 'User', apiValue: 'USER'),
  clubOwner(label: 'Club Owner', apiValue: 'CLUB_OWNER');

  const SignUpRole({required this.label, required this.apiValue});

  final String label;
  final String apiValue;

  static SignUpRole fromLabel(String label) {
    return SignUpRole.values.firstWhere(
      (role) => role.label == label,
      orElse: () => SignUpRole.user,
    );
  }
}

class SignUpRequestModel {
  final String role;
  final String name;
  final String email;
  final String phoneNumber;
  final String location;
  final String password;
  final String deviceIdentifier;
  final String fcmToken;
  final double latitude;
  final double longitude;
  final String platform;
  final String gender;
  final String dateOfBirth;

  const SignUpRequestModel({
    required this.role,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.location,
    required this.password,
    required this.deviceIdentifier,
    required this.fcmToken,
    required this.latitude,
    required this.longitude,
    required this.platform,
    required this.gender,
    required this.dateOfBirth,
  });

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'location': location,
      'password': password,
      'deviceIdentifier': deviceIdentifier,
      'fcmToken': fcmToken,
      'lat': latitude,
      'lng': longitude,
      'platform': platform,
      'gender': gender,
      'dateOfBirth': dateOfBirth,
    };
  }
}

class SignUpPendingDataModel {
  final String? verificationToken;

  const SignUpPendingDataModel({this.verificationToken});

  factory SignUpPendingDataModel.fromJson(Map<String, dynamic> json) {
    return SignUpPendingDataModel(
      verificationToken:
          (json['verificationToken'] ??
                  json['pendingVerificationToken'] ??
                  json['token'])
              ?.toString(),
    );
  }
}

class SignUpResponseModel {
  final bool success;
  final String message;
  final SignUpPendingDataModel? data;

  const SignUpResponseModel({
    required this.success,
    required this.message,
    this.data,
  });

  factory SignUpResponseModel.fromJson(Map<String, dynamic> json) {
    final rawData = json['data'];
    return SignUpResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: rawData is Map<String, dynamic>
          ? SignUpPendingDataModel.fromJson(rawData)
          : null,
    );
  }
}
