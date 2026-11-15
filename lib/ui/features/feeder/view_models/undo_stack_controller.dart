import 'dart:async';

import 'package:flutter/foundation.dart';

/// Distinguishes whether a pending 10-second Undo target is a meal or a treat.
enum UndoKind { meal, treat }

/// Immutable entry on the 10-second LIFO Undo stack.
@immutable
class PendingUndoEntry {
  const PendingUndoEntry({
    required this.entryId,
    required this.kind,
    required this.label,
    String? emoji,
    this.householdId = '',
    this.secondsRemaining = 10,
  }) : emoji = emoji ?? (kind == UndoKind.meal ? '🥣' : '🦴');

  final String entryId;
  final UndoKind kind;
  final String label;
  final String emoji;
  final String householdId;
  final int secondsRemaining;

  PendingUndoEntry tick() => PendingUndoEntry(
        entryId: entryId,
        kind: kind,
        label: label,
        emoji: emoji,
        householdId: householdId,
        secondsRemaining: secondsRemaining - 1,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PendingUndoEntry &&
          entryId == other.entryId &&
          kind == other.kind &&
          label == other.label &&
          emoji == other.emoji &&
          householdId == other.householdId &&
          secondsRemaining == other.secondsRemaining;

  @override
  int get hashCode => Object.hash(
        entryId,
        kind,
        label,
        emoji,
        householdId,
        secondsRemaining,
      );
}

/// Manages the non-clobbering 10-second LIFO Undo stack and its 1s countdown timer.
class UndoStackController {
  UndoStackController({required VoidCallback onChanged}) : _onChanged = onChanged;

  final VoidCallback _onChanged;
  final List<PendingUndoEntry> _stack = <PendingUndoEntry>[];
  Timer? _timer;
  bool _isDisposed = false;

  /// Read-only view of active Undo entries (oldest to newest).
  List<PendingUndoEntry> get entries => List<PendingUndoEntry>.unmodifiable(_stack);

  /// Top-of-stack Undo entry to revert next.
  PendingUndoEntry? get activeEntry => _stack.isEmpty ? null : _stack.last;

  int get length => _stack.length;

  bool get isEmpty => _stack.isEmpty;

  int get secondsRemaining => _stack.isEmpty ? 0 : _stack.last.secondsRemaining;

  bool get canUndo => _stack.isNotEmpty && _stack.last.secondsRemaining > 0;

  /// Formatted status copy for the Undo bar (e.g. `'🥣 Logged Breakfast! Undo within 8s'`
  /// or `'🥜 Logged PB Kong! Undo within 9s (+1 more)'`).
  String get bannerText {
    final top = activeEntry;
    if (top == null || top.secondsRemaining <= 0) return '';
    final extraCount = _stack.length - 1;
    final moreSuffix = extraCount > 0 ? ' (+$extraCount more)' : '';
    return '${top.emoji} Logged ${top.label}! Undo within ${top.secondsRemaining}s$moreSuffix';
  }

  /// Pushes [entry] onto the LIFO stack (deduplicating matching kind + id) and starts the 1s timer.
  void push(PendingUndoEntry entry) {
    if (_isDisposed) return;
    _stack.removeWhere(
      (existing) => existing.kind == entry.kind && existing.entryId == entry.entryId,
    );
    _stack.add(entry);
    _onChanged();

    _timer ??= Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  /// Pops the top entry from the stack and stops the timer if the stack becomes empty.
  PendingUndoEntry? pop() {
    if (_stack.isEmpty) return null;
    final entry = _stack.removeLast();
    if (_stack.isEmpty) {
      _cancelTimer();
    }
    return entry;
  }

  /// Removes any entry matching [entryId] and [kind] (e.g. when a treat is deleted directly).
  void removeById(String entryId, {required UndoKind kind}) {
    _stack.removeWhere(
      (entry) => entry.kind == kind && entry.entryId == entryId,
    );
    if (_stack.isEmpty) {
      _cancelTimer();
    }
  }

  /// Clears all pending undo entries and cancels any active countdown timer.
  void clear() {
    _cancelTimer();
    _stack.clear();
  }

  void dispose() {
    _isDisposed = true;
    clear();
  }

  void _onTick(Timer _) {
    if (_isDisposed) {
      clear();
      return;
    }
    for (var i = _stack.length - 1; i >= 0; i--) {
      final next = _stack[i].tick();
      if (next.secondsRemaining <= 0) {
        _stack.removeAt(i);
      } else {
        _stack[i] = next;
      }
    }
    if (_stack.isEmpty) {
      _cancelTimer();
    }
    _onChanged();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
