(function () {
  if (typeof window.useTranslations !== 'function') {
    window.useTranslations = function () {
      return function (key, values) {
        var text = String(key);
        var name;
        if (values && typeof values === 'object') {
          for (name in values) {
            if (Object.prototype.hasOwnProperty.call(values, name)) {
              text = text.replace(new RegExp('\\{' + name + '\\}', 'g'), String(values[name]));
            }
          }
        }
        return text;
      };
    };
  }

  var officeShim = {
    context: { mailbox: { diagnostics: { hostName: 'DavidTeam' } } },
    onReady: function (callback) {
      if (typeof callback === 'function') {
        callback();
      }
    }
  };

  try {
    Object.defineProperty(window, 'Office', {
      value: officeShim,
      writable: false,
      configurable: false
    });
  } catch (e) {
    window.Office = officeShim;
  }
})();
