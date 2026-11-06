import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:deliveryboy/features/home/models/dashboard_model.dart';

import '../../../helpers/test_logging.dart';

void main() {
  late Map<String, dynamic> json;
  late DashboardModel model;

  setUp(() {
    // Mirrors the real /dashboard response — refresh
    // test/fixtures/home/dashboard_response.json when the backend contract
    // changes, instead of editing these tests.
    json =
        jsonDecode(
              File(
                'test/fixtures/home/dashboard_response.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    model = DashboardModel.fromJson(json);
  });

  tearDownAll(() => printTestDivider('=== All tests run! ==='));

  test('parses the envelope', () {
    printTestDivider('parses the envelope');
    printTestLog('status  → expected: 1, actual: ${model.status}');
    expect(model.status, 1);
    printTestLog('message → expected: "Success", actual: "${model.message}"');
    expect(model.message, 'Success');
    printTestLog('total   → expected: 1, actual: ${model.total}');
    expect(model.total, 1);
  });

  test('parses the profile block', () {
    printTestDivider('parses the profile block');
    final profile = model.data!.profile!;
    printTestLog('id           → expected: 2, actual: ${profile.id}');
    expect(profile.id, 2);
    printTestLog('name         → expected: "Alex Johnson", actual: "${profile.name}"');
    expect(profile.name, 'Alex Johnson');
    printTestLog('status       → expected: 1, actual: ${profile.status}');
    expect(profile.status, 1);
    printTestLog('country      → expected: "India", actual: "${profile.country}"');
    expect(profile.country, 'India');
    printTestLog('currency     → expected: "₹", actual: "${profile.currency}"');
    expect(profile.currency, '₹');
    printTestLog('currencyCode → expected: "INR", actual: "${profile.currencyCode}"');
    expect(profile.currencyCode, 'INR');
    printTestLog('bonusType    → expected: 1, actual: ${profile.bonusType}');
    expect(profile.bonusType, 1);
  });

  test("parses today's figures", () {
    printTestDivider("parses today's figures");
    final today = model.data!.today!;
    printTestLog('earnings  → expected: 96.7, actual: ${today.earnings}');
    expect(today.earnings, 96.7);
    printTestLog('delivered → expected: 2, actual: ${today.delivered}');
    expect(today.delivered, 2);
    printTestLog('cash      → expected: 706.5, actual: ${today.cash}');
    expect(today.cash, 706.5);
    printTestLog('orders    → expected: 2, actual: ${today.orders}');
    expect(today.orders, 2);
  });

  test('parses the wallet block', () {
    printTestDivider('parses the wallet block');
    final wallet = model.data!.wallet!;
    printTestLog('balance           → expected: 462.95, actual: ${wallet.balance}');
    expect(wallet.balance, 462.95);
    printTestLog('totalEarned       → expected: 20862.95, actual: ${wallet.totalEarned}');
    expect(wallet.totalEarned, 20862.95);
    printTestLog('totalDebited      → expected: 400.0, actual: ${wallet.totalDebited}');
    expect(wallet.totalDebited, 400.0);
    printTestLog('pendingWithdrawal → expected: 310.0, actual: ${wallet.pendingWithdrawal}');
    expect(wallet.pendingWithdrawal, 310.0);
    printTestLog('available         → expected: 152.95, actual: ${wallet.available}');
    expect(wallet.available, 152.95);
  });

  test('parses the cash block', () {
    printTestDivider('parses the cash block');
    final cash = model.data!.cash!;
    printTestLog('inHand         → expected: 16703.34, actual: ${cash.inHand}');
    expect(cash.inHand, 16703.34);
    printTestLog('totalCollected → expected: 315360.49, actual: ${cash.totalCollected}');
    expect(cash.totalCollected, 315360.49);
    printTestLog('totalDeposited → expected: 298657.15, actual: ${cash.totalDeposited}');
    expect(cash.totalDeposited, 298657.15);
    printTestLog('totalSettled   → expected: 298657.15, actual: ${cash.totalSettled}');
    expect(cash.totalSettled, 298657.15);
  });

  test('parses the salary block, coercing whole numbers to double', () {
    printTestDivider('parses the salary block, coercing whole numbers to double');
    final salary = model.data!.salary!;
    printTestLog('totalPaid  → expected: 20000.0, actual: ${salary.totalPaid}');
    expect(salary.totalPaid, 20000.0);
    printTestLog('lastPaidOn → expected: "2026-08-10", actual: "${salary.lastPaidOn}"');
    expect(salary.lastPaidOn, '2026-08-10');
    printTestLog('lastAmount → expected: 20000.0, actual: ${salary.lastAmount}');
    expect(salary.lastAmount, 20000.0);
  });

  test('parses the order counters', () {
    printTestDivider('parses the order counters');
    final orders = model.data!.orders!;
    printTestLog('total     → expected: 31, actual: ${orders.total}');
    expect(orders.total, 31);
    printTestLog('active    → expected: 6, actual: ${orders.active}');
    expect(orders.active, 6);
    printTestLog('delivered → expected: 25, actual: ${orders.delivered}');
    expect(orders.delivered, 25);
    printTestLog('cancelled → expected: 0, actual: ${orders.cancelled}');
    expect(orders.cancelled, 0);
    printTestLog('quick     → expected: 26, actual: ${orders.quick}');
    expect(orders.quick, 26);
    printTestLog('ecommerce → expected: 5, actual: ${orders.ecommerce}');
    expect(orders.ecommerce, 5);
  });

  test('parses every status-breakdown entry in order', () {
    printTestDivider('parses every status-breakdown entry in order');
    final breakdown = model.data!.statusBreakdown!;
    printTestLog('length → expected: 3, actual: ${breakdown.length}');
    expect(breakdown.length, 3);
    printTestLog(
      'first → expected: 5/"Out For Delivery"/5, actual: ${breakdown.first.statusId}/"${breakdown.first.name}"/${breakdown.first.count}',
    );
    expect(breakdown.first.statusId, 5);
    expect(breakdown.first.name, 'Out For Delivery');
    expect(breakdown.first.count, 5);
    // A zero count still comes through as an entry rather than being dropped.
    printTestLog('last count → expected: 0, actual: ${breakdown.last.count}');
    expect(breakdown.last.count, 0);
  });

  test('parses the returns block including its nested breakdown', () {
    printTestDivider('parses the returns block including its nested breakdown');
    final returns = model.data!.returns!;
    printTestLog('total     → expected: 0, actual: ${returns.total}');
    expect(returns.total, 0);
    printTestLog('completed → expected: 0, actual: ${returns.completed}');
    expect(returns.completed, 0);
    printTestLog('pending   → expected: 0, actual: ${returns.pending}');
    expect(returns.pending, 0);
    printTestLog('breakdown length → expected: 3, actual: ${returns.breakdown!.length}');
    expect(returns.breakdown!.length, 3);
    printTestLog(
      'first breakdown name → expected: "Out for Pickup", actual: "${returns.breakdown!.first.name}"',
    );
    expect(returns.breakdown!.first.name, 'Out for Pickup');
  });

  test('parses the earnings trend, rounding each data point to an int', () {
    printTestDivider('parses the earnings trend, rounding each data point to an int');
    final trend = model.data!.earningsTrend!;
    printTestLog('labels length → expected: 7, actual: ${trend.labels!.length}');
    expect(trend.labels!.length, 7);
    printTestLog('first label → expected: "11 Aug", actual: "${trend.labels!.first}"');
    expect(trend.labels!.first, '11 Aug');
    printTestLog('data length → expected: 7, actual: ${trend.data!.length}');
    expect(trend.data!.length, 7);
    // EarningsTrend.data is List<int> and rounds: the chart loses the paise
    // that `total` keeps (96.7 -> 97, 526.25 -> 526).
    printTestLog('first data point → expected: 526 (from 526.25), actual: ${trend.data!.first}');
    expect(trend.data!.first, 526);
    printTestLog('last data point  → expected: 97 (from 96.7), actual: ${trend.data!.last}');
    expect(trend.data!.last, 97);
    printTestLog('trend → expected: "7", actual: "${trend.trend}"');
    expect(trend.trend, '7');
    printTestLog('total → expected: 862.95 (unrounded), actual: ${trend.total}');
    expect(trend.total, 862.95);
  });

  test('parses the recent cash entries', () {
    printTestDivider('parses the recent cash entries');
    final cash = model.data!.recentCash!;
    printTestLog('length → expected: 5, actual: ${cash.length}');
    expect(cash.length, 5);
    printTestLog('first id      → expected: 35, actual: ${cash.first.id}');
    expect(cash.first.id, 35);
    printTestLog('first orderId → expected: 187, actual: ${cash.first.orderId}');
    expect(cash.first.orderId, 187);
    printTestLog('first type    → expected: "COD", actual: "${cash.first.type}"');
    expect(cash.first.type, 'COD');
    printTestLog('first amount  → expected: 567.0, actual: ${cash.first.amount}');
    expect(cash.first.amount, 567.0);
    printTestLog('first date    → expected: "2026-08-17 07:43:17", actual: "${cash.first.date}"');
    expect(cash.first.date, '2026-08-17 07:43:17');
  });

  test('parses the recent withdrawals', () {
    printTestDivider('parses the recent withdrawals');
    final withdrawals = model.data!.recentWithdrawals!;
    printTestLog('length → expected: 5, actual: ${withdrawals.length}');
    expect(withdrawals.length, 5);
    printTestLog('first amount → expected: 200.0, actual: ${withdrawals.first.amount}');
    expect(withdrawals.first.amount, 200.0);
    printTestLog('first status → expected: 0 (pending), actual: ${withdrawals.first.status}');
    expect(withdrawals.first.status, 0);
    printTestLog('last status  → expected: 1 (settled), actual: ${withdrawals.last.status}');
    expect(withdrawals.last.status, 1);
  });

  test('leaves recentFundTransfers null — the response sends recent_settlements', () {
    printTestDivider(
      'leaves recentFundTransfers null — the response sends recent_settlements',
    );
    // Documents a real key mismatch: DashboardDataModel.fromJson reads
    // `recent_fund_transfers`, but the API sends `recent_settlements`, so this
    // list never populates. Nothing in the UI reads it today, which is why it
    // has gone unnoticed. Change the key (and RecentFundTransfers.id to a
    // String — the real ids look like "W-34") before wiring it to a screen.
    printTestLog(
      'response key → expected: "recent_settlements" present, actual: ${json['data'].containsKey('recent_settlements')}',
    );
    expect((json['data'] as Map).containsKey('recent_settlements'), isTrue);
    printTestLog(
      'recentFundTransfers → expected: null, actual: ${model.data!.recentFundTransfers}',
    );
    expect(model.data!.recentFundTransfers, isNull);
  });

  test('survives a response whose data block is missing entirely', () {
    printTestDivider('survives a response whose data block is missing entirely');
    final empty = DashboardModel.fromJson(const {
      'status': 1,
      'message': 'Success',
    });
    printTestLog('data  → expected: null, actual: ${empty.data}');
    expect(empty.data, isNull);
    printTestLog('total → expected: null, actual: ${empty.total}');
    expect(empty.total, isNull);
  });

  test('survives a data block with every section missing', () {
    printTestDivider('survives a data block with every section missing');
    final sparse = DashboardModel.fromJson(const {
      'status': 1,
      'data': <String, dynamic>{},
    });
    final data = sparse.data!;
    printTestLog('profile → expected: null, actual: ${data.profile}');
    expect(data.profile, isNull);
    printTestLog('today   → expected: null, actual: ${data.today}');
    expect(data.today, isNull);
    printTestLog('statusBreakdown → expected: null, actual: ${data.statusBreakdown}');
    expect(data.statusBreakdown, isNull);
    printTestLog('earningsTrend   → expected: null, actual: ${data.earningsTrend}');
    expect(data.earningsTrend, isNull);
  });

  test('toJson round-trips the sections it carries', () {
    printTestDivider('toJson round-trips the sections it carries');
    final roundTripped = DashboardModel.fromJson(model.toJson());

    printTestLog(
      'profile name → expected: "${model.data!.profile!.name}", actual: "${roundTripped.data!.profile!.name}"',
    );
    expect(roundTripped.data!.profile!.name, model.data!.profile!.name);
    printTestLog(
      'wallet balance → expected: ${model.data!.wallet!.balance}, actual: ${roundTripped.data!.wallet!.balance}',
    );
    expect(roundTripped.data!.wallet!.balance, model.data!.wallet!.balance);
    printTestLog(
      'status breakdown length → expected: ${model.data!.statusBreakdown!.length}, actual: ${roundTripped.data!.statusBreakdown!.length}',
    );
    expect(
      roundTripped.data!.statusBreakdown!.length,
      model.data!.statusBreakdown!.length,
    );
    printTestLog(
      'recent cash length → expected: ${model.data!.recentCash!.length}, actual: ${roundTripped.data!.recentCash!.length}',
    );
    expect(
      roundTripped.data!.recentCash!.length,
      model.data!.recentCash!.length,
    );
  });
}
