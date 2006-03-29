INSERT IGNORE INTO reskey_vars VALUES (8,'duration_creation-use', 2, 'min duration (in seconds) between creation and use');
INSERT IGNORE INTO reskey_vars VALUES (8,'user_seclev', 2, 'Minimum seclev to use resource');
INSERT IGNORE INTO reskey_vars VALUES (8, 'duration_uses', 30, 'min duration (in seconds) between uses');
INSERT IGNORE INTO reskey_vars VALUES (8, 'duration_max-uses', '30', 'how many uses per timeframe');

INSERT INTO vars (name, description, value) VALUES ('bookmark_popular_days', "Number of days back to look for popular bookmarks", 1);
INSERT INTO vars (name, description, value) VALUES ('bookmark_allowed_schemes', "Schemes to allow for bookmarks.  Separate entries with |", "http|https");
