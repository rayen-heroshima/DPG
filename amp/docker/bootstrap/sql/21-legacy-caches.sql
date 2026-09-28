-- Pre-"ni_" names of the sector/program level caches. AMP truncates and
-- repopulates these, so they must be TABLES, not views onto the ni_ ones.
-- Run after the view patches, since they are built from the v_ views.

CREATE OR REPLACE VIEW v_all_sectors_with_levels AS
    SELECT s.amp_sector_id, s.parent_sector_id, cc.name AS sector_config_name,
           ss.amp_sec_scheme_id, ss.sec_scheme_code, ss.sec_scheme_name,
           s.sector_code, s.name,
           getsectorlevel(s.amp_sector_id, 0) as id0,
           getsectorlevel(s.amp_sector_id, 1) as id1,
           getsectorlevel(s.amp_sector_id, 2) as id2,
           getsectorlevel(s.amp_sector_id, 3) as id3,
           getsectorlevel(s.amp_sector_id, 4) as id4
    FROM amp_sector s
    LEFT JOIN amp_sector_scheme ss ON s.amp_sec_scheme_id = ss.amp_sec_scheme_id
    LEFT JOIN amp_classification_config cc ON cc.classification_id = ss.amp_sec_scheme_id;

DROP TABLE IF EXISTS all_sectors_with_levels CASCADE;
CREATE TABLE all_sectors_with_levels AS SELECT * FROM v_all_sectors_with_levels;

DROP TABLE IF EXISTS all_programs_with_levels CASCADE;
CREATE TABLE all_programs_with_levels AS SELECT * FROM v_all_programs_with_levels;
