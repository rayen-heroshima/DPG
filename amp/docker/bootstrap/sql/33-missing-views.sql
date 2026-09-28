-- Views AMP's code requires but that no patch in the tree creates — like the
-- five hand-written helper functions, these only ever exist inside a dump.

-- InternationalizedViewsRepository declares v_pledges_donor with columns
-- (name, amp_donor_org_id). Modelled on its sibling v_pledges_donor_group,
-- joining pledges to amp_organisation via amp_funding_pledges.amp_org_id.
CREATE OR REPLACE VIEW v_pledges_donor AS
    SELECT afp.id AS pledge_id,
           v.name,
           COALESCE(v.amp_donor_org_id, -999999999) AS amp_donor_org_id
    FROM amp_funding_pledges afp
    LEFT JOIN (
        SELECT f.id AS pledge_id, o.name AS name, o.amp_org_id AS amp_donor_org_id
        FROM amp_funding_pledges f
        JOIN amp_organisation o ON f.amp_org_id = o.amp_org_id
    ) v ON afp.id = v.pledge_id;

-- v_activity_versions is created at runtime by
-- SimpleSQLPatcher.defineActivityVersionsViews(), but the view patches are
-- applied here before AMP ever boots, so it has to exist up front. This is that
-- method's statement verbatim, including its column ORDER: AMP re-issues it as
-- CREATE OR REPLACE on every start, and postgres refuses to replace a view whose
-- columns are named differently. The status list is AmpARFilter.VALIDATED_ACTIVITY_STATUS.
CREATE OR REPLACE VIEW v_activity_versions AS
    SELECT aag.amp_activity_group_id,
           max(aav.amp_activity_id) AS amp_activity_latest_validated_id,
           aag.amp_activity_last_version_id
    FROM amp_activity_group aag
    LEFT JOIN amp_activity_version aav
           ON (aag.amp_activity_group_id = aav.amp_activity_group_id)
          AND (aav.deleted IS NULL OR aav.deleted = false)
          AND (aav.draft IS NULL OR aav.draft = false)
          AND (aav.approval_status IN ('approved', 'startedapproved'))
    GROUP BY aag.amp_activity_group_id, aag.amp_activity_last_version_id;
