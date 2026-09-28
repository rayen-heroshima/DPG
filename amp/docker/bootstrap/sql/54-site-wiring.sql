-- What the first real HTTP request complained about.

-- The site's view-config folder: AMP loads WEB-INF/SITE/<folder>/site-config.xml
-- and 'amp' is the folder shipped in the war.
UPDATE dg_site SET folder = 'amp' WHERE id = 3;

-- Supported languages ("Language en(English) is not supported").
INSERT INTO dg_site_trans_lang_map (site_id, code)
SELECT 3, 'en' WHERE NOT EXISTS (SELECT 1 FROM dg_site_trans_lang_map WHERE site_id=3 AND code='en');
INSERT INTO dg_site_user_lang_map (site_id, code)
SELECT 3, 'en' WHERE NOT EXISTS (SELECT 1 FROM dg_site_user_lang_map WHERE site_id=3 AND code='en');

-- The common module instances — exactly the set DigiSchemaPopulate's
-- commented-out createCommonInstances() would have created.
INSERT INTO dg_module_instance (module_instance_id, module_name, module_instance,
                                permitted, num_of_items_in_teaser, site_id, real_instance_id)
SELECT v.id, v.m, v.i, true, 1, 3, NULL
FROM (VALUES (60,'admin','default'), (61,'um','user'), (62,'exception','default')) AS v(id, m, i)
WHERE NOT EXISTS (
    SELECT 1 FROM dg_module_instance d
     WHERE d.module_name = v.m AND d.module_instance = v.i AND d.site_id = 3);

-- A 'default' instance for every module in WEB-INF/moduleConfig. AMP resolves
-- /<module>/<action>.do to (module, 'default'); without these rows every /aim/*
-- page answers 404 once logged in, and teasers log "Module instance null is not
-- permitted. Required module: content, instance: default".
INSERT INTO dg_module_instance (module_instance_id, module_name, module_instance,
                                permitted, num_of_items_in_teaser, site_id, real_instance_id)
SELECT (SELECT coalesce(max(module_instance_id), 0) FROM dg_module_instance)
         + row_number() OVER (ORDER BY v.m), v.m, 'default', true, 1, 3, NULL
FROM (VALUES ('aim'), ('autopatcher'), ('budgetexport'), ('calendar'), ('categorymanager'),
             ('content'), ('contentrepository'), ('digifeed'), ('editor'), ('esrigis'),
             ('gateperm'), ('gpi'), ('help'), ('message'), ('parisindicator'), ('sdm'),
             ('search'), ('translate'), ('translation'), ('um'), ('xmlpatcher')) AS v(m)
WHERE NOT EXISTS (
    SELECT 1 FROM dg_module_instance d
     WHERE d.module_name = v.m AND d.module_instance = 'default' AND d.site_id = 3);

-- Keep Hibernate's generator ahead of the hand-assigned ids above.
SELECT setval('dg_module_instance_seq',
              (SELECT max(module_instance_id) FROM dg_module_instance));

-- A home page content item. After login AMP renders the site home page through
-- content/view/contentView.jsp, which imports layout_${contentLayout}.jsp; with
-- no row the layout is empty, layout_.jsp is not found, and the response dies
-- after it has started — the browser shows a white page. The htmlblocks are
-- editor keys, editable in place ("Edit HTML") by an admin.
INSERT INTO amp_content_item (amp_content_item_id, pagecode, layout, description,
                              ishomepage, htmlblock_1, htmlblock_2, title)
SELECT nextval('amp_content_item_seq'), 'home', '1', 'Home page', true,
       'content_home_sidebar', 'content_home_text', 'Home'
WHERE NOT EXISTS (SELECT 1 FROM amp_content_item WHERE ishomepage);

-- The site's default groups (Site.defaultGroups; keys from Group.java). A real
-- install creates them with the site; menu patches such as
-- AMP-19297-new-menu-config-01 look groups up by key and abort the whole
-- patcher run (and AMP startup) with a NULL group_id when they are missing.
INSERT INTO dg_group (id, inherit_security, creation_date, creation_ip, last_modified,
                      modifying_ip, parent_id, group_name, site_id, group_key)
SELECT nextval('dg_group_seq'), false, localtimestamp, NULL, localtimestamp, NULL, NULL, v.n, 3, v.k
FROM (VALUES ('Administrators', 'ADM'), ('Members', 'MEM'), ('Translators', 'TRN')) AS v(n, k)
WHERE NOT EXISTS (SELECT 1 FROM dg_group g WHERE g.group_key = v.k AND g.site_id = 3);
