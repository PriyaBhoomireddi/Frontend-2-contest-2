
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
    safeExecuteQuery('getLocalizedStringsForLoadingPage', "", function (res) { 
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
        self._LCLZ("#id_loading_title", "HomePage_LoadingTitle");
    }); 

    Localization._instance = this;	
};	

Localization.prototype.localize = function(key, hint){	
    var ret = this._stringsTable[key];	
    if (ret)	
        return ret;	

    hint = hint || '(null)';	
    console.warn('Localization: missing "' + this._currentLocale + '" translated value for key:"' + key + '", hint: "' + hint + '"');	
    return null;	
};	

Localization.prototype._LCLZ = function(id, key) {
    var val = this.localize(key);
    if (!val) {	
        return;	
    }	
    document.querySelector(id).innerHTML = val;	
};	

new Localization();
