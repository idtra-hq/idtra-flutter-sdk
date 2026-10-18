class IdtraVerificationResult {
  final bool isMatch;
  final double confidence;
  final String message;
  final CitizenData? citizenData;
  final Map<String, dynamic> rawJson;

  IdtraVerificationResult({
    required this.isMatch,
    required this.confidence,
    required this.message,
    this.citizenData,
    required this.rawJson,
  });

  factory IdtraVerificationResult.fromJson(Map<String, dynamic> json) {
    final faceMatch = json['face_match'] as Map<String, dynamic>?;
    final isMatch = faceMatch?['is_match'] ?? (json['status'] == 'success');
    final confidence = (faceMatch?['confidence'] as num?)?.toDouble() ?? (isMatch ? 0.95 : 0.20);
    final message = faceMatch?['message'] ?? json['message'] ?? '';

    final dataJson = json['data'] as Map<String, dynamic>?;

    return IdtraVerificationResult(
      isMatch: isMatch,
      confidence: confidence,
      message: message,
      citizenData: dataJson != null ? CitizenData.fromJson(dataJson) : null,
      rawJson: json,
    );
  }
}

class CitizenData {
  final String? firstname;
  final String? surname;
  final String? middlename;
  final String? gender;
  final String? birthdate;
  final String? nin;
  final String? bvn;
  final String? photoBase64;
  final String? address;

  CitizenData({
    this.firstname,
    this.surname,
    this.middlename,
    this.gender,
    this.birthdate,
    this.nin,
    this.bvn,
    this.photoBase64,
    this.address,
  });

  String get fullName => [firstname, middlename, surname].where((s) => s != null && s.isNotEmpty).join(' ');

  factory CitizenData.fromJson(Map<String, dynamic> json) {
    return CitizenData(
      firstname: json['firstname'] ?? json['firstName'],
      surname: json['surname'] ?? json['lastName'],
      middlename: json['middlename'] ?? json['middleName'],
      gender: json['gender'],
      birthdate: json['birthdate'] ?? json['birthDate'],
      nin: json['nin'],
      bvn: json['bvn'],
      photoBase64: json['photo'],
      address: json['residence_address'] ?? json['residentialAddress'],
    );
  }
}
