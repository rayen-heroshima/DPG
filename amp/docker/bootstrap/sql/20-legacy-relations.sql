-- Relations the general/views patches read from but that the current Hibernate
-- model no longer creates. On a real install they survive inside the country
-- dump as legacy structures; without them ~35 of the view patches cannot compile.

-- Legacy store for a global setting's selectable values. Current AMP keeps these
-- in amp_global_settings.possiblevalues and no Java code writes this table any
-- more, so an empty table with the right shape is enough.
CREATE TABLE IF NOT EXISTS util_global_settings_possible_ (
    setting_name character varying(255),
    value_id     bigint,
    value_shown  character varying(255),
    id           bigint
);

-- Activity <-> performance-rule join table.
CREATE TABLE IF NOT EXISTS amp_activity_performance_rule (
    amp_activity_id     bigint,
    performance_rule_id bigint
);

-- Legacy column the v_project_implementation_unit view patch still selects.
-- SimpleSQLPatcher deliberately keeps it on real installs (its DROP is
-- commented out: "Has Mondrian reference"), but the Hibernate model no longer
-- maps it. Without it that patch fails, AMP's patcher halts the whole
-- recreate-views run, and startup dies on the missing v_ni_gpi_funding view.
ALTER TABLE amp_activity_version ADD COLUMN IF NOT EXISTS prj_implementation_unit boolean;

-- amp_xml_patch_log.idx is a leftover from when the mapping was a Hibernate
-- <list>; the <index column="idx"/> is commented out in AmpXmlPatch.hbm.xml, so
-- nothing populates it. Schema export still emits it NOT NULL, which aborts the
-- batch on every patch log write and rolls back the whole patcher run.
ALTER TABLE amp_xml_patch_log ALTER COLUMN idx DROP NOT NULL;

-- amp_activity is a VIEW in AMP (xmlpatches/general/views/amp_activity.xml
-- defines it as the latest non-deleted row per activity group), but there is
-- also an AmpActivity entity mapped to that name, so schema export creates it as
-- a TABLE. The view patch then fails with "amp_activity is not a view" and
-- everything built on it fails too. Drop the table so the patch can own the name.
DROP TABLE IF EXISTS amp_activity CASCADE;
