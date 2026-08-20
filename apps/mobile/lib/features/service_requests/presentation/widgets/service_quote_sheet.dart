import 'package:flutter/material.dart';

import '../../../../core/design_system/components/app_button.dart';
import '../../../../core/design_system/foundations/app_colors.dart';
import '../../domain/entities/service_request_negotiation.dart';

class ServiceQuoteSheet extends StatefulWidget {
  const ServiceQuoteSheet({
    required this.currentPriceCents,
    required this.isCounterOffer,
    this.previous,
    super.key,
  });

  final int currentPriceCents;
  final bool isCounterOffer;
  final ServiceQuote? previous;

  @override
  State<ServiceQuoteSheet> createState() => _ServiceQuoteSheetState();
}

class _ServiceQuoteSheetState extends State<ServiceQuoteSheet> {
  final _message = TextEditingController();
  final _form = GlobalKey<FormState>();
  late final List<_QuoteLineEditor> _lines;
  int _validDays = 7;
  String? _error;

  @override
  void initState() {
    super.initState();
    final previous = widget.previous;
    _message.text = previous?.message ?? '';
    _lines = previous != null
        ? previous.items
              .map(
                (item) => _QuoteLineEditor(
                  kind: item.kind,
                  description: item.description,
                  amountCents: item.amountCents,
                ),
              )
              .toList()
        : [
            _QuoteLineEditor(
              kind: ServiceQuoteItemKind.labor,
              description: 'Mão de obra',
              amountCents: widget.currentPriceCents,
            ),
          ];
  }

  @override
  void dispose() {
    _message.dispose();
    for (final line in _lines) {
      line.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        8,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.outline,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.isCounterOffer
                    ? 'Fazer contraproposta'
                    : 'Enviar orçamento',
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                widget.isCounterOffer
                    ? 'Ajuste os itens e valores. A outra pessoa precisará aceitar antes do atendimento.'
                    : 'Detalhe mão de obra, materiais e adicionais para deixar o acordo transparente.',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 18),
              ..._lines.indexed.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _QuoteLineCard(
                    key: ObjectKey(entry.$2),
                    editor: entry.$2,
                    canRemove: _lines.length > 1,
                    onChanged: () => setState(() => _error = null),
                    onRemove: () => _remove(entry.$1),
                  ),
                ),
              ),
              if (_lines.length < maximumServiceQuoteItems)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _add,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Adicionar item'),
                  ),
                ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _message,
                maxLength: 1000,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Mensagem (opcional)',
                  hintText: 'Explique premissas, materiais ou condições',
                ),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                initialValue: _validDays,
                decoration: const InputDecoration(
                  labelText: 'Validade da proposta',
                  prefixIcon: Icon(Icons.schedule_outlined),
                ),
                items: const {
                  1: '24 horas',
                  3: '3 dias',
                  7: '7 dias',
                  14: '14 dias',
                }.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (value) => setState(() => _validDays = value ?? 7),
              ),
              const SizedBox(height: 16),
              _QuoteTotal(totalCents: _totalCents),
              if (_error case final error?) ...[
                const SizedBox(height: 10),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 12),
                ),
              ],
              const SizedBox(height: 18),
              AppButton(
                label: widget.isCounterOffer
                    ? 'Enviar contraproposta'
                    : 'Enviar orçamento',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  int get _totalCents => _lines.fold(0, (total, line) {
    final amount = _parseCents(line.amount.text) ?? 0;
    return line.kind == ServiceQuoteItemKind.discount
        ? total - amount
        : total + amount;
  });

  void _add() => setState(() {
    _lines.add(
      _QuoteLineEditor(
        kind: ServiceQuoteItemKind.addon,
        description: '',
        amountCents: 0,
      ),
    );
  });

  void _remove(int index) => setState(() {
    _lines.removeAt(index).dispose();
    _error = null;
  });

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final items = <ServiceQuoteItemDraft>[];
    for (final line in _lines) {
      final amount = _parseCents(line.amount.text);
      if (amount == null || amount < 1) {
        setState(() => _error = 'Informe valores maiores que zero.');
        return;
      }
      if (amount > 100000000) {
        setState(() => _error = 'Cada item deve ser de até R\$ 1.000.000,00.');
        return;
      }
      items.add(
        ServiceQuoteItemDraft(
          kind: line.kind,
          description: line.description.text.trim(),
          amountCents: amount,
        ),
      );
    }
    final draft = ServiceQuoteDraft(
      items: List.unmodifiable(items),
      message: _message.text.trim(),
      expiresAt: DateTime.now().toUtc().add(Duration(days: _validDays)),
    );
    if (draft.totalCents < 1) {
      setState(
        () => _error = 'Os descontos não podem superar o valor da proposta.',
      );
      return;
    }
    if (draft.totalCents > 100000000) {
      setState(() => _error = 'O total deve ser de até R\$ 1.000.000,00.');
      return;
    }
    Navigator.pop(context, draft);
  }
}

