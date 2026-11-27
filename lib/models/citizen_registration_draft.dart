/// In-memory citizen registration details carried across signup steps.
/// The sample ID and password must not be logged or persisted by this model.
class CitizenRegistrationDraft {
  const CitizenRegistrationDraft({
    required this.fullName,
    required this.nationalId,
    required this.phone,
    required this.password,
  });

  final String fullName;
  final String nationalId;
  final String phone;
  final String password;
}
