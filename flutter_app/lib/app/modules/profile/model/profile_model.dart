class UserProfileData {
  final String? id;
  final String? userId;
  final String? location;
  final String? dateOfBirth;
  final String? gender;
  final String? profileAvatar;
  final String? profileCover;

  UserProfileData({
    this.id,
    this.userId,
    this.location,
    this.dateOfBirth,
    this.gender,
    this.profileAvatar,
    this.profileCover,
  });

  factory UserProfileData.fromJson(Map<String, dynamic> json) {
    return UserProfileData(
      id: json['id']?.toString(),
      userId: json['userId']?.toString(),
      location: json['location']?.toString(),
      dateOfBirth: json['dateOfBirth']?.toString(),
      gender: json['gender']?.toString(),
      profileAvatar: json['profileAvatar']?.toString(),
      profileCover: json['profileCover']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'location': location,
      'dateOfBirth': dateOfBirth,
      'gender': gender,
      'profileAvatar': profileAvatar,
      'profileCover': profileCover,
    };
  }
}

class UserModel {
  final String? id;
  final String? name;
  final String? email;
  final String? phoneNumber;
  final String? accountStatus;
  final String? accountRole;
  final bool? isVerified;
  final UserProfileData? profile;

  UserModel({
    this.id,
    this.name,
    this.email,
    this.phoneNumber,
    this.accountStatus,
    this.accountRole,
    this.isVerified,
    this.profile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString(),
      name: json['name']?.toString(),
      email: json['email']?.toString(),
      phoneNumber: json['phoneNumber']?.toString(),
      accountStatus: json['accountStatus']?.toString(),
      accountRole: json['accountRole']?.toString(),
      isVerified: json['isVerified'] is bool ? json['isVerified'] : null,
      profile: json['profile'] != null && json['profile'] is Map<String, dynamic>
          ? UserProfileData.fromJson(json['profile'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'accountStatus': accountStatus,
      'accountRole': accountRole,
      'isVerified': isVerified,
      'profile': profile?.toJson(),
    };
  }
}

class ProfileResponseModel {
  final bool success;
  final String? message;
  final UserModel? user;
  final String? traceId;

  ProfileResponseModel({
    required this.success,
    this.message,
    this.user,
    this.traceId,
  });

  factory ProfileResponseModel.fromJson(Map<String, dynamic> json) {
    return ProfileResponseModel(
      success: json['success'] == true,
      message: json['message']?.toString(),
      user: json['data']?['user'] != null &&
              json['data']['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['data']['user'])
          : null,
      traceId: json['traceId']?.toString(),
    );
  }
}
