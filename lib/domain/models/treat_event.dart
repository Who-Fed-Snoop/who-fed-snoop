import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Built-in 1-tap treat presets plus custom treat option.
enum TreatPreset {
  trainingTreat(
    id: 'training_treat',
    label: 'Training Treat',
    emoji: '🦴',
    defaultCalories: 15,
  ),
  dentalChew(
    id: 'dental_chew',
    label: 'Dental Chew',
    emoji: '🪥',
    defaultCalories: 85,
  ),
  peanutButterKong(
    id: 'pb_kong',
    label: 'PB Kong',
    emoji: '🥜',
    defaultCalories: 120,
  ),
  crunchyBiscuit(
    id: 'crunchy_biscuit',
    label: 'Crunchy Biscuit',
    emoji: '🍪',
    defaultCalories: 45,
  ),
  custom(
    id: 'custom',
    label: 'Custom Treat',
    emoji: '✨',
    defaultCalories: 30,
  );

  const TreatPreset({
    required this.id,
    required this.label,
    required this.emoji,
    required this.defaultCalories,
  });

  final String id;
  final String label;
  final String emoji;
  final int defaultCalories;

  /// Accepts either `preset.id` (e.g. `'pb_kong'`) or `preset.name` (e.g. `'peanutButterKong'`).
  static TreatPreset fromString(String value) {
    final normalized = value.trim();
    for (final preset in TreatPreset.values) {
      if (preset.id == normalized || preset.name == normalized) {
        return preset;
      }
    }
    return TreatPreset.custom;
  }
}

/// A logged treat event for a household pet, tracked orthogonally from meals.
@immutable
class TreatEvent {
  const TreatEvent({
    required this.id,
    required this.preset,
    required this.label,
    required this.emoji,
    this.quantity = 1,
    required this.caloriesPerUnit,
    required this.logicalDate,
    required this.givenByUid,
    required this.givenByName,
    required this.givenAt,
    this.note,
  });

  /// Unique treat event ID (`treat_{logicalDate}_{ms}_{seq}`).
  final String id;

  /// Preset category for this treat.
  final TreatPreset preset;

  /// Display name of the treat (`1..40` chars).
  final String label;

  /// Emoji badge (`1..8` chars).
  final String emoji;

  /// Number of units given (`1..20`, default `1`).
  final int quantity;

  /// Estimated calories per unit (`0..2000`).
  final int caloriesPerUnit;

  /// Household logical date (`YYYY-MM-DD`), aligned with `MealSchedule.logicalDateFor`.
  final String logicalDate;

  /// UID of the household member who gave the treat.
  final String givenByUid;

  /// Display name of the household member who gave the treat.
  final String givenByName;

  /// Local timestamp when the treat was given.
  final DateTime givenAt;

  /// Optional note or context (`0..140` chars).
  final String? note;

  /// Total estimated calories for this treat log (`quantity * caloriesPerUnit`).
  int get totalCalories => quantity * caloriesPerUnit;

  Map<String, Object?> toJson() => <String, Object?>{
        'id': id,
        'preset': preset.id,
        'label': label,
        'emoji': emoji,
        'quantity': quantity,
        'caloriesPerUnit': caloriesPerUnit,
        'logicalDate': logicalDate,
        'givenByUid': givenByUid,
        'givenByName': givenByName,
        'givenAt': givenAt.toUtc().toIso8601String(),
        if (note != null) 'note': note,
      };

  factory TreatEvent.fromJson(Map<String, Object?> json, {String? fallbackId}) {
    final preset = TreatPreset.fromString(
      (json['preset'] as String?) ?? 'custom',
    );
    final rawLabel = (json['label'] as String?)?.trim();
    final rawEmoji = (json['emoji'] as String?)?.trim();
    final rawNote = (json['note'] as String?)?.trim();

    return TreatEvent(
      id: (json['id'] as String?) ?? fallbackId ?? '',
      preset: preset,
      label: (rawLabel != null && rawLabel.isNotEmpty) ? rawLabel : preset.label,
      emoji: (rawEmoji != null && rawEmoji.isNotEmpty) ? rawEmoji : preset.emoji,
      quantity: ((json['quantity'] as num?)?.toInt() ?? 1).clamp(1, 20),
      caloriesPerUnit:
          ((json['caloriesPerUnit'] as num?)?.toInt() ?? preset.defaultCalories)
              .clamp(0, 2000),
      logicalDate: (json['logicalDate'] as String?) ?? '',
      givenByUid: (json['givenByUid'] as String?) ?? '',
      givenByName: (json['givenByName'] as String?) ?? 'Someone',
      givenAt: _parseDateTime(json['givenAt']),
      note: (rawNote != null && rawNote.isNotEmpty) ? rawNote : null,
    );
  }

  static DateTime _parseDateTime(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate().toLocal();
    }
    if (raw is DateTime) {
      return raw.toLocal();
    }
    if (raw is String) {
      return DateTime.tryParse(raw)?.toLocal() ?? DateTime.now();
    }
    return DateTime.now();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TreatEvent &&
          id == other.id &&
          preset == other.preset &&
          label == other.label &&
          emoji == other.emoji &&
          quantity == other.quantity &&
          caloriesPerUnit == other.caloriesPerUnit &&
          logicalDate == other.logicalDate &&
          givenByUid == other.givenByUid &&
          givenByName == other.givenByName &&
          givenAt == other.givenAt &&
          note == other.note;

  @override
  int get hashCode => Object.hash(
        id,
        preset,
        label,
        emoji,
        quantity,
        caloriesPerUnit,
        logicalDate,
        givenByUid,
        givenByName,
        givenAt,
        note,
      );
}