class _QuoteLineEditor {
  _QuoteLineEditor({
    required this.kind,
    required String description,
    required int amountCents,
  }) : description = TextEditingController(text: description),
       amount = TextEditingController(
         text: amountCents > 0 ? _editableMoney(amountCents) : '',
       );

  ServiceQuoteItemKind kind;
  final TextEditingController description;
  final TextEditingController amount;

  void dispose() {
    description.dispose();
    amount.dispose();
  }
}

class _QuoteLineCard extends StatefulWidget {
  const _QuoteLineCard({
    required this.editor,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
    super.key,
  });

  final _QuoteLineEditor editor;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  State<_QuoteLineCard> createState() => _QuoteLineCardState();
}

class _QuoteLineCardState extends State<_QuoteLineCard> {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.outline),
    ),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<ServiceQuoteItemKind>(
                initialValue: widget.editor.kind,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: ServiceQuoteItemKind.values
                    .map(
                      (kind) => DropdownMenuItem(
                        value: kind,
                        child: Text(_kindLabel(kind)),
                      ),
                    )
                    .toList(growable: false),
                onChanged: (kind) {
                  if (kind == null) return;
                  setState(() => widget.editor.kind = kind);
                  widget.onChanged();
                },
              ),
            ),
            if (widget.canRemove)
              IconButton(
                tooltip: 'Remover item',
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
          ],
        ),
        const SizedBox(height: 10),
        TextFormField(
          controller: widget.editor.description,
          maxLength: 120,
          decoration: const InputDecoration(
            labelText: 'Descrição',
            hintText: 'Ex.: troca da resistência',
          ),
          validator: (value) => (value?.trim().length ?? 0) < 2
              ? 'Descreva este item.'
              : null,
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.editor.amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Valor',
            prefixText: 'R\$ ',
          ),
          onChanged: (_) => widget.onChanged(),
          validator: (value) => (_parseCents(value ?? '') ?? 0) < 1
              ? 'Informe um valor válido.'
              : null,
        ),
      ],
    ),
  );
}

class _QuoteTotal extends StatelessWidget {
  const _QuoteTotal({required this.totalCents});
  final int totalCents;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Total da proposta',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          _money(totalCents),
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    ),
  );
}

String _kindLabel(ServiceQuoteItemKind kind) => switch (kind) {
  ServiceQuoteItemKind.labor => 'Mão de obra',
  ServiceQuoteItemKind.material => 'Material',
  ServiceQuoteItemKind.addon => 'Adicional',
  ServiceQuoteItemKind.discount => 'Desconto',
};

int? _parseCents(String raw) {
  var value = raw.replaceAll('R\$', '').replaceAll(' ', '').trim();
  if (value.isEmpty) return null;
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  final amount = double.tryParse(value);
  if (amount == null || !amount.isFinite) return null;
  return (amount * 100).round();
}

String _editableMoney(int cents) => (cents / 100).toStringAsFixed(2).replaceAll('.', ',');

String _money(int cents) {
  final value = (cents.abs() / 100).toStringAsFixed(2).replaceAll('.', ',');
  return '${cents < 0 ? '-' : ''}R\$ $value';
}
