INSERT INTO dynamic_blocks VALUES (1, 'portal', 'no');
INSERT INTO dynamic_blocks VALUES (2, 'portal', 'yes');
INSERT INTO dynamic_blocks VALUES (3, 'admin', 'no');
INSERT INTO dynamic_blocks VALUES (4, 'admin', 'yes');
INSERT INTO dynamic_blocks VALUES (5, 'user', 'no');
INSERT INTO dynamic_blocks VALUES (6, 'user', 'yes');

INSERT INTO dynamic_user_blocks (type_id, uid, name, title, description, seclev, created, last_update) VALUES (3, 0, 'performancebox', 'Performance', 'Performance Stats', 10000, NOW(), NOW());
INSERT INTO dynamic_user_blocks (type_id, uid, name, title, description, seclev, created, last_update) VALUES (3, 0, 'authoractivity', 'Authors', 'Author Activity', 10000, NOW(), NOW());
INSERT INTO dynamic_user_blocks (type_id, uid, name, title, description, seclev, created, last_update) VALUES (3, 0, 'admintodo', 'Admin Todo', 'Admin Todo Items', 10000, NOW(), NOW());
INSERT INTO dynamic_user_blocks (type_id, uid, name, title, description, seclev, created, last_update) VALUES (3, 0, 'recenttagnames', 'Recent Tagnames', 'Recent Tagnames', 10000, NOW(), NOW());
INSERT INTO dynamic_user_blocks (type_id, uid, name, title, description, seclev, created, last_update) VALUES (3, 0, 'firehoseusage', 'Firehose Usage', 'Firehose Usage', 10000, NOW(), NOW());

INSERT INTO ajax_ops VALUES (NULL, 'dynamic_blocks_delete_message', 'Slash::DynamicBlocks', 'ajaxDeleteMessage', 'ajax_user_static', 'createuse');
