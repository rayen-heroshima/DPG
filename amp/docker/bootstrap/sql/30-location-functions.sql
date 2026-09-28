-- getlocationidbyimplloc / getlocationname
--
-- These two are the only helpers AMP's patch history never ships: every patch
-- from 2.7.04 onward *calls* them but none defines them, so on a real install
-- they arrive inside the country dump. Reconstructed here from AMP's own
-- reference implementation: getlocationidbyimpllocMap in
-- xmlpatches/2.8.3/AMP-16976.xml is the same walk-up-the-parent-chain
-- algorithm, over the same columns.
--
-- One deliberate difference from the Map variant: that one falls back to
-- returning its own input when no ancestor matches the requested level. Here we
-- return NULL instead, because every caller wraps this in
-- COALESCE(<level>_id, -acvl_id) ... 'Undefined' — i.e. callers expect NULL to
-- mean "this location has no ancestor at that level". Returning the input id
-- would claim a level-2 location is its own level-0.

CREATE OR REPLACE FUNCTION getlocationidbyimplloc(paramcvlocationid bigint, impllocation character varying)
    RETURNS bigint AS
$BODY$
DECLARE
    cValueId bigint;
    currentValueId bigint;
    parentCvLocationId bigint;
    cvLocationId bigint;
BEGIN
    cvLocationId := paramCvLocationId;
    currentValueId := 0;
    parentCvLocationId := cvLocationId;

    SELECT v.id INTO cValueId
        FROM amp_category_value v, amp_category_class c
        WHERE c.keyName = 'implementation_location'
          AND v.category_value = implLocation
          AND c.id = v.amp_category_class_id;

    WHILE currentValueId IS DISTINCT FROM cValueId AND parentCvLocationId IS NOT NULL LOOP
        cvLocationId := parentCvLocationId;
        SELECT loc.parent_category_value, loc.parent_location
            INTO currentValueId, parentCvLocationId
            FROM amp_category_value_location loc
            WHERE loc.id = cvLocationId;
    END LOOP;

    IF currentValueId IS NOT DISTINCT FROM cValueId THEN
        RETURN cvLocationId;
    END IF;
    RETURN NULL;
END;
$BODY$
LANGUAGE plpgsql STABLE;

CREATE OR REPLACE FUNCTION getlocationname(acvlid bigint)
    RETURNS character varying AS
$BODY$
DECLARE
    ret character varying;
BEGIN
    IF acvlid IS NULL THEN
        RETURN NULL;
    END IF;
    SELECT location_name INTO ret FROM amp_category_value_location WHERE id = acvlid;
    RETURN ret;
END;
$BODY$
LANGUAGE plpgsql STABLE;
