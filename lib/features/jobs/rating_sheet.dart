import 'package:flutter/material.dart';

Future<int?> showRatingSheet(BuildContext context, {required String title}) {
  return showModalBottomSheet<int>(
    context: context,
    showDragHandle: true,
    builder: (_) => _RatingSheet(title: title),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.title});
  final String title;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  int _stars = 5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  onPressed: () => setState(() => _stars = i),
                  icon: Icon(
                    i <= _stars ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.pop(context, _stars),
            child: const Text('إرسال التقييم'),
          ),
        ],
      ),
    );
  }
}
