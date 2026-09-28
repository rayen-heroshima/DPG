-- QuartzStartupListener.enableActivityCloserIfNeeded() registers the
-- CloseExpiredActivitiesJob the first time AMP ever starts against a database.
-- That path calls QuartzJobClassUtils.getJobClassesByClassfullName(), which
-- needs a managed Hibernate session the listener never opens, so it throws.
-- Any restored dump already carries this row (the job is registered once, ever),
-- which is why the failure only shows up on a from-scratch database.
INSERT INTO qrtz_job_details (job_name, job_group, description, job_class_name,
                              is_durable, is_volatile, is_stateful, requests_recovery, job_data)
SELECT 'CloseExpiredActivitiesJob', 'ampServices',
       'Pre-registered so AMP skips its one-time bootstrap registration',
       'org.digijava.module.message.jobs.CloseExpiredActivitiesJob',
       false, false, false, false, NULL
WHERE NOT EXISTS (
    SELECT 1 FROM qrtz_job_details
     WHERE job_class_name = 'org.digijava.module.message.jobs.CloseExpiredActivitiesJob');
