import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PinInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int length;
  final bool error;
  final bool disabled;
  final ColorScheme colors;

  const PinInputWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.length,
    this.error = false,
    this.disabled = false,
    required this.colors,
  });

  @override
  State<PinInputWidget> createState() => _PinInputWidgetState();
}

class _PinInputWidgetState extends State<PinInputWidget> {
  int _currentLength = 0;

  @override
  void initState() {
    super.initState();
    _currentLength = widget.controller.text.length;
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(PinInputWidget old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
      _currentLength = widget.controller.text.length;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() => _currentLength = widget.controller.text.length);
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;

    return GestureDetector(
      onTap: () {
        if (!widget.disabled) widget.focusNode.requestFocus();
      },
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: colors.onSurface.withAlpha(8),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.error
                ? colors.error.withAlpha(50)
                : widget.disabled
                    ? colors.onSurface.withAlpha(10)
                    : widget.focusNode.hasFocus
                        ? colors.primary.withAlpha(80)
                        : colors.onSurface.withAlpha(15),
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (i) {
                final filled = i < _currentLength;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (widget.error ? colors.error : colors.primary)
                        : colors.onSurface.withAlpha(25),
                    border: filled
                        ? null
                        : Border.all(color: colors.onSurface.withAlpha(40)),
                  ),
                );
              }),
            ),
            Positioned.fill(
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                autofocus: true,
                readOnly: widget.disabled,
                keyboardType: TextInputType.number,
                maxLength: 4,
                maxLengthEnforcement: MaxLengthEnforcement.enforced,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(
                  color: Colors.transparent,
                  fontSize: 1,
                  height: 0,
                ),
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
                enableInteractiveSelection: false,
                enableSuggestions: false,
                autocorrect: false,
                buildCounter: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
