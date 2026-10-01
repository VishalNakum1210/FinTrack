import 'money.dart';
import 'package:flutter/foundation.dart';

/// Represents a participant in a split bill or group trip.
@immutable
class SplitParticipant {
  final String phone;
  final String name;
  final bool isMe;

  const SplitParticipant({
    required this.phone,
    required this.name,
    this.isMe = false,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitParticipant &&
          runtimeType == other.runtimeType &&
          phone == other.phone;

  @override
  int get hashCode => phone.hashCode;

  @override
  String toString() => 'SplitParticipant($name, phone: $phone, isMe: $isMe)';
}

/// Represents a single expense entry within a multi-split session or trip.
@immutable
class GroupExpense {
  final String id;
  final String title;
  final double amount;
  final String category;
  final DateTime date;
  final SplitParticipant payer;
  final List<SplitParticipant> participants;
  final Map<String, double>? customShares; // phone -> exact share

  const GroupExpense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.date,
    required this.payer,
    required this.participants,
    this.customShares,
  });

  void validate() {
    final amountPaise = Money.tryPaise(amount);
    if (amountPaise == null ||
        amountPaise <= 0 ||
        participants.isEmpty ||
        participants.map((p) => p.phone).toSet().length !=
            participants.length) {
      throw ArgumentError('Invalid amount or duplicate/empty participants');
    }
    if (customShares != null) {
      if (customShares!.length != participants.length ||
          !participants.every((p) => customShares!.containsKey(p.phone))) {
        throw ArgumentError('Every participant needs an exact share');
      }
      int sum = 0;
      for (final value in customShares!.values) {
        final cents = Money.tryPaise(value);
        if (cents == null || cents < 0) {
          throw ArgumentError('Invalid custom share');
        }
        sum += cents;
      }
      if (sum != amountPaise) {
        throw ArgumentError('Custom shares must equal the bill total');
      }
    }
  }

  /// Computes the share for a specific participant in this expense.
  double shareFor(SplitParticipant participant) {
    validate();
    if (!participants.contains(participant)) return 0.0;
    if (customShares != null && customShares!.containsKey(participant.phone)) {
      return customShares![participant.phone] ?? 0.0;
    }
    if (participants.isEmpty) return 0.0;
    final index = participants.indexOf(participant);
    final totalCents = Money.paise(amount);
    final baseCents = totalCents ~/ participants.length;
    final remainder = totalCents % participants.length;
    final participantCents = baseCents + (index < remainder ? 1 : 0);
    return participantCents / 100.0;
  }
}

/// A single directional debt line (e.g. "Give ₹100 to Rahul" or "Get ₹500 from You").
@immutable
class PersonDebtLine {
  final SplitParticipant otherPerson;
  final double amount;
  final bool
  isGive; // true: this person gives to otherPerson; false: this person gets from otherPerson
  final String reason;

  const PersonDebtLine({
    required this.otherPerson,
    required this.amount,
    required this.isGive,
    required this.reason,
  });

  @override
  String toString() =>
      '${isGive ? "Give" : "Get"} ₹$amount ${isGive ? "to" : "from"} ${otherPerson.name} ($reason)';
}

/// Person-Centric settlement summary for a specific participant.
@immutable
class PersonSettlement {
  final SplitParticipant person;
  final double totalPaid;
  final double totalConsumed;
  final double
  netBalance; // positive = gets money overall, negative = owes money overall
  final List<PersonDebtLine> giveLines;
  final List<PersonDebtLine> getLines;

  const PersonSettlement({
    required this.person,
    required this.totalPaid,
    required this.totalConsumed,
    required this.netBalance,
    required this.giveLines,
    required this.getLines,
  });

  bool get isSettled => Money.paise(netBalance) == 0;
  bool get willGet => Money.paise(netBalance) > 0;
  bool get willGive => Money.paise(netBalance) < 0;
}

