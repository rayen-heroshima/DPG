-- drop_view() from xmlpatches/2.z12.01/AMP-22614. Extracted by hand because the
-- patch declares delimiter=";" which splits its own PL/pgSQL body.
CREATE OR REPLACE FUNCTION drop_view(viewName varchar) RETURNS void AS $$
BEGIN
    IF (SELECT count(*) FROM pg_tables WHERE schemaname='public' AND tablename=viewName) = 1 THEN
        EXECUTE 'DROP TABLE ' || viewName || ' CASCADE';
    ELSE
        EXECUTE 'DROP VIEW IF EXISTS ' || viewName || ' CASCADE';
    END IF;
END;
$$ LANGUAGE plpgsql;
