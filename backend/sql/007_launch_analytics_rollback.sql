DROP INDEX IF EXISTS idx_product_crash_reports_created_at;
DROP TABLE IF EXISTS product_crash_reports;

DROP INDEX IF EXISTS idx_product_feedback_created_at;
DROP TABLE IF EXISTS product_feedback;

DROP INDEX IF EXISTS idx_product_analytics_user_id;
DROP INDEX IF EXISTS idx_product_analytics_session_id;
DROP INDEX IF EXISTS idx_product_analytics_event_name_time;
DROP TABLE IF EXISTS product_analytics_events;
