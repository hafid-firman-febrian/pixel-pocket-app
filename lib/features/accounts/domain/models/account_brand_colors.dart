const String _bca = '#386694';
const String _dana = '#4791C2';
const String _gopay = '#46A6B9';
const String _jago = '#D8A246';
const String _cash = '#46915F';

const List<String> accountBrandPalette = [_bca, _dana, _gopay, _jago, _cash];

const Map<String, String> _brandColorsByWord = {
  'bca': _bca,
  'dana': _dana,
  'gopay': _gopay,
  'jago': _jago,
  'cash': _cash,
  'tunai': _cash,
};

String? brandColorFor(String name) {
  for (final word in name.toLowerCase().split(RegExp(r'[^a-z0-9]+'))) {
    final color = _brandColorsByWord[word];
    if (color != null) return color;
  }
  return null;
}
