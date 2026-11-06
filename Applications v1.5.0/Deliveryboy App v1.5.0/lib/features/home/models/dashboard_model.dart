import 'package:deliveryboy/utils/extensions/num_extensions.dart';

/// Top-level response model for the home dashboard endpoint.
class DashboardModel {
  int? status;
  String? message;
  DashboardDataModel? data;
  int? total;

  DashboardModel({this.status, this.message, this.data, this.total});

  DashboardModel.fromJson(Map<String, dynamic> json) {
    status = toSafeIntOrNull(json['status']);
    message = json['message']?.toString();
    data = json['data'] != null
        ? DashboardDataModel.fromJson(json['data'])
        : null;
    total = toSafeIntOrNull(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status'] = status;
    data['message'] = message;
    if (this.data != null) {
      data['data'] = this.data!.toJson();
    }
    data['total'] = total;
    return data;
  }
}

class DashboardDataModel {
  Profile? profile;
  Today? today;
  Wallet? wallet;
  Cash? cash;
  Salary? salary;
  Orders? orders;
  List<StatusBreakdown>? statusBreakdown;
  Returns? returns;
  EarningsTrend? earningsTrend;
  List<RecentFundTransfers>? recentFundTransfers;
  List<RecentCash>? recentCash;
  List<RecentWithdrawals>? recentWithdrawals;

  DashboardDataModel({
    this.profile,
    this.today,
    this.wallet,
    this.cash,
    this.salary,
    this.orders,
    this.statusBreakdown,
    this.returns,
    this.earningsTrend,
    this.recentFundTransfers,
    this.recentCash,
    this.recentWithdrawals,
  });

