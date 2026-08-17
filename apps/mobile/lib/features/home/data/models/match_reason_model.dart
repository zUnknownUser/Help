import '../../domain/entities/match_reason.dart';
import 'json_reader.dart';

class MatchReasonModel {
  const MatchReasonModel({required this.code, required this.label});

  factory MatchReasonModel.fromJson(Map<String, dynamic> json) =>
      MatchReasonModel(
        code: JsonReader.string(json, 'code'),
        label: JsonReader.string(json, 'label'),
      );

  final String code;
  final String label;

  MatchReason toEntity() => MatchReason(code: code, label: label);
}
