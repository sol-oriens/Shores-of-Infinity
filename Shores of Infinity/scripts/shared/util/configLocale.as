string configLocale(string localeKey) {
  int paramIndex = localeKey.findFirst("^");
	if(paramIndex > 0) {
    int valueIndex = localeKey.findFirst(":");
    if(valueIndex > 0) {
      string param = localeKey.substr(paramIndex + 1, (valueIndex - paramIndex - 1));
      string value = localeKey.substr(valueIndex + 1, localeKey.length() - (valueIndex + 1));
      int result = toInt(value) * config::get(param);
      localeKey = localeKey.substr(0, paramIndex) + ":" + result;
    }
  }

  return localeKey;
}
