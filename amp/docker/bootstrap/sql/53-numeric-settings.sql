-- Global settings AMP parses with Integer/Long.valueOf. The generic 'false'
-- default used for unknown settings throws NumberFormatException on these.
-- '-1' is the documented "disabled" value for the audit cleaner; 0 for
-- AmpARFilter.AMOUNT_OPTION_IN_UNITS and the other id-style settings.
UPDATE amp_global_settings SET settingsvalue='-1', possiblevalues='t_Number'
 WHERE settingsname = 'Automatic Audit Logger Cleanup'
   AND settingsvalue !~ '^-?[0-9]+$';

UPDATE amp_global_settings SET settingsvalue='0', possiblevalues='t_Number'
 WHERE settingsname IN (
   'Amounts in Thousands',
   'Responsible Organization Default Organization Group',
   'Organisation type for Beneficiary Agency',
   'Closed activity status',
   'Default value for Activity Budget',
   'NDD Mapping Indirect Level',
   'NDD Mapping Program Level',
   'Reorder funding items',
   'Workspace Team to run reports from jobs',
   'Default Component Type',
   'Feature Template',
   'Mapping Destination Program',
   'Report wizard visibility source'
 ) AND settingsvalue !~ '^-?[0-9]+$';

UPDATE amp_global_settings SET settingsvalue='10', possiblevalues='t_Number'
 WHERE settingsname IN ('Maximum file size (MB)',
                        'Show icons for Project Sites for locations up to')
   AND settingsvalue !~ '^-?[0-9]+$';

-- Report year-range defaults. SettingsUtils.addDateSetting() Integer.parseInt()s
-- these; when the rows are missing /rest/amp/settings answers 500 and the
-- JS-rendered page header (amp-boilerplate) never draws. '-1' = no default.
INSERT INTO amp_global_settings (id, settingsname, settingsvalue, possiblevalues,
                                 description, section, internal)
SELECT nextval('amp_global_settings_seq'), v.n, '-1', 't_Number', v.n, 'general', false
FROM (VALUES ('Change Range Default Start Value'),
             ('Change Range Default End Value')) AS v(n)
WHERE NOT EXISTS (SELECT 1 FROM amp_global_settings g WHERE g.settingsname = v.n);