  DashboardDataModel.fromJson(Map<String, dynamic> json) {
    profile = json['profile'] != null
        ? Profile.fromJson(json['profile'])
        : null;
    today = json['today'] != null ? Today.fromJson(json['today']) : null;
    wallet = json['wallet'] != null ? Wallet.fromJson(json['wallet']) : null;
    cash = json['cash'] != null ? Cash.fromJson(json['cash']) : null;
    salary = json['salary'] != null ? Salary.fromJson(json['salary']) : null;
    orders = json['orders'] != null ? Orders.fromJson(json['orders']) : null;
    if (json['status_breakdown'] != null) {
      statusBreakdown = <StatusBreakdown>[];
      json['status_breakdown'].forEach((v) {
        statusBreakdown!.add(StatusBreakdown.fromJson(v));
      });
    }
    returns = json['returns'] != null
        ? Returns.fromJson(json['returns'])
        : null;
    earningsTrend = json['earnings_trend'] != null
        ? EarningsTrend.fromJson(json['earnings_trend'])
        : null;
    if (json['recent_fund_transfers'] != null) {
      recentFundTransfers = <RecentFundTransfers>[];
      json['recent_fund_transfers'].forEach((v) {
        recentFundTransfers!.add(RecentFundTransfers.fromJson(v));
      });
    }
    if (json['recent_cash'] != null) {
      recentCash = <RecentCash>[];
      json['recent_cash'].forEach((v) {
        recentCash!.add(RecentCash.fromJson(v));
      });
    }
    if (json['recent_withdrawals'] != null) {
      recentWithdrawals = <RecentWithdrawals>[];
      json['recent_withdrawals'].forEach((v) {
        recentWithdrawals!.add(RecentWithdrawals.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (profile != null) {
      data['profile'] = profile!.toJson();
    }
    if (today != null) {
      data['today'] = today!.toJson();
    }
    if (wallet != null) {
      data['wallet'] = wallet!.toJson();
    }
    if (cash != null) {
      data['cash'] = cash!.toJson();
    }
    if (salary != null) {
      data['salary'] = salary!.toJson();
    }
    if (orders != null) {
      data['orders'] = orders!.toJson();
    }
    if (statusBreakdown != null) {
      data['status_breakdown'] = statusBreakdown!
          .map((v) => v.toJson())
          .toList();
    }
    if (returns != null) {
      data['returns'] = returns!.toJson();
    }
    if (earningsTrend != null) {
      data['earnings_trend'] = earningsTrend!.toJson();
    }
    if (recentFundTransfers != null) {
      data['recent_fund_transfers'] = recentFundTransfers!
          .map((v) => v.toJson())
          .toList();
    }
    if (recentCash != null) {
      data['recent_cash'] = recentCash!.map((v) => v.toJson()).toList();
    }
    if (recentWithdrawals != null) {
      data['recent_withdrawals'] = recentWithdrawals!
          .map((v) => v.toJson())
          .toList();
    }
    return data;
  }
}

class Profile {
  int? id;
  String? name;
  int? status;
  String? country;
  String? currency;
  String? currencyCode;
  int? bonusType;

  Profile({
    this.id,
    this.name,
    this.status,
    this.country,
    this.currency,
    this.currencyCode,
    this.bonusType,
  });

  Profile.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    name = json['name']?.toString();
    status = toSafeIntOrNull(json['status']);
    country = json['country']?.toString();
    currency = json['currency']?.toString();
    currencyCode = json['currency_code']?.toString();
    bonusType = toSafeIntOrNull(json['bonus_type']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['name'] = name;
    data['status'] = status;
    data['country'] = country;
    data['currency'] = currency;
    data['currency_code'] = currencyCode;
    data['bonus_type'] = bonusType;
    return data;
  }
}

class Today {
  double? earnings;
  int? delivered;
  double? cash;
  int? orders;

  Today({this.earnings, this.delivered, this.cash, this.orders});

  Today.fromJson(Map<String, dynamic> json) {
    earnings = toSafeDouble(json['earnings']);
    delivered = toSafeIntOrNull(json['delivered']);
    cash = toSafeDouble(json['cash']);
    orders = toSafeIntOrNull(json['orders']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['earnings'] = earnings;
    data['delivered'] = delivered;
    data['cash'] = cash;
    data['orders'] = orders;
    return data;
  }
}

class Wallet {
  double? balance;
  double? totalEarned;
  double? totalDebited;
  double? pendingWithdrawal;
  double? totalWithdrawn;
  double? available;

  Wallet({
    this.balance,
    this.totalEarned,
    this.totalDebited,
    this.pendingWithdrawal,
    this.totalWithdrawn,
    this.available,
  });

  Wallet.fromJson(Map<String, dynamic> json) {
    balance = toSafeDouble(json['balance']);
    totalEarned = toSafeDouble(json['total_earned']);
    totalDebited = toSafeDouble(json['total_debited']);
    pendingWithdrawal = toSafeDouble(json['pending_withdrawal']);
    totalWithdrawn = toSafeDouble(json['total_withdrawn']);
    available = toSafeDouble(json['available']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['balance'] = balance;
    data['total_earned'] = totalEarned;
    data['total_debited'] = totalDebited;
    data['pending_withdrawal'] = pendingWithdrawal;
    data['total_withdrawn'] = totalWithdrawn;
    data['available'] = available;
    return data;
  }
}

class Cash {
  double? inHand;
  double? totalCollected;
  double? totalDeposited;
  double? totalSettled;

  Cash({
    this.inHand,
    this.totalCollected,
    this.totalDeposited,
    this.totalSettled,
  });

  Cash.fromJson(Map<String, dynamic> json) {
    inHand = toSafeDouble(json['in_hand']);
    totalCollected = toSafeDouble(json['total_collected']);
    totalDeposited = toSafeDouble(json['total_deposited']);
    totalSettled = toSafeDouble(json['total_settled']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['in_hand'] = inHand;
    data['total_collected'] = totalCollected;
    data['total_deposited'] = totalDeposited;
    data['total_settled'] = totalSettled;
    return data;
  }
}

class Salary {
  double? totalPaid;
  String? lastPaidOn;
  double? lastAmount;

  Salary({this.totalPaid, this.lastPaidOn, this.lastAmount});

  Salary.fromJson(Map<String, dynamic> json) {
    totalPaid = toSafeDouble(json['total_paid']);
    lastPaidOn = json['last_paid_on']?.toString();
    lastAmount = toSafeDouble(json['last_amount']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total_paid'] = totalPaid;
    data['last_paid_on'] = lastPaidOn;
    data['last_amount'] = lastAmount;
    return data;
  }
}

class Orders {
  int? total;
  int? active;
  int? delivered;
  int? cancelled;
  int? quick;
  int? ecommerce;

  Orders({
    this.total,
    this.active,
    this.delivered,
    this.cancelled,
    this.quick,
    this.ecommerce,
  });

  Orders.fromJson(Map<String, dynamic> json) {
    total = toSafeIntOrNull(json['total']);
    active = toSafeIntOrNull(json['active']);
    delivered = toSafeIntOrNull(json['delivered']);
    cancelled = toSafeIntOrNull(json['cancelled']);
    quick = toSafeIntOrNull(json['quick']);
    ecommerce = toSafeIntOrNull(json['ecommerce']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total'] = total;
    data['active'] = active;
    data['delivered'] = delivered;
    data['cancelled'] = cancelled;
    data['quick'] = quick;
    data['ecommerce'] = ecommerce;
    return data;
  }
}

class StatusBreakdown {
  int? statusId;
  String? name;
  int? count;

  StatusBreakdown({this.statusId, this.name, this.count});

  StatusBreakdown.fromJson(Map<String, dynamic> json) {
    statusId = toSafeIntOrNull(json['status_id']);
    name = json['name']?.toString();
    count = toSafeIntOrNull(json['count']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['status_id'] = statusId;
    data['name'] = name;
    data['count'] = count;
    return data;
  }
}

class Returns {
  int? total;
  int? completed;
  int? pending;
  List<StatusBreakdown>? breakdown;

  Returns({this.total, this.completed, this.pending, this.breakdown});

  Returns.fromJson(Map<String, dynamic> json) {
    total = toSafeIntOrNull(json['total']);
    completed = toSafeIntOrNull(json['completed']);
    pending = toSafeIntOrNull(json['pending']);
    if (json['breakdown'] != null) {
      breakdown = <StatusBreakdown>[];
      json['breakdown'].forEach((v) {
        breakdown!.add(StatusBreakdown.fromJson(v));
      });
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['total'] = total;
    data['completed'] = completed;
    data['pending'] = pending;
    if (breakdown != null) {
      data['breakdown'] = breakdown!.map((v) => v.toJson()).toList();
    }
    return data;
  }
}

class EarningsTrend {
  List<String>? labels;
  List<int>? data;
  String? trend;
  double? total;

  EarningsTrend({this.labels, this.data, this.trend, this.total});

  EarningsTrend.fromJson(Map<String, dynamic> json) {
    labels = (json['labels'] as List?)?.cast<String>();
    data = (json['data'] as List?)?.map((e) => (e as num).round()).toList();
    trend = json['trend']?.toString();
    total = toSafeDouble(json['total']);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['labels'] = labels;
    data['data'] = this.data;
    data['trend'] = trend;
    data['total'] = total;
    return data;
  }
}

class RecentCash {
  int? id;
  int? orderId;
  String? type;
  double? amount;
  String? date;

  RecentCash({this.id, this.orderId, this.type, this.amount, this.date});

  RecentCash.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    orderId = toSafeIntOrNull(json['order_id']);
    type = json['type']?.toString();
    amount = toSafeDouble(json['amount']);
    date = json['date']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['order_id'] = orderId;
    data['type'] = type;
    data['amount'] = amount;
    data['date'] = date;
    return data;
  }
}

class RecentFundTransfers {
  int? id;
  String? type;
  double? amount;
  String? message;
  String? date;

  RecentFundTransfers({
    this.id,
    this.type,
    this.amount,
    this.message,
    this.date,
  });

  RecentFundTransfers.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    type = json['type']?.toString();
    amount = toSafeDouble(json['amount']);
    message = json['message']?.toString();
    date = json['date']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['type'] = type;
    data['amount'] = amount;
    data['message'] = message;
    data['date'] = date;
    return data;
  }
}

class RecentWithdrawals {
  int? id;
  double? amount;
  int? status;
  String? date;

  RecentWithdrawals({this.id, this.amount, this.status, this.date});

  RecentWithdrawals.fromJson(Map<String, dynamic> json) {
    id = toSafeIntOrNull(json['id']);
    amount = toSafeDouble(json['amount']);
    status = toSafeIntOrNull(json['status']);
    date = json['date']?.toString();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['id'] = id;
    data['amount'] = amount;
    data['status'] = status;
    data['date'] = date;
    return data;
  }
}
