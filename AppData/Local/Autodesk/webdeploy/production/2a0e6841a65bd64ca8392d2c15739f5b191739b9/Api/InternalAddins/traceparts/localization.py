
import os, json

_stringTable: dict = None

def _LCLZ(key: str, default: str) -> str:
    global _stringTable
    if not _stringTable:
        _stringTable = _loadStringTable() or {}
    return _stringTable \
        and (key in _stringTable) \
        and ('translation' in _stringTable[key]) \
        and _stringTable[key]['translation'] \
        or default

_locales = [
    'de-DE',
    'en-US',
    'fr-FR',
    'it-IT',
    'ja-JP',
    'zh-CN'
]

def _getLocaleNameMap():
    from adsk.core import UserLanguages # pylint: disable=import-error
    return {
        UserLanguages.GermanLanguage: 'de-DE',
        UserLanguages.EnglishLanguage: 'en-US',
        UserLanguages.FrenchLanguage: 'fr-FR',
        UserLanguages.ItalianLanguage: 'it-IT',
        UserLanguages.JapaneseLanguage: 'ja-JP',
        UserLanguages.ChinesePRCLanguage: 'zh-CN',
        UserLanguages.ChineseTaiwanLanguage: 'zh-CN'
        #UserLanguages.CzechLanguage
        #UserLanguages.HungarianLanguage
        #UserLanguages.KoreanLanguage
        #UserLanguages.PolishLanguage
        #UserLanguages.PortugueseBrazilianLanguage
        #UserLanguages.RussianLanguage
        #UserLanguages.SpanishLanguage
    }

def getCurrentLanguage() -> int:
    from .utils import app # pylint: disable=relative-beyond-top-level
    return app.preferences.generalPreferences.userLanguage

def _loadStringTable():
    from .utils import handleError # pylint: disable=relative-beyond-top-level
    localeNameMap = _getLocaleNameMap()
    try:
        tables = {}
        with open(os.path.join(os.path.dirname(__file__), 'localization.json'), encoding='utf-8') as file:
            tables = json.load(file)
        return tables[localeNameMap[getCurrentLanguage()]]
    except:
        handleError('loadStringTable')
    return None

def _exportStrings():
    import re
    folder = os.getcwd()

    table = {}
    pattern = re.compile(r'''_LCLZ\((?P<quote1>['"])(?P<key>.*)(?P=quote1)[ \t]*,[ \t]*(?P<quote2>['"])(?P<default>.*)(?P=quote2)\)''')
    for filename in os.listdir(folder):
        _, extension = os.path.splitext(filename)
        if extension != '.py':
            continue
        with open(os.path.join(os.getcwd(), filename), 'r') as file:
            for line in file:
                for match in pattern.finditer(line):
                    table[match.group('key')] = {
                        'devLabel': match.group('default'),
                        'translation': ''
                    }

    tables = {}
    for locale in _locales:
        tables[locale] = table
    with open(os.path.join(folder, 'localization.json'), 'w') as out:
        json.dump(tables, out, indent=4)

if __name__ == "__main__":
    _exportStrings()
