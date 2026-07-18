String formatPkr(num value) {
  final rounded = value.round().toString();
  final formatted = rounded.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (match) => '${match[1]},',
  );
  return 'PKR $formatted';
}
