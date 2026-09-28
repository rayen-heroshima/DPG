"""Seed the GlobalSettingsConstants that AMP's patch tree never inserts.

Default policy: 'false'. Every one of these is an optional feature toggle or
optional config, and AMP dereferences several of them with
getGlobalSettingValue(X).equalsIgnoreCase("true"), which NPEs on a missing row.
'false' both avoids the NPE and leaves optional features off, which is what a
minimal boot wants. The few that are parsed as numbers or read as real strings
get explicit values instead, because 'false' would throw there.
"""
import sys

NUMERIC = {
    "Activity Versions Queue Size": "10",
    "Activity version life time in days": "365",
    "Current Fiscal Year": "2026",
    "Daily Currency Rates Update Hour": "1",
    "Daily Currency Rates Update Timeout": "60",
    "Funding gap notification threshold": "0",
    "Max Inactive Session Interval": "60",
    "Maximum file size (MB)": "10",
    "Number of Years in Range": "5",
    "Number of indicators in M&E Dashboard": "5",
    "Year Range Start": "2000",
}

STRINGS = {
    "AMP Server Name": "AMP",
    "Default Country": "",
    "Default Date Format": "dd/MM/yyyy",
    "Default Decimal Separator": ".",
    "Default Grouping Separator": ",",
    "Default Exchange Rate Separator": ".",
    "Default Number Format": "###,###,###.##",
    "Fiscal Year End Date": "31/12",
    "Limit upload of file types": "",
    "Project Title Hierarchy": "",
    "Site Domain": "localhost",
    "AMP Dashboard URL": "",
    "AMP Dashboard Core Indicator URL": "",
    "AMP Dashboard Core Indicator Username": "",
    "AMP Dashboard Core Indicator Password": "",
    "AMP Registry URL": "",
    "Resource list sort column": "",
    "Components Sort Order": "",
    "system": "",
}

names = [l.rstrip("\n") for l in open(sys.argv[1], encoding="utf-8") if l.strip()]

out = ["-- Defaults for GlobalSettingsConstants entries no patch inserts.",
       "-- Guarded, so re-running never overwrites an existing value.\n"]
for n in names:
    if n in NUMERIC:
        val, possible = NUMERIC[n], "t_Number"
    elif n in STRINGS:
        val, possible = STRINGS[n], "t_String"
    else:
        val, possible = "false", "t_Boolean"
    e = lambda s: s.replace("'", "''")
    out.append(
        "INSERT INTO amp_global_settings (id, settingsname, settingsvalue, possiblevalues, description, section, internal)\n"
        "SELECT nextval('amp_global_settings_seq'), '%s', '%s', '%s', '%s', 'general', false\n"
        "WHERE NOT EXISTS (SELECT 1 FROM amp_global_settings WHERE settingsname = '%s');"
        % (e(n), e(val), possible, e(n), e(n)))

open(sys.argv[2], "w", encoding="utf-8", newline="\n").write("\n".join(out) + "\n")
print("settings to seed:", len(names))
