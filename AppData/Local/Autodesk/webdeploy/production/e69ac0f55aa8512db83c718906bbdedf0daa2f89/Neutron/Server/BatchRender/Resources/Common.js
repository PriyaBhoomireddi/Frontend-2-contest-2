/**
* Copyright 2015 Autodesk, Inc.
* All rights reserved.
*
* This computer source code and related instructions and comments are the unpublished confidential
* and proprietary information of Autodesk, Inc. and are protected under Federal copyright and state
* trade secret law. They may not be disclosed to, copied or used by any third party without the
* prior written consent of Autodesk, Inc.
*
*/

// This is for defining common resources shared between render settings, viewer and gallery components.


(function(i,s,o,g,r,a,m){i['GoogleAnalyticsObject']=r;i[r]=i[r]||function(){
(i[r].q=i[r].q||[]).push(arguments)},i[r].l=1*new Date();a=s.createElement(o),
m=s.getElementsByTagName(o)[0];a.async=1;a.src=g;m.parentNode.insertBefore(a,m)
})(window,document,'script','https://www.google-analytics.com/analytics.js','ga');
if (myContext.settingsProvider.environment == 'production' || myContext.settingsProvider.environment == 'preprod'){
    ga('create', 'UA-33607141-4', 'auto');
} else {
	ga('create', 'UA-33607141-3', 'auto');
}
ga('set', 'checkProtocolTask', null); // Disable file protocol checking.
ga('set', 'checkStorageTask', null); // Disable cookie storage checking.
ga('set', 'historyImportTask', null); // Disable history checking (requires reading from cookies).

//disable right-click contextual menu when in production
$(document).on("contextmenu", function (e) {
    return myContext.settingsProvider.environment != 'production';
});

// Create the ng-app (https://docs.angularjs.org/api/ng/directive/ngApp). We do manual initialization
// https://docs.angularjs.org/guide/bootstrap. my-ng-app will be the parameter in angular.bootstrap.
var myAppName = document.getElementsByTagName('body')[0].getAttribute('my-ng-app');
var myApp = angular.module(myAppName, ['vx360.webcomponents']);

// Helper function that sends input url to fusion to show in a standard browser, used by myApp.config;settingsProvider
function myLinkHandler(url) {
    window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ doOpenUrl: url }));
}

// Local variables to store authtoken and the time when the token was last refreshed
var token = '';
var lastUpdate = 0;

// Helper function that returns an authtoken, used by myApp.config;settingsProvider
// The function will cache a token for a second to avoid too frequent token requests, but it needs to be refreshed regularly to avoid timing out.
function myAuthToken() {
    // Token is cached for 1 second to avoid unnessessary queries
    if (Date.now() > (lastUpdate + 1000)) {
        token = window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ getAuthToken: null }));
        lastUpdate = Date.now();
    }
    return token;
}

// Convert to standard locale code, e.g. 'en' -> 'en-us'
function getLocaleCode(loc) {
    var t = "en-us";
    switch (loc.toLowerCase()) {
        case "cs": case "cs-cz": t = "cs-cz"; break;
        case "de": case "de-de": t = "de-de"; break;
        case "es": case "es-es": t = "es-es"; break;
        case "fr": case "fr-fr": t = "fr-fr"; break;
        case "hu": case "hu-hu": t = "hu-hu"; break;
        case "it": case "it-it": t = "it-it"; break;
        case "ja": case "ja-jp": t = "ja-jp"; break;
        case "ko": case "ko-kr": t = "ko-kr"; break;
        case "pl": case "pl-pl": t = "pl-pl"; break;
        case "pt": case "pt-br": t = "pt-br"; break;
        case "ru": case "ru-ru": t = "ru-ru"; break;
        case "zh-hans": case "zh-cn": t = "zh-cn"; break;
        case "zh-hant": case "zh-tw": t = "zh-tw"; break;
    }
    return t;
}

// Define angular config module defined at https://git.autodesk.com/raas/vx360-web-components/blob/develop/docs/VX360WebModule.md#configuration, for angular reference, see https://docs.angularjs.org/guide/module on Configuration blocks.
myApp.config(['raasSettingsProvider', function (settingsProvider) {

    if (myContext.settingsProvider.locale) {
        // v2.x.x use standard locale code. e.g. 'en-us'
        myContext.settingsProvider.locale = getLocaleCode(myContext.settingsProvider.locale);
    }

    if (window.myLoader && window.myLoader.settings) {
        settingsProvider.set(window.myLoader.settings);
    }

    settingsProvider.set(myContext.settingsProvider);
    settingsProvider.set({
        linkHandler: myLinkHandler,
        authToken: myAuthToken,
        overrideSharing: true,
        supportedJobTypes: ['image', 'turntable', 'motionstudy'],
        theme: 'fusion-theme',
        enableGoogleAnalytics: true
    });
}]);


// Define job provider, see https://git.autodesk.com/raas/vx360-web-components/blob/develop/docs/JobService.md#setjobproviderjobprovider
var myJobProvider = {
    isKnownJob: function (jobId) {
        return window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ getJobExists: jobId })) === 'True';
    },
    jobInfo: function (jobId) {
        var info = window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ getJobInfo: jobId }));
        if (info.length > 0) return JSON.parse(info);
        return null;
    },
    stopJob: function (jobId) {
        window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ doStopJob: jobId }));
        return true;
    },
    saveImage: function (jobId) {
        var image = window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ saveImage: jobId }));
        return JSON.parse(image).Image;
    },
    deleteJob: function (jobId) {
        window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ doDeleteJob: jobId }));
        return true;
    },
    listJobs: function (gallery) {
        if (gallery.design) {
            var list = window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ getJobList: gallery.design.designId }));
            if (list.length > 0) {
                var jobInfos = [];
                var jobs = JSON.parse(list);
                for (var i in jobs) {
                    var jobInfo = this.jobInfo(jobs[i]);
                    if (jobInfo)
                        jobInfos.push(jobInfo);
                }
                return jobInfos;
            }
        }
        return null;
    }
};

// Passing VX events over to c++.
function myVXEventHandler(event, args) {
    if (args.status == 'error')
        window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ sendError: args }));
    else
        window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ sendMessage: args }));
}

// Workaround for an unhandled exception in $scope.apply, unclear what it does and why the exception is triggered, for more info contact Asheem Mamoowala <asheem.mamoowala@autodesk.com>
function mySafeApply(scope, fn) {
    var phase = scope.$root.$$phase;
    if (phase == '$apply' || phase == '$digest') {
        if (fn && (typeof (fn) === 'function'))
            fn();
    }
    else
        scope.$apply(fn);
};

// Make sure the app is shutdown, so we can safeley close the browser
function myShutdown(scope) {
    scope.$root.$destroy();
};

// Send loaded to fusion to turn off the "load..." output in the dialog and avoid fusion shutting down the browser.
// Placed in $(function () to delay sendLoaded until a proper loaded event can be supported by the component
$(function () {
    window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ sendLoaded: null }));
});
