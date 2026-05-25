\i kyoto_subway_schemas.sql
\i seed_data.sql
\i views.sql
\i pipeline.sql

CALL sp_run_operational_etl(CURRENT_DATE, NULL, 1440);