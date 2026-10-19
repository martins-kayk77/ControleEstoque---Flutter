enum StockMovementType {
  inbound,
  sale,
  adjustment,
  loss,
  damage,
  ownUse,
  returnItem,
  gift,
  reversal,
  other,
}

extension StockMovementTypeX on StockMovementType {
  String get code {
    return switch (this) {
      StockMovementType.inbound => 'inbound',
      StockMovementType.sale => 'sale',
      StockMovementType.adjustment => 'adjustment',
      StockMovementType.loss => 'loss',
      StockMovementType.damage => 'damage',
      StockMovementType.ownUse => 'own_use',
      StockMovementType.returnItem => 'return',
      StockMovementType.gift => 'gift',
      StockMovementType.reversal => 'reversal',
      StockMovementType.other => 'other',
    };
  }

  String get label {
    return switch (this) {
      StockMovementType.inbound => 'Entrada',
      StockMovementType.sale => 'Venda',
      StockMovementType.adjustment => 'Ajuste',
      StockMovementType.loss => 'Perda',
      StockMovementType.damage => 'Dano',
      StockMovementType.ownUse => 'Uso próprio',
      StockMovementType.returnItem => 'Devolução',
      StockMovementType.gift => 'Brinde',
      StockMovementType.reversal => 'Estorno',
      StockMovementType.other => 'Outro',
    };
  }
}

StockMovementType stockMovementTypeFromCode(String code) {
  return StockMovementType.values.firstWhere(
    (type) => type.code == code,
    orElse: () => StockMovementType.other,
  );
}

class StockMovement {
  const StockMovement({
    required this.id,
    required this.companyId,
    required this.productId,
    required this.type,
    required this.quantityDelta,
    required this.occurredAt,
    this.operationId,
    this.userId,
    this.userEmail = '',
    this.responsibleName = '',
    this.operationReference = '',
    this.reason = '',
    this.note = '',
    this.sourceChannelId,
    this.stockAfter,
    this.reversalOfOperationId,
    this.reversalOperationId,
    this.reversedAt,
    this.reversedByUserId,
    this.reversedByResponsibleName = '',
    this.reversalReason = '',
  });

  final String id;
  final String companyId;
  final String productId;
  final StockMovementType type;
  final int quantityDelta;
  final DateTime occurredAt;
  final String? operationId;
  final String? userId;
  final String userEmail;
  final String responsibleName;
  final String operationReference;
  final String reason;
  final String note;
  final String? sourceChannelId;
  final int? stockAfter;
  final String? reversalOfOperationId;
  final String? reversalOperationId;
  final DateTime? reversedAt;
  final String? reversedByUserId;
  final String reversedByResponsibleName;
  final String reversalReason;

  bool get increasesStock => quantityDelta > 0;
  bool get decreasesStock => quantityDelta < 0;
  bool get isReversal => reversalOfOperationId != null;
  bool get isReversed => reversalOperationId != null;
}
