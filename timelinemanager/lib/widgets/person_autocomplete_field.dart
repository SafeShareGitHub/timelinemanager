import 'package:flutter/material.dart';

/// A [TextField] that suggests entries from [options] as the user types.
///
/// Unlike Flutter's [Autocomplete], this wraps [RawAutocomplete] so the
/// caller can keep ownership of the [TextEditingController] and read its
/// value at save time — the artifact dialogs rely on that.
class PersonAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final InputDecoration decoration;
  final List<String> options;

  const PersonAutocompleteField({
    super.key,
    required this.controller,
    required this.options,
    this.decoration = const InputDecoration(),
  });

  @override
  State<PersonAutocompleteField> createState() =>
      _PersonAutocompleteFieldState();
}

class _PersonAutocompleteFieldState extends State<PersonAutocompleteField> {
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: widget.controller,
      focusNode: _focus,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) return const Iterable<String>.empty();
        return widget.options.where((o) {
          final lo = o.toLowerCase();
          return lo.contains(q) && lo != q;
        });
      },
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: widget.decoration,
          onSubmitted: (_) => onFieldSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, maxWidth: 320),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, i) {
                  final option = options.elementAt(i);
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text(option)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
