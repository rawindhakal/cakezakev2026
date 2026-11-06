/// Withdrawal request status, matching the API's `status` filter values.
enum WithdrawalStatus {
  all(''),
  pending('0'),
  approved('1'),
  rejected('2');

  const WithdrawalStatus(this.value);

  final String value;

  static WithdrawalStatus fromValue(String? value) => WithdrawalStatus.values
      .firstWhere((e) => e.value == value, orElse: () => WithdrawalStatus.all);
}
