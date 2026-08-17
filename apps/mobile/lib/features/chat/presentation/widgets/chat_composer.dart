import 'package:flutter/material.dart';

import '../../../../core/design_system/foundations/app_colors.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSend,
    required this.editing,
    required this.onCancelEdit,
    required this.recording,
    required this.recordingDuration,
    required this.onRecordStart,
    required this.onRecordStop,
    required this.onRecordCancel,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onSend;
  final bool editing;
  final VoidCallback onCancelEdit;
  final bool recording;
  final Duration recordingDuration;
  final VoidCallback onRecordStart;
  final VoidCallback onRecordStop;
  final VoidCallback onRecordCancel;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(12, 6, 10, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (editing)
            Row(
              children: [
                const Icon(Icons.edit_outlined, size: 17),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Editando mensagem',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  tooltip: 'Cancelar edicao',
                  onPressed: onCancelEdit,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          if (recording)
            _RecordingBar(
              duration: recordingDuration,
              onCancel: onRecordCancel,
              onSend: onRecordStop,
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    onChanged: onChanged,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Mensagem',
                      prefixIcon: Icon(Icons.sentiment_satisfied_alt_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) {
                    final canSend =
                        editing || controller.text.trim().isNotEmpty;
                    if (canSend) {
                      return IconButton.filled(
                        tooltip: editing ? 'Salvar edicao' : 'Enviar',
                        onPressed: onSend,
                        icon: Icon(
                          editing ? Icons.check_rounded : Icons.send_rounded,
                        ),
                      );
                    }
                    return GestureDetector(
                      onLongPressStart: (_) => onRecordStart(),
                      onLongPressEnd: (_) => onRecordStop(),
                      child: IconButton.filled(
                        tooltip: 'Gravar mensagem de voz',
                        onPressed: onRecordStart,
                        icon: const Icon(Icons.mic_rounded),
                      ),
                    );
                  },
                ),
              ],
            ),
        ],
      ),
    ),
  );
}

class _RecordingBar extends StatelessWidget {
  const _RecordingBar({
    required this.duration,
    required this.onCancel,
    required this.onSend,
  });

  final Duration duration;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Cancelar gravacao',
        onPressed: onCancel,
        icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
      ),
      const SizedBox(width: 4),
      const _RecordingPulse(),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          _format(duration),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      const Text(
        'Gravando...',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      ),
      const SizedBox(width: 10),
      IconButton.filled(
        tooltip: 'Enviar audio',
        onPressed: onSend,
        icon: const Icon(Icons.send_rounded),
      ),
    ],
  );

  static String _format(Duration value) =>
      '${value.inMinutes}:${value.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

class _RecordingPulse extends StatelessWidget {
  const _RecordingPulse();

  @override
  Widget build(BuildContext context) => Container(
    width: 10,
    height: 10,
    decoration: const BoxDecoration(
      color: AppColors.danger,
      shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Color(0x55D92D20), blurRadius: 8)],
    ),
  );
}
