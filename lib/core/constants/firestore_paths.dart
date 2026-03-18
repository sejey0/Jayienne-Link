class FirestorePaths {
  FirestorePaths._();

  // Collections
  static const String users = 'users';
  static const String couples = 'couples';
  static const String inviteCodes = 'inviteCodes';
  static const String locations = 'locations'; // Subcollection under couples

  // User fields
  static const String uid = 'uid';
  static const String userEmail = 'email';
  static const String userPhoneNumber = 'phoneNumber';
  static const String userDisplayName = 'displayName';
  static const String userPhotoUrl = 'photoUrl';
  static const String userBirthday = 'birthday';
  static const String userCoupleId = 'coupleId';
  static const String userInviteCode = 'inviteCode';
  static const String userProfileComplete = 'profileComplete';
  static const String userCreatedAt = 'createdAt';
  static const String userUpdatedAt = 'updatedAt';

  // Couple fields
  static const String couplePartnerIds = 'partnerIds';
  static const String couplePartnerNames = 'partnerNames';
  static const String coupleCreatedAt = 'createdAt';
  static const String coupleAnniversary = 'anniversary';
  static const String coupleName = 'coupleName';
  static const String coupleStatus = 'status';

  // Invite code fields
  static const String codeUserId = 'userId';
  static const String codeCreatedAt = 'createdAt';
  static const String codeExpiresAt = 'expiresAt';
  static const String codeUsed = 'used';
  static const String codeUsedBy = 'usedBy';
  static const String codeUsedAt = 'usedAt';

  // Location fields
  static const String locationOwnerId = 'owner_id';
  static const String locationLatitude = 'latitude';
  static const String locationLongitude = 'longitude';
  static const String locationAccuracy = 'accuracy';
  static const String locationTimestamp = 'timestamp';
  static const String locationPartnerId = 'partner_id';
  static const String locationCoupleId = 'couple_id';
}
