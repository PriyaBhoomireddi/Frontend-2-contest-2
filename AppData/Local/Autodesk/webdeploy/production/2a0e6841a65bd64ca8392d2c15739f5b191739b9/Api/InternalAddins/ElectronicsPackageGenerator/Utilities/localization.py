import os
import json
import adsk.core

class Localization:
    def __init__(self, locale):
        global locale_messages
        self.locale = locale
        
        with open(os.path.dirname(__file__) + '/../Localization/' + self.locale + '.json', encoding="utf8") as locale_json:
            locale_messages = json.load(locale_json)

    @staticmethod
    def get_locale_string(key, default_value):
        try:
            return locale_messages[key]
        except KeyError:
            return default_value

class UserPrefernce:
    def __init__(self):
        #https://help.autodesk.com/view/fusion360/ENU/?guid=GUID-b8af2def-f673-4cd4-baec-3c9912059547
        self.supported_languages = {0: "zh", 3: "en", 4: "fr", 5: "de", 7: "it",  8: "ja"}
        self.app = adsk.core.Application.get()
        self.language_code = self.app.preferences.generalPreferences.userLanguage

    # get user language prefernece from fusion and set locale for addin
    def get_user_language(self):
        try:
            return self.supported_languages[self.language_code]
        except KeyError:
            return "en"

userPrefernce = UserPrefernce()
locale = userPrefernce.get_user_language()

localization = Localization(locale)

_LCLZ = localization.get_locale_string

