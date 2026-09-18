class PaymentConfig {
  const PaymentConfig({
    this.monthlyFeeCup = 1000,
    this.transfermovilCard = '',
    this.paymentInstructions = 'Paga por Transfermóvil y espera confirmación del administrador.',
  });

  final int monthlyFeeCup;
  final String transfermovilCard;
  final String paymentInstructions;

  PaymentConfig copyWith({
    int? monthlyFeeCup,
    String? transfermovilCard,
    String? paymentInstructions,
  }) =>
      PaymentConfig(
        monthlyFeeCup: monthlyFeeCup ?? this.monthlyFeeCup,
        transfermovilCard: transfermovilCard ?? this.transfermovilCard,
        paymentInstructions: paymentInstructions ?? this.paymentInstructions,
      );
}