/// Core calculation engine for multi-payer group splits and per-person breakdown.
class SplitHelper {
  /// Calculates person-centric settlements for all participants across multiple expenses
  /// using bilateral pairwise netting (e.g. if A owes B 200 and B owes A 500, only 1 net line
  /// "A gets 300 from B" is generated, with at most N-1 net lines per person).
  static List<PersonSettlement> calculatePersonSettlements({
    required List<GroupExpense> expenses,
    required List<SplitParticipant> allParticipants,
  }) {
    for (final expense in expenses) {
      expense.validate();
    }
    // Unify all declared participants and any participants referenced in expenses
    final Map<String, SplitParticipant> participantMap = {};
    for (final p in allParticipants) {
      participantMap[p.phone] = p;
    }
    for (final exp in expenses) {
      participantMap.putIfAbsent(exp.payer.phone, () => exp.payer);
      for (final c in exp.participants) {
        participantMap.putIfAbsent(c.phone, () => c);
      }
    }

    final effectiveParticipants = participantMap.values.toList();
    if (effectiveParticipants.isEmpty) return [];

    final Map<String, int> totalPaidMap = {};
    final Map<String, int> totalConsumedMap = {};

    // grossDebts[debtorPhone][creditorPhone] = total amount debtor owes creditor
    final Map<String, Map<String, int>> grossDebts = {};
    final Map<String, Set<String>> pairwiseReasons = {};

    for (final p1 in effectiveParticipants) {
      totalPaidMap[p1.phone] = 0;
      totalConsumedMap[p1.phone] = 0;
      grossDebts[p1.phone] = {};
      for (final p2 in effectiveParticipants) {
        grossDebts[p1.phone]![p2.phone] = 0;
      }
    }

    // Step 1: Accumulate total paid, consumed, and directional debts per bill
    for (final exp in expenses) {
      final payer = exp.payer;
      totalPaidMap[payer.phone] =
          (totalPaidMap[payer.phone] ?? 0) + Money.paise(exp.amount);

      for (final consumer in exp.participants) {
        final share = Money.paise(exp.shareFor(consumer));
        totalConsumedMap[consumer.phone] =
            (totalConsumedMap[consumer.phone] ?? 0) + share;

        if (consumer.phone != payer.phone && share > 0.0) {
          grossDebts[consumer.phone]?[payer.phone] =
              (grossDebts[consumer.phone]?[payer.phone] ?? 0) + share;

          final pairKey = _pairKey(consumer.phone, payer.phone);
          pairwiseReasons.putIfAbsent(pairKey, () => <String>{}).add(exp.title);
        }
      }
    }

    // Step 2: Bilateral Netting between every pair of participants
    final List<PersonSettlement> result = [];

    for (final p1 in effectiveParticipants) {
      final paid = totalPaidMap[p1.phone] ?? 0;
      final consumed = totalConsumedMap[p1.phone] ?? 0;
      final rawNet = paid - consumed;
      final net = rawNet / 100;

      final List<PersonDebtLine> giveLines = [];
      final List<PersonDebtLine> getLines = [];

      for (final p2 in effectiveParticipants) {
        if (p1.phone == p2.phone) continue;

        final youOweOther = grossDebts[p1.phone]?[p2.phone] ?? 0;
        final otherOwesYou = grossDebts[p2.phone]?[p1.phone] ?? 0;
        final netDiff = otherOwesYou - youOweOther;

        final pairKey = _pairKey(p1.phone, p2.phone);
        final reasons = (pairwiseReasons[pairKey] ?? <String>{}).join(", ");

        if (netDiff > 0) {
          // p1 gets from p2
          final amount = netDiff / 100;
          getLines.add(
            PersonDebtLine(
              otherPerson: p2,
              amount: amount,
              isGive: false,
              reason: reasons,
            ),
          );
        } else if (netDiff < 0) {
          // p1 gives to p2
          final amount = netDiff.abs() / 100;
          giveLines.add(
            PersonDebtLine(
              otherPerson: p2,
              amount: amount,
              isGive: true,
              reason: reasons,
            ),
          );
        }
      }

      result.add(
        PersonSettlement(
          person: p1,
          totalPaid: paid / 100,
          totalConsumed: consumed / 100,
          netBalance: net,
          giveLines: giveLines,
          getLines: getLines,
        ),
      );
    }

    return result;
  }

  static String _pairKey(String a, String b) {
    return a.compareTo(b) < 0 ? '$a<->$b' : '$b<->$a';
  }
}
