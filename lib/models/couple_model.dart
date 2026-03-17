import 'package:cloud_firestore/cloud_firestore.dart';

class CoupleModel {
  final String id;
  final List<String> partnerIds;
  final List<String> partnerNames;
  final DateTime createdAt;
  final DateTime? anniversary;
  final String? coupleName;
  final String status;

  const CoupleModel({
    required this.id,
    required this.partnerIds,
    required this.partnerNames,
    required this.createdAt,
    this.anniversary,
    this.coupleName,
    this.status = 'active',
  });

  String getPartnerName(String myUid) {
    final myIndex = partnerIds.indexOf(myUid);
    return partnerNames[myIndex == 0 ? 1 : 0];
  }

  String getPartnerId(String myUid) {
    return partnerIds.firstWhere((id) => id != myUid);
  }

  int get daysTogether => DateTime.now().difference(createdAt).inDays;

  CoupleModel copyWith({
    String? id,
    List<String>? partnerIds,
    List<String>? partnerNames,
    DateTime? createdAt,
    DateTime? anniversary,
    String? coupleName,
    String? status,
  }) {
    return CoupleModel(
      id: id ?? this.id,
      partnerIds: partnerIds ?? this.partnerIds,
      partnerNames: partnerNames ?? this.partnerNames,
      createdAt: createdAt ?? this.createdAt,
      anniversary: anniversary ?? this.anniversary,
      coupleName: coupleName ?? this.coupleName,
      status: status ?? this.status,
    );
  }

  factory CoupleModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CoupleModel(
      id: doc.id,
      partnerIds: List<String>.from(data['partnerIds'] ?? []),
      partnerNames: List<String>.from(data['partnerNames'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      anniversary: (data['anniversary'] as Timestamp?)?.toDate(),
      coupleName: data['coupleName'] as String?,
      status: data['status'] as String? ?? 'active',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'partnerIds': partnerIds,
      'partnerNames': partnerNames,
      'createdAt': Timestamp.fromDate(createdAt),
      'anniversary':
          anniversary != null ? Timestamp.fromDate(anniversary!) : null,
      'coupleName': coupleName,
      'status': status,
    };
  }
}
