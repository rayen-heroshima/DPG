-- Foundational AMP seed data.
--
-- A real AMP install gets these rows from the country dump. This recreates the
-- minimum an empty, schema-only database needs in order to boot.
--
-- dg_site.id = 3 is not arbitrary: AMP's own patches hardcode SITE_ID=3 (see
-- xmlpatches/.../xmlpatcher_enable.xml), so 3 is the conventional id of the
-- main site in every AMP database.

BEGIN;

-- Locale ---------------------------------------------------------------------
INSERT INTO dg_locale (code, name, available, message_lang_key, left_to_right)
VALUES ('en', 'English', true, 'en', true)
ON CONFLICT (code) DO NOTHING;

-- Site -----------------------------------------------------------------------
INSERT INTO dg_site (id, name, site_id, inherit_security, creation_date, private_p,
                     priority, invisible, alerts_to_admin, default_language)
VALUES (3, 'AMP', 'amp', false, now(), false, 1, false, false, 'en')
ON CONFLICT (id) DO NOTHING;

-- Domain: must match AMP_SERVER_NAME / the host the browser uses, or AMP
-- will not resolve the request to a site.
INSERT INTO dg_site_domain (site_domain_id, site_domain, site_path, site_id,
                            language_code, is_default, enable_security)
SELECT nextval('dg_site_domain_seq'), 'localhost', NULL, 3, 'en', true, false
WHERE NOT EXISTS (SELECT 1 FROM dg_site_domain WHERE site_domain = 'localhost');

-- Currency -------------------------------------------------------------------
-- CurrencyUtil.getBaseCurrencyCode() falls back to 'USD' when the global
-- setting is absent, and AmpCurrencyConvertor NPEs if no such row exists.
INSERT INTO amp_currency (amp_currency_id, currency_code, currency_name,
                          country_name, active_flag, virtual_flag)
SELECT nextval('amp_currency_seq'), 'USD', 'US Dollar', 'United States', 1, false
WHERE NOT EXISTS (SELECT 1 FROM amp_currency WHERE currency_code = 'USD');

INSERT INTO amp_currency (amp_currency_id, currency_code, currency_name,
                          country_name, active_flag, virtual_flag)
SELECT nextval('amp_currency_seq'), 'EUR', 'Euro', 'European Union', 1, false
WHERE NOT EXISTS (SELECT 1 FROM amp_currency WHERE currency_code = 'EUR');

-- Global settings ------------------------------------------------------------
INSERT INTO amp_global_settings (id, settingsname, settingsvalue, possiblevalues,
                                 description, section, internal)
SELECT nextval('amp_global_settings_seq'), v.name, v.val, v.possible, v.name, v.section, false
FROM (VALUES
    ('Base Currency', 'USD', 't_Currency', 'general'),
    ('Recreate the views on the next server restart', 'true', 't_Boolean', 'general'),
    ('Default Language', 'en', 't_Language', 'general')
) AS v(name, val, possible, section)
WHERE NOT EXISTS (
    SELECT 1 FROM amp_global_settings gs WHERE gs.settingsname = v.name
);

COMMIT;
