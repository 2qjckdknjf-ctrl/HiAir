ALTER TABLE user_settings
    ADD COLUMN IF NOT EXISTS preferred_language TEXT NOT NULL DEFAULT 'ru';

ALTER TABLE user_settings
    DROP CONSTRAINT IF EXISTS user_settings_preferred_language_check;

ALTER TABLE user_settings
    ADD CONSTRAINT user_settings_preferred_language_check
    CHECK (preferred_language IN ('ru', 'en'));
