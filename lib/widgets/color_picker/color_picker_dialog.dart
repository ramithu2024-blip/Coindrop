import 'package:flutter/material.dart';

const List<List<int>> _swatches = [
  [0xFF000000, 0xFF434343, 0xFF666666, 0xFF999999, 0xFFB7B7B7, 0xFFCCCCCC, 0xFFE0E0E0, 0xFFFFFFFF],
  [0xFF980000, 0xFFFF0000, 0xFFFF6600, 0xFFFF9900, 0xFFFFCC00, 0xFF99CC00, 0xFF339900, 0xFF006600],
  [0xFF330000, 0xFF660000, 0xFF993300, 0xFFB45F06, 0xFFBF9000, 0xFF6AA84F, 0xFF38761D, 0xFF134F5C],
  [0xFFCC4125, 0xFFE06666, 0xFFF6B26B, 0xFFFFD966, 0xFFFFF2CC, 0xFFD9EAD3, 0xFFB6D7A8, 0xFF93C47D],
  [0xFF652C1F, 0xFFA64D38, 0xFFD98C5C, 0xFFE6A96E, 0xFFF4C78F, 0xFFD5B08C, 0xFFB8957A, 0xFF9C7A66],
  [0xFF1C4587, 0xFF3C78D8, 0xFF6D9EEB, 0xFF8DB4E2, 0xFFA4C2F4, 0xFFC9DAF8, 0xFFD0E0F0, 0xFFD9D9D9],
  [0xFF073763, 0xFF0B5394, 0xFF2986CC, 0xFF4897D6, 0xFF6FA8DC, 0xFF8FB9E8, 0xFFA8C9F0, 0xFFC5DFF5],
  [0xFF20124D, 0xFF351C75, 0xFF674EA7, 0xFF8E7CC3, 0xFFA490D2, 0xFFB8A7D6, 0xFFCCC0DC, 0xFFDDD0EA],
  [0xFF4A113A, 0xFF741B47, 0xFFA64D79, 0xFFC27BA0, 0xFFD5A6BD, 0xFFE0B8CC, 0xFFEAC8D8, 0xFFF1D7E6],
];

/// Shows a bottom-sheet color picker with a 72-color palette grid.
/// Returns the selected [Color] or null if cancelled.
Future<Color?> showColorPicker(BuildContext context, {Color? initialColor}) async {
  final colors = Theme.of(context).colorScheme;
  Color picked = initialColor ?? Colors.teal;

  final result = await showModalBottomSheet<int>(
    context: context,
    backgroundColor: colors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 16, right: 16, top: 12,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 36, height: 4, decoration: BoxDecoration(
                    color: colors.onSurface.withAlpha(40),
                    borderRadius: BorderRadius.circular(2),
                  )),
                  const SizedBox(height: 16),
                  Text('Pick a Color', style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold, color: colors.onSurface,
                  )),
                  const SizedBox(height: 16),
                  Container(
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: picked,
                    ),
                    child: Center(
                      child: Text('Preview', style: TextStyle(
                        color: picked.computeLuminance() > 0.5 ? Colors.black87 : Colors.white,
                        fontWeight: FontWeight.w600,
                      )),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ..._swatches.map((row) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Row(
                        children: row.map((c) {
                          final color = Color(c);
                          final selected = picked.value == c;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => picked = color),
                              child: Container(
                                height: 34,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(6),
                                  border: selected
                                      ? Border.all(color: colors.onSurface, width: 2.5)
                                      : null,
                                ),
                                child: selected
                                    ? Icon(Icons.check, size: 16,
                                        color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                                    : null,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx, -1),
                          child: Text('Cancel', style: TextStyle(color: colors.onSurface.withAlpha(150))),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, picked.value),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Apply', style: TextStyle(color: colors.onPrimary)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  if (result != null && result > 0) return Color(result);
  return null;
}
