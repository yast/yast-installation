/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is the Mozilla Firefox browser.
 *
 * The Initial Developer of the Original Code is
 * Benjamin Smedberg <benjamin@smedbergs.us>
 *
 * Portions created by the Initial Developer are Copyright (C) 2004
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 * Wolfgang Rosenauer <stark@suse.de>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

const nsISupports              = Components.interfaces.nsISupports;

const nsICategoryManager       = Components.interfaces.nsICategoryManager;
const nsIComponentRegistrar    = Components.interfaces.nsIComponentRegistrar;
const nsICommandLine           = Components.interfaces.nsICommandLine;
const nsICommandLineHandler    = Components.interfaces.nsICommandLineHandler;
const nsIFactory               = Components.interfaces.nsIFactory;
const nsIModule                = Components.interfaces.nsIModule;
const nsIPrefBranch            = Components.interfaces.nsIPrefBranch;
const nsISupportsString        = Components.interfaces.nsISupportsString;
const nsIWindowWatcher         = Components.interfaces.nsIWindowWatcher;
const nsIBrowserDOMWindow      = Components.interfaces.nsIBrowserDOMWindow;
const nsIDOMWindow             = Components.interfaces.nsIDOMWindow;
const nsIDOMChromeWindow       = Components.interfaces.nsIDOMChromeWindow;


/**
 * This file provides a generic default command-line handler.
 *
 * It opens the chrome window specified by the pref "toolkit.defaultChromeURI"
 * the arguments passed to the window are the nsICommandLine instance.
 *
 * It doesn't do anything if the pref is unset.
 */

var nsCmdlineHandler = {
  /* nsISupports */

  QueryInterface : function clh_QI(iid) {
    if (iid.equals(nsICommandLineHandler) ||
        iid.equals(nsIFactory) ||
        iid.equals(nsISupports))
      return this;

    throw Components.results.NS_ERROR_NO_INTERFACE;
  },

  /* nsICommandLineHandler */

  handle : function clh_handle(cmdLine) {
    var win;
    var args;
    try {
      var uristr = cmdLine.handleFlagWithParam("url", false);
      if (!uristr) {
        dump("no -url parameter specified\n");
        return;
      } else {
        var uri = cmdLine.resolveURI(uristr);
        args = Components.classes["@mozilla.org/supports-string;1"]
                         .createInstance(nsISupportsString);
        args.data = uri.spec;
      }
    } 
    catch (e) { }
    
    var prefs = Components.classes["@mozilla.org/preferences-service;1"]
                          .getService(nsIPrefBranch);

    try {
      var chromeURI = prefs.getCharPref("toolkit.defaultChromeURI");

      var wwatch = Components.classes["@mozilla.org/embedcomp/window-watcher;1"]
                             .getService(nsIWindowWatcher);
      win = wwatch.openWindow(null, chromeURI, "_blank",
                        "chrome,dialog=no,all", args);
    }
    catch (e) { }

  },

  helpInfo : "  -url URI      Define the URL to be opened at startup.\n",

  /* nsIFactory */

  createInstance : function mdh_CI(outer, iid) {
    if (outer != null)
      throw Components.results.NS_ERROR_NO_AGGREGATION;

    return this.QueryInterface(iid);
  },

  lockFactory : function mdh_lock(lock) {
    /* no-op */
  }
};

const clh_contractID = "@novell.com/yast/browser-clh;1";
const clh_CID = Components.ID("{fafad6ea-860c-4879-8280-eb51b6a85d6b}");

var Module = {
  /* nsISupports */

  QueryInterface : function mod_QI(iid) {
    if (iid.equals(nsIModule) ||
        iid.equals(nsISupports))
      return this;

    throw Components.results.NS_ERROR_NO_INTERFACE;
  },

  /* nsIModule */

  getClassObject : function mod_gch(compMgr, cid, iid) {
    if (cid.equals(clh_CID))
      return nsCmdlineHandler.QueryInterface(iid);

    throw components.results.NS_ERROR_FAILURE;
  },

  registerSelf : function mod_regself(compMgr, fileSpec, location, type) {
    var compReg = compMgr.QueryInterface(nsIComponentRegistrar);

    compReg.registerFactoryLocation(clh_CID,
                                    "nsCmdlineHandler",
                                    clh_contractID,
                                    fileSpec,
                                    location,
                                    type);

    var catMan = Components.classes["@mozilla.org/categorymanager;1"]
                           .getService(nsICategoryManager);

    catMan.addCategoryEntry("command-line-handler",
                            "y-default",
                            clh_contractID, true, true);
  },

  unregisterSelf : function mod_unreg(compMgr, location, type) {
    var compReg = compMgr.QueryInterface(nsIComponentRegistrar);
    compReg.unregisterFactoryLocation(clh_CID, location);

    var catMan = Components.classes["@mozilla.org/categorymanager;1"]
                           .getService(nsICategoryManager);

    catMan.deleteCategoryEntry("command-line-handler",
                               "y-default");
  },

  canUnload : function (compMgr) {
    return true;
  }
};

function NSGetModule(compMgr, fileSpec) {
  return Module;
}
