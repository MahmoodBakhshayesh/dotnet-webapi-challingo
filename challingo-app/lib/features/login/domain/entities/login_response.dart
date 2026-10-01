import '/core/helpers/json_validators.dart';
import '/core/helpers/nullable.dart';

class LoginResponseData {
  final String accessToken;
  final UserEntity user;

  LoginResponseData({
    required this.accessToken,
    required this.user,
  });

  LoginResponseData copyWith({
    String? accessToken,
    UserEntity? user,
  }) => LoginResponseData(
    accessToken: accessToken ?? this.accessToken,
    user: user ?? this.user,
  );

  factory LoginResponseData.fromJson(Map<String, dynamic> json) => LoginResponseData(
    accessToken: expectString(json, 'AccessToken'),
    user: UserEntity.fromJson(expectMap(json, 'User')),
  );

  Map<String, dynamic> toJson() => {
    'AccessToken': accessToken,
    'User': user.toJson(),
  };
}

class UserEntity {
  final String id;
  final String phoneNumber;
  final String fullName;
  final String? username;
  final String? email;
  final String? profileImageUrl;

  UserEntity({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    this.username,
    this.email,
    this.profileImageUrl,
  });

  UserEntity copyWith({
    String? id,
    String? phoneNumber,
    String? fullName,
    Nullable<String?>? username,
    Nullable<String?>? email,
    Nullable<String?>? profileImageUrl,
  }) => UserEntity(
    id: id ?? this.id,
    phoneNumber: phoneNumber ?? this.phoneNumber,
    fullName: fullName ?? this.fullName,
    username: username != null ? username.value : this.username,
    email: email != null ? email.value : this.email,
    profileImageUrl: profileImageUrl != null ? profileImageUrl.value : this.profileImageUrl,
  );

  factory UserEntity.fromJson(Map<String, dynamic> json) => UserEntity(
    id: expectString(json, 'Id'),
    phoneNumber: expectString(json, 'PhoneNumber'),
    fullName: expectString(json, 'FullName', defaultValue: ''),
    username: expectNullableString(json, 'Username'),
    email: expectNullableString(json, 'Email'),
    profileImageUrl: expectNullableString(json, 'ProfileImageUrl'),
  );

  Map<String, dynamic> toJson() => {
    'Id': id,
    'PhoneNumber': phoneNumber,
    'FullName': fullName,
    if (username != null) 'Username': username,
    if (email != null) 'Email': email,
    'ProfileImageUrl': profileImageUrl,
  };
}
