-- Global administrator.
--
-- DigiDaoAuthenticationProvider compares ShaCrypt.crypt(input) against
-- dg_user.password, and ShaCrypt is plain SHA-1 hex — so the stored value is
-- SHA1('admin123'). Change the password from the UI after first login.
INSERT INTO dg_user (id, email, first_names, last_name, password,
                     email_verified, banned, global_admin, creation_date, last_modified)
SELECT nextval('dg_user_seq'), 'admin@amp.org', 'AMP', 'Administrator',
       'f865b53623b121fd34ee5426c792e5c33af8c227', true, false, true, now(), now()
WHERE NOT EXISTS (SELECT 1 FROM dg_user WHERE email = 'admin@amp.org');

UPDATE dg_user SET global_admin = true, banned = false, email_verified = true
 WHERE email = 'admin@amp.org';

-- User.emailBouncing is a primitive boolean in the Hibernate mapping, so a NULL
-- here makes loading the user throw PropertyAccessException and login fails
-- with HTTP 500 ("Unable to load user").
UPDATE dg_user SET email_bouncing = false WHERE email_bouncing IS NULL;

-- The admin belongs in the site's Administrators group.
INSERT INTO dg_user_group (user_id, group_id)
SELECT u.id, g.id FROM dg_user u, dg_group g
WHERE u.email = 'admin@amp.org' AND g.group_key = 'ADM' AND g.site_id = 3
  AND NOT EXISTS (SELECT 1 FROM dg_user_group x WHERE x.user_id = u.id AND x.group_id = g.id);

-- Menu patches are data patches, which the patch registry marks as applied
-- without running. Reopen the base menu patches so AMP's own patcher creates
-- the menus at the next start; with no amp_menu_entry rows /rest/security/menus
-- is empty. Only these three: the later ones (from AMP-19518-menu-fm-def-02 on)
-- need the Feature Manager tree (amp_modules_visibility), which this empty
-- database lacks, and a failing patch halts the patcher and AMP's startup.
UPDATE amp_xml_patch p SET state = 0
 WHERE p.patch_id IN ('AMP-19297-add-current-menu-entries.xml',
                      'AMP-19297-add-dynamic-menu-entries.xml',
                      'AMP-19297-new-menu-config-01.xml')
   AND NOT EXISTS (SELECT 1 FROM amp_xml_patch_log l
                    WHERE l.patch_id = p.patch_id AND l.error = false);
