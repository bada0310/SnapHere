class GoogleIdentityCredential {
  const GoogleIdentityCredential({
    required this.idToken,
    required this.subject,
    required this.email,
    this.displayName,
    this.photoUrl,
  });

  final String idToken;
  final String subject;
  final String email;
  final String? displayName;
  final String? photoUrl;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.needsProfileSetup,
    this.displayName,
    this.photoUrl,
    this.nickname,
    this.bio,
  });

  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? nickname;
  final String? bio;
  final bool needsProfileSetup;

  Map<String, Object?> toJson() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'nickname': nickname,
    'bio': bio,
    'needsProfileSetup': needsProfileSetup,
  };

  factory AuthUser.fromJson(Map<String, Object?> json) => AuthUser(
    id: json['id']! as String,
    email: json['email']! as String,
    displayName: json['displayName'] as String?,
    photoUrl: json['photoUrl'] as String?,
    nickname: json['nickname'] as String?,
    bio: json['bio'] as String?,
    needsProfileSetup: json['needsProfileSetup']! as bool,
  );
}

class AuthSession {
  const AuthSession.authenticated({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  }) : isGuest = false;

  const AuthSession.guest()
    : accessToken = null,
      refreshToken = null,
      user = null,
      isGuest = true;

  final String? accessToken;
  final String? refreshToken;
  final AuthUser? user;
  final bool isGuest;

  bool get isAuthenticated => !isGuest && user != null;

  Map<String, Object?> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'user': user?.toJson(),
    'isGuest': isGuest,
  };

  factory AuthSession.fromJson(Map<String, Object?> json) {
    if (json['isGuest'] == true) {
      return const AuthSession.guest();
    }
    return AuthSession.authenticated(
      accessToken: json['accessToken']! as String,
      refreshToken: json['refreshToken']! as String,
      user: AuthUser.fromJson(Map<String, Object?>.from(json['user']! as Map)),
    );
  }
}

/// 로컬 세션은 삭제됐으며 외부 연결 종료 여부는 별도로 확인한다.
class SignOutResult {
  const SignOutResult({
    this.serverSessionEnded = true,
    this.googleSessionEnded = true,
  });

  final bool serverSessionEnded;
  final bool googleSessionEnded;
}

class ConsentRecord {
  const ConsentRecord({
    required this.termsVersion,
    required this.privacyVersion,
    required this.acceptedAt,
    required this.marketingAccepted,
    this.marketingVersion,
  });

  final String termsVersion;
  final String privacyVersion;
  final String? marketingVersion;
  final bool marketingAccepted;
  final DateTime acceptedAt;

  Map<String, Object?> toJson() => {
    'termsVersion': termsVersion,
    'privacyVersion': privacyVersion,
    'marketingVersion': marketingVersion,
    'marketingAccepted': marketingAccepted,
    'acceptedAt': acceptedAt.toUtc().toIso8601String(),
  };
}

class ProfileSubmission {
  const ProfileSubmission({
    required this.nickname,
    required this.bio,
    required this.consents,
    this.profileImagePath,
  });

  final String nickname;
  final String? bio;
  final String? profileImagePath;
  final ConsentRecord consents;

  Map<String, Object?> toJson() => {
    'nickname': nickname,
    'bio': bio,
    'profileImagePath': profileImagePath,
    'consents': consents.toJson(),
  };
}

enum LegalDocumentType {
  terms('terms'),
  privacyConsent('privacy-consent'),
  privacyPolicy('privacy-policy'),
  marketing('marketing');

  const LegalDocumentType(this.path);
  final String path;

  static LegalDocumentType? fromPath(String path) {
    for (final type in values) {
      if (type.path == path) return type;
    }
    return null;
  }
}

class LegalDocument {
  const LegalDocument({
    required this.type,
    required this.title,
    required this.version,
    required this.effectiveDate,
    required this.sections,
  });

  final LegalDocumentType type;
  final String title;
  final String version;
  final DateTime effectiveDate;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection({required this.heading, required this.body});
  final String heading;
  final String body;
}
