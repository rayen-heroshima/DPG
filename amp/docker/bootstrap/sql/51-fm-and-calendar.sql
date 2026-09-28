-- Feature Manager template, FM module tree, and the default fiscal calendar.

-- AMP resolves the FM template by the id in the "Visibility Template" global
-- setting and fails startup when it is missing.
INSERT INTO amp_templates_visibility (id, name, visible)
SELECT nextval('amp_templates_visibility_seq'), 'Default', 'true'
WHERE NOT EXISTS (SELECT 1 FROM amp_templates_visibility WHERE name = 'Default');

INSERT INTO amp_global_settings (id, settingsname, settingsvalue, possiblevalues, description, section, internal)
SELECT nextval('amp_global_settings_seq'), 'Visibility Template',
       (SELECT id::text FROM amp_templates_visibility WHERE name='Default'),
       't_Template', 'Visibility Template', 'general', false
WHERE NOT EXISTS (SELECT 1 FROM amp_global_settings WHERE settingsname = 'Visibility Template');

-- RecreateFMEntries looks up the "Measures" module nested under "Reporting"
-- and NPEs when amp_modules_visibility is empty.
INSERT INTO amp_modules_visibility (id, name, description, haslevel, parent)
SELECT nextval('amp_modules_visibility_seq'), 'Reporting', 'Reporting', false, NULL
WHERE NOT EXISTS (SELECT 1 FROM amp_modules_visibility WHERE lower(name)='reporting');

INSERT INTO amp_modules_visibility (id, name, description, haslevel, parent)
SELECT nextval('amp_modules_visibility_seq'), 'Measures', 'Measures', false,
       (SELECT id FROM amp_modules_visibility WHERE lower(name)='reporting')
WHERE NOT EXISTS (SELECT 1 FROM amp_modules_visibility WHERE lower(name)='measures');

-- base_cal must be one of AMP's codes (GREG-CAL / NEP-CAL / ETH-CAL);
-- AmpFiscalCalendar.getworker() returns null for anything else, then NPEs.
INSERT INTO amp_fiscal_calendar (amp_fiscal_cal_id, start_month_num, start_day_num,
                                 year_offset, name, description, base_cal, is_fiscal)
SELECT 1, 1, 1, 0, 'Gregorian Calendar', 'Default Gregorian calendar', 'GREG-CAL', false
WHERE NOT EXISTS (SELECT 1 FROM amp_fiscal_calendar WHERE amp_fiscal_cal_id = 1);

-- INSERT-if-missing + UPDATE, not just UPDATE: on a from-scratch database no
-- earlier step creates this row, so an UPDATE alone would be a silent no-op and
-- leave it to fall through to the generic 'false' default later, which NPEs
-- here (AmpFiscalCalendar lookup by 'false' finds nothing).
INSERT INTO amp_global_settings (id, settingsname, settingsvalue, possiblevalues, description, section, internal)
SELECT nextval('amp_global_settings_seq'), 'Default Calendar', '1', 't_Calendar', 'Default Calendar', 'general', false
WHERE NOT EXISTS (SELECT 1 FROM amp_global_settings WHERE settingsname = 'Default Calendar');

UPDATE amp_global_settings SET settingsvalue='1', possiblevalues='t_Calendar'
 WHERE settingsname = 'Default Calendar';
