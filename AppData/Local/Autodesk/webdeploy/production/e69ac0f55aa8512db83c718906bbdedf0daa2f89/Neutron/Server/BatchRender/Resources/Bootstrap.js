/**
* Copyright 2017 Autodesk, Inc.
* All rights reserved.
*
* This computer source code and related instructions and comments are the unpublished confidential
* and proprietary information of Autodesk, Inc. and are protected under Federal copyright and state
* trade secret law. They may not be disclosed to, copied or used by any third party without the
* prior written consent of Autodesk, Inc.
*
*/

// This is for defining common resources shared between render settings, viewer and gallery components.


// Main data query, gets as much information as possible from fusion to avoid multiple queries.
// Context will be a json with separate sections for the separate vx api inputs
var myContext = JSON.parse(window.neutronJavaScriptObject.executeQuery('RaasRequest', JSON.stringify({ getContext: null })));

// Utility to load vx360.webcomponents from either a web server or a local storage.
(function (window, document, offline) {
    'use strict';

    // Configurations
    var loaderConfig = (myContext.settingsProvider.environment !== 'production')
        ? 'https://d1rpnxi7v571vn.cloudfront.net/fusion/BootstrapConfig.js'
        : 'https://dnie9zy2a5op.cloudfront.net/fusion/BootstrapConfig.js';
    var loader = {
        cdn: {
            scripts: [],
            css: []
        },
        local: {
            scripts: [
                'vx360.webcomponents/scripts/vx360.webcomponents.lib.js',
                'vx360.webcomponents/scripts/vx360.webcomponents.js'
            ],
            css: [
                'vx360.webcomponents/css/vx360.webcomponents.lib.css',
                'vx360.webcomponents/css/vx360.webcomponents.css'
            ]
        },
        settings: {
        },
        data: {
            timeout: 10000,
            state: 0,
            scriptIndex: 0,
            cssIndex: 0,
            localScriptIndex: 0,
            localCssIndex: 0,
            isError: false,
            isTimeout: false,
            isFinish: false
        },
        sandbox: undefined
    };

    // Uncomment this line to force offline mode. Otherwise, vx360 will
    // respect Fusion's working mode.
    //offline = true;

    // Helper function to generate <script src='...'></script> html.
    var scriptHtml = function(url) {
        return '<script src="' + url + '"></script>';
    };

    // Helper function to generate <link ref='stylesheet' href='...'/> html.
    var cssHtml = function(url) {
        return '<link rel="stylesheet" href="' + url + '"/>';
    };

    // Helper function to determine if an angular module exists.
    var angularModuleExists = function(name) {
        try {
            window.angular.module(name);
            return true;
        } catch(err) {
            return false;
        }
    };

    // Helper function to reference an external stylesheet.
    var referenceCss = function(doc, url, loadCb, errorCb) {
        var link = doc.createElement('link');
        link.rel = 'stylesheet';
        link.href = url;
        if (loadCb) {
            link.onload = function() {
                loadCb();
            };
        }
        if (errorCb) {
            link.onerror = function(data) {
                errorCb(data);
            };
        }
        doc.getElementsByTagName('head')[0].appendChild(link);
    };

    // Helper function to reference an external script.
    var referenceScript = function(doc, url, loadCb, errorCb) {
        var script = doc.createElement('script');
        script.src = url;
        if (loadCb) {
            script.onload = function() {
                loadCb();
            };
        }
        if (errorCb) {
            script.onerror = function(data) {
                errorCb(data);
            };
        }
        doc.body.appendChild(script);
    };

    // Helper function to reference an array of external stylesheets.
    var referenceCssArray = function(doc, urls, tickCb, loadCb, errorCb) {
        var loadCount = 0;
        urls.forEach(function(url) {
            referenceCss(doc, url, function() {
                loadCount++;
                if (tickCb) {
                    tickCb(loadCount);
                }
                if (loadCount === urls.length) {
                    if (loadCb) {
                        loadCb();
                    }
                }
            }, function(data) {
                if (errorCb) {
                    errorCb(data);
                }
            });
        });
    };

    // Helper function to reference an array of external scripts.
    var referenceScriptArray = function(doc, urls, index, tickCb, loadCb, errorCb) {
        referenceScript(doc, urls[index], function() {
            if (tickCb) {
                tickCb(index+1);
            }
            if (index+1 < urls.length) {
                referenceScriptArray(doc, urls, index+1, tickCb, loadCb, errorCb);
            } else {
                if (loadCb) {
                    loadCb();
                }
            }
        }, function(data) {
            if (errorCb) {
                errorCb(data);
            }
        });
    };

    // Polyfill: https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent/CustomEvent
    if (typeof window.CustomEvent !== 'function') {
        var CustomEvent = function(event, params) {
            params = params || {bubbles: false, cancelable: false, detail: undefined};
            var evt = document.createEvent('CustomEvent');
            evt.initCustomEvent(event, params.bubbles, params.cancelable, params.detail);
            return evt;
        };
        CustomEvent.prototype = window.Event.prototype;
        window.CustomEvent = CustomEvent;
    }

    // Bootstrap. Load the config file from CDN.
    loader.bootstrap = function() {
        // If Fusion is in offline mode, don't load any scripts or stylesheets
        // from CDN. fallback() will load the local version.
        if (offline) {
            this.fallback();
            return; // Use local data!
        }

        // Init a sandbox iframe element to hold async loading scripts.
        this.sandbox = document.createElement('iframe');
        this.sandbox.style.width = 0;
        this.sandbox.style.height = 0;
        this.sandbox.style.border = 0;
        this.sandbox.style.visibility = 'hidden';
		//move sandbox out of viewport
		this.sandbox.style.position = 'absolute';
		this.sandbox.style.left = '-9999px';
		this.sandbox.style.top = '-9999px';
        document.body.appendChild(this.sandbox);

        // Shortcuts
        var sandbox = this.sandbox;
        var sandboxWin = this.sandbox.contentWindow;
        var sandboxDoc = this.sandbox.contentWindow.document;

        // Init sandbox document
        sandboxDoc.open();
        sandboxDoc.write('<html><head></head><body></body></html>');
        sandboxDoc.close();

        // State -> loading BootstrapConfig.js
        this.data.state = 1;

        // Add BootstrapConfig.js to the sandbox.
        referenceScript(sandboxDoc, loaderConfig, function() {
            // Merge the configs from CDN ...
            if (sandboxWin.vx360webcomponentsBootstrapConfig) {
                loader.cdn = sandboxWin.vx360webcomponentsBootstrapConfig.cdn;
                loader.settings = sandboxWin.vx360webcomponentsBootstrapConfig.settings;
            }
            loader.checkOk();
        }, function() {
            loader.checkError();
        });

        // Add Timeout fallback
        setTimeout(function() {
            loader.checkTimeout();
        }, this.data.timeout);
    };

    // Load the vx360.webcomponents scripts and stylesheets from CDN.
    loader.loadFromCDN = function() {
        // Shortcuts
        var sandbox = this.sandbox;
        var sandboxDoc = this.sandbox.contentWindow.document;

        // Ideally, we should load scripts in parallel. But older Chrome does
        // not support preload. Using object element will introduce a huge
        // latency in loading resources..

        // State -> loading vx360 from CDN into sandbox
        this.data.state = 2;

        // No scripts or stylesheets in the BootstrapConfig.js?
        if (this.cdn.scripts.length === 0 &&
                this.cdn.css.length === 0) {
            this.checkError();
            return;
        }

        // Add the scripts to sandbox one by one.
        if (this.cdn.scripts.length > 0) {
            referenceScriptArray(sandboxDoc, this.cdn.scripts, 0, function(tick) {
                loader.data.scriptIndex = tick;
            }, function() {
                loader.checkOk();
            }, function() {
                loader.checkError();
            });
        }

        // Add the stylesheets to sandbox in parallel.
        if (this.cdn.css.length > 0) {
            referenceCssArray(sandboxDoc, this.cdn.css, function(tick) {
                loader.data.cssIndex = tick;
            }, function() {
                loader.checkOk();
            }, function() {
                loader.checkError();
            });
        }
    };

    // Promote scripts and stylesheets from sandbox to the document.
    loader.promoteFromSandbox = function() {
        // Advance the state only when both scripts and stylesheets are loaded
        // in the sandbox. Otherwise, wait for the next load event.
        var scriptOk = this.data.scriptIndex === this.cdn.scripts.length;
        var cssOk = this.data.cssIndex === this.cdn.css.length;
        if (!scriptOk || !cssOk) {
            return; // Loading in progress..
        }

        // vx360 has been fully loaded in the sandbox. We are going to commit
        // the changes to the main document. It's not possible to fallback
        // past now.
        this.data.scriptIndex = 0;
        this.data.cssIndex = 0;
        this.data.isFinish = true;

        // State -> promoting vx360 to document
        this.data.state = 3;

        // Load vx360 in the main document. We should hit cache this time.
        if (this.cdn.scripts.length > 0) {
            referenceScriptArray(document, this.cdn.scripts, 0, function(tick) {
                loader.data.scriptIndex = tick;
            }, function() {
                loader.checkOk();
            });
        }
        if (this.cdn.css.length > 0) {
            referenceCssArray(document, this.cdn.css, function(tick) {
                loader.data.cssIndex = tick;
            });
        }
    };

    // Load client scripts (e.g. Common.js) and bootstrap angular.
    loader.loadClientScript = function() {
        // Continue once the scripts are loaded.
        if (this.data.scriptIndex !== this.cdn.scripts.length) {
            return; // Loading in progress..
        }

        // State -> loading client scripts
        this.data.state = 4;

        // Load Common.js and bootstrap angular.
        referenceScript(document, 'Common.js', function() {
            loader.angularInit();
            loader.checkOk();
        });
    };

    // Load local resources as a fallback.
    loader.loadLocalResources = function() {
        // Error or Timeout happened. This method is called once when the error or
        // timeout event happens. Further state changes from regular load callbacks
        // should be ignored.
        this.data.isFinish = true;

        // State -> loading local resources
        this.data.state = 12;

        // Load vx360 in the main document using the local resources.
        referenceScriptArray(document, this.local.scripts, 0, function(tick) {
            loader.data.localScriptIndex = tick;
        }, function() {
            if (loader.data.localScriptIndex === loader.local.scripts.length) {
                // Load Common.js in the main document.
                referenceScript(document, 'Common.js', function() {
                    loader.angularInit();
                });
            }
        });
        referenceCssArray(document, this.local.css, function(tick) {
            loader.data.localCssIndex = tick;
        });
    };

    // State Machine. There are multiple stages to load vx360.
    loader.check = function() {
        switch (this.data.state) {

        case 1: // loading BootstrapConfig.js
            this.loadFromCDN(); // loading vx360 from CDN into sandbox
            break;

        case 2: // loading vx360 from CDN into sandbox
            this.promoteFromSandbox(); // promoting vx360 to document
            break;

        case 3: // promoting vx360 to document
            this.loadClientScript(); // loading client scripts
            break;

        case 4: // loading client scripts
            this.data.state = 9;
            break;

        case 9: // Done !!
            break;

        case 11: // Fallback !!
            this.loadLocalResources(); // loading local resources
            break;

        case 12: // loading local resources
            this.data.state = 19;
            break;

        case 19: // Done (local) !!
            break;
        }
    };

    // Mark the state as Ok.
    loader.checkOk = function() {
        if (!this.data.isError && !this.data.isTimeout) {
            this.check();
        }
    };

    // Mark the state as Error.
    loader.checkError = function() {
        if (!this.data.isError && !this.data.isTimeout) {
            this.data.isError = true;
            this.data.state = 11;
            this.check();
        }
    };

    // Mark the state as Timeout.
    loader.checkTimeout = function() {
        if (!this.data.isError && !this.data.isTimeout && !this.data.isFinish) {
            this.data.isTimeout = true;
            this.data.state = 11;
            this.check();
        }
    };

    // Manual angularjs initialization.
    loader.angularInit = function() {
        document.dispatchEvent(new window.CustomEvent('myInit', {
            detail: {
                message: 'Initialize before angular.bootstrap'
            }
        }));
        window.angular.bootstrap(document, [document.body.getAttribute('my-ng-app')]);
    };

    // Load the local version of vx360.webcomponents if CDN is not available.
    // We always have a complete local version of vx360.webcomponents and
    // Chrome should not block the scripts from loading because they are not
    // cross-site scripts.
    loader.fallback = function() {
        // Load the stylesheets from local storage ...
        this.local.css.forEach(function(url) {
            referenceCss(document, url);
        });
        // Load the scripts from local storage ...
        this.local.scripts.forEach(function(url) {
            document.write(scriptHtml(url));
        });
        // Load Common.js ...
        document.write(scriptHtml('Common.js'));
        // Init angularjs ...
        document.write(
            '<script language="JavaScript" type="application/javascript">' +
                'myLoader.angularInit();' +
            '</script>');
    };

    // Export the loader to global/window namespace.
    window.myLoader = loader;

    // Load NOW !!
    loader.bootstrap();

} (window, document, myContext.connectionStatus !== 'Online'));
