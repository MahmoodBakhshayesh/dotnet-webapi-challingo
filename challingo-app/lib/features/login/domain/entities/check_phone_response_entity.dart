import '/core/helpers/json_validators.dart';

class CheckPhoneResponseData {
  final bool exists;
  final bool isConfirmed;
  final bool requiresRegistration;
  final bool canLoginWithPassword;
  final bool isProfileCompleted;
  final bool canLoginWithOtp;

  CheckPhoneResponseData({
    required this.exists,
    required this.isConfirmed,
    required this.requiresRegistration,
    required this.canLoginWithPassword,
    required this.isProfileCompleted,
    required this.canLoginWithOtp,
  });

  CheckPhoneResponseData copyWith({
    bool? exists,
    bool? isConfirmed,
    bool? requiresRegistration,
    bool? canLoginWithPassword,
    bool? isProfileCompleted,
    bool? canLoginWithOtp,
  }) =>
      CheckPhoneResponseData(
        exists: exists ?? this.exists,
        isConfirmed: isConfirmed ?? this.isConfirmed,
        requiresRegistration: requiresRegistration ?? this.requiresRegistration,
        canLoginWithPassword: canLoginWithPassword ?? this.canLoginWithPassword,
        isProfileCompleted: isProfileCompleted ?? this.isProfileCompleted,
        canLoginWithOtp: canLoginWithOtp ?? this.canLoginWithOtp,
      );

  factory CheckPhoneResponseData.fromJson(Map<String, dynamic> json) => CheckPhoneResponseData(
    exists: expectBool(json, 'Exists'),
    isConfirmed: expectBool(json, 'IsConfirmed'),
    requiresRegistration: expectBool(json, 'RequiresRegistration'),
    canLoginWithPassword: expectBool(json, 'CanLoginWithPassword'),
    isProfileCompleted: expectBool(json, 'IsProfileCompleted'),
    canLoginWithOtp: expectBool(json, 'CanLoginWithOtp'),
  );

  Map<String, dynamic> toJson() => {
    'Exists': exists,
    'IsConfirmed': isConfirmed,
    'RequiresRegistration': requiresRegistration,
    'CanLoginWithPassword': canLoginWithPassword,
    'IsProfileCompleted': isProfileCompleted,
    'CanLoginWithOtp': canLoginWithOtp,
  };
}