
/** 
* Event handling
* 
*/

function onClickRetry() {
    document.getElementById("id_button_retry").disabled = true;
    window.neutronJavaScriptObject.executeQuery('retryForErrorPage', "{}");
}

function onClickExit() {
    document.getElementById("id_button_retry").disabled = true;
    window.neutronJavaScriptObject.executeQuery('ExitForErrorPage', "{}");
}

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
        var retStr = window.neutronJavaScriptObject.executeQuery('getLocalizeStringsForErrorPage', "{}");
        obj = JSON.parse(retStr);
    }
    catch(e) {
        console.warn("Can't parse response for getLocalizeStringsForErrorPage: '" + retStr + "'");
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
    if (ret !== undefined)
        return ret;

    hint = hint || '(null)';
    console.warn('Localization: missing "' + this._currentLocale + '" translated value for key:"' + key + '", hint: "' + hint + '"');
    return null;
};

new Localization();

_LCLZ = function(id, key) {
    var val = Localization._instance.localize(key);
	if (val === undefined) {
		return;
	}
	document.querySelector(id).innerHTML = val;
};

function updateLocalizationString() {
	_LCLZ("#id_error_title", "TeamPicker_ErrorTitle");
	_LCLZ("#id_error_message", "TeamPicker_ErrorMessage");
	_LCLZ("#id_button_retry", "Retry");
	_LCLZ("#id_button_exit", "Exit");
	_LCLZ("#id_forum_help", "TeamPicker_ForumHelp");
}

updateLocalizationString();
