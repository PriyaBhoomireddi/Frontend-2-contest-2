
const safeExecuteQuery = (...args) => {
  if (window.neutronJavaScriptObject) {
    window.neutronJavaScriptObject.executeQuery(...args);
  } else {
    setTimeout(() => safeExecuteQuery(...args), 60); // try again after 60 milliseconds
  }
};

/** 
* Localization
* 
*/
Localization = function(){
    this._currentLocale = null;
    this._stringsTable = null;

    this._init();
};

Localization.prototype._init = function () {
    var obj = null;
    var self = this;
    
    safeExecuteQuery('getLocalizedStringsForOfflinePage', "", function (res) { 
        try {
            obj = JSON.parse(res);
        }
        catch(e) {
            console.warn("Can't parse response for getLocalizedStringsForOfflinePage: '" + retStr + "'");
            obj = {
                'table' : {},
                'lang' : 'ERR'
            };
        }
        self._currentLocale = obj['lang'];
        self._stringsTable = obj['table'];
        updateLocalizationString(self);
    }); 


    Localization._instance = this;
};

Localization.prototype.localize = function(key, hint){
    var ret = this._stringsTable[key];
    if (ret !== undefined)
        return ret;

    hint = hint || '(null)';
    console.warn('Localization: missing "' + this._currentLocale + '" translated value for key:"' + key + '", hint: "' + hint + '"');
    return null;
};


Localization.prototype._LCLZ = function(id, key) {
    var val = this.localize(key);
	if (val === undefined) {
		return;
	}
	document.querySelector(id).innerHTML = val;
};

function updateLocalizationString(self) {
	self._LCLZ("#id_SUStorage_title", "Hometab_SUS_Title");
	self._LCLZ("#id_SUStorage_subtitle", "Hometab_SUS_Subtitle");
	self._LCLZ("#id_SUStorage_message", "Hometab_SUS_Message");
	self._LCLZ("#id_Offline_title", "Hometab_Offline_Title");
	self._LCLZ("#id_Offline_subtitle", "Hometab_Offline_Subtitle");
	self._LCLZ("#id_Offline_message", "Hometab_Offline_Message");
	self._LCLZ("#id_NonMEHub_title", "Hometab_NonMEHub_Title");
	self._LCLZ("#id_NonMEHub_subtitle", "Hometab_NonMEHub_Subtitle");
	self._LCLZ("#id_NonMEHub_message", "Hometab_NonMEHub_Message");
}

new Localization();


