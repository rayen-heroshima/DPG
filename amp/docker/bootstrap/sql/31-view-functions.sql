-- Three helpers the general/views patches call but that no patch in AMP's tree
-- defines — like getlocationidbyimplloc, they arrive inside a country dump on a
-- real install. Written to match AMP's own conventions for these hierarchies:
-- getsectorlevel/getprogramlevel treat level 0 as the root ancestor and return
-- the node itself when it is already a root.

-- v_act_pp_sectors rolls each activity sector up to its top-level sector, which
-- is exactly getsectorlevel(id, 0).
CREATE OR REPLACE FUNCTION getparentsectorid(sectorid bigint)
    RETURNS bigint AS
$BODY$
BEGIN
    IF sectorid IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN getsectorlevel(sectorid, 0);
END;
$BODY$
LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION getsectorname(sectorid bigint)
    RETURNS character varying AS
$BODY$
DECLARE
    ret character varying;
BEGIN
    IF sectorid IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT name INTO ret FROM amp_sector WHERE amp_sector_id = sectorid;
    RETURN ret;
END;
$BODY$
LANGUAGE plpgsql STABLE;

-- amp_program_settings.default_hierarchy points at the root theme of a program
-- hierarchy, so a theme's settings row is the one whose default_hierarchy is
-- that theme's root ancestor.
CREATE OR REPLACE FUNCTION getprogramsettingid(themeid bigint)
    RETURNS bigint AS
$BODY$
DECLARE
    rootid bigint;
    ret bigint;
BEGIN
    IF themeid IS NULL THEN
        RETURN NULL;
    END IF;
    rootid := getprogramlevel(themeid, 0);
    IF rootid IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT amp_program_settings_id INTO ret
        FROM amp_program_settings
        WHERE default_hierarchy = rootid
        LIMIT 1;
    RETURN ret;
END;
$BODY$
LANGUAGE plpgsql STABLE;
