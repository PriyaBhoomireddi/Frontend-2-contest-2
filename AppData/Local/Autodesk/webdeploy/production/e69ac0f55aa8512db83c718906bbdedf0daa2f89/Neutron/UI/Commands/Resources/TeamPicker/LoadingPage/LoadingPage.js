
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
    try {	
        var retStr = window.neutronJavaScriptObject.executeQuery('getLocalizeStringsForLoadingPage', "{}");	
        obj = JSON.parse(retStr);	
    }	
    catch(e) {	
        console.warn("Can't parse response for getLocalizeStringsForLoadingPage: '" + retStr + "'");	
        obj = {	
            'table' : {},	
            'lang' : 'ERR'	
        };	
    }	
    this._currentLocale = obj['lang'];	
    this._stringsTable = obj['table'];	
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

new Localization();	

_LCLZ = function(id, key) {	
    var val = Localization._instance.localize(key);	
    if (!val) {	
        return;	
    }	
    document.querySelector(id).innerHTML = val;	
};	

function updateLocalizationString() {	
    _LCLZ("#id_loading_title", "TeamPicker_LoadingTitle");	
}	

updateLocalizationString();
