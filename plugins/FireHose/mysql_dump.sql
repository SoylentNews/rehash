#
# $Id$
#
INSERT INTO ajax_ops VALUES (NULL, 'firehose_fetch_text', 'Slash::FireHose', 'fetchItemText', 'ajax_user_static', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_reject', 'Slash::FireHose', 'rejectItem', 'ajax_admin_static', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_firehose', 'Slash::FireHose', 'ajaxGetUserFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_firehose', 'Slash::FireHose', 'ajaxCreateForFirehose', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_up_down', 'Slash::FireHose', 'ajaxUpDownFirehose', 'ajax_user_static', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_firehose', 'Slash::FireHose', 'ajaxGetAdminFirehose', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_save_note', 'Slash::FireHose', 'ajaxSaveNoteFirehose', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_save_tab', 'Slash::FireHose', 'ajaxSaveFirehoseTab', 'ajax_user_static', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_remove_tab', 'Slash::FireHose', 'ajaxRemoveUserTab', 'ajax_user_static', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_list_tabs', 'Slash::FireHose', 'ajaxFirehoseListTabs', 'ajax_user_static', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_usage', 'Slash::FireHose', 'ajaxFireHoseUsage', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_media', 'Slash::FireHose', 'ajaxFetchMedia', 'ajax_base', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_top_firehose', 'Slash::FireHose', 'ajaxGetFireHoseTagsTop', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_combined_firehose', 'Slash::FireHose', 'ajaxGetCombinedFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','firehose.css','','','firehose','no','',2,0, '');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','firehose.css','','','users','no','',2,0, '');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','calendar.css','','','firehose','no','',2,0, '');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','firehose.css','','','users','no','',2,0, '');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','comments.css','','','firehose','no','',2,0, '');

INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_admin_extras', 'Slash::FireHose', 'ajaxGetAdminExtras', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_form', 'Slash::FireHose', 'ajaxGetFormContents', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_get_updates', 'Slash::FireHose', 'ajaxFireHoseGetUpdates', 'ajax_user', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_set_options', 'Slash::FireHose', 'ajaxFireHoseSetOptions', 'ajax_user_static', 'use');
INSERT INTO vars (name, value, description) VALUES ('firehose_admindownclout', '0.5', 'Admin clout for downvotes can be reduced by specifying a number between 0 and 1');
INSERT INTO vars (name, value, description) VALUES ('firehose_adminudcclout', '0.5', 'Admin clout for udc purposes (number between 0 and 1, probably');
INSERT INTO vars (name, value, description) VALUES ('firehose_adminupclout', '0.5', 'Admin clout for upvotes can be reduced by specifying a number between 0 and 1');
INSERT INTO vars (name, value, description) VALUES ('firehose_story_ignore_skids', '', 'list of skids that you want to not want created or shown as firehose entries.  Delimit skids with |');
INSERT INTO vars (name, value, description) VALUES ('firehose_color_slices', '30|30|0.2|0.2|0.2|0.2|0.2|0.0', 'Number or percent of remaining stories at each color level separated by | 30|0.5|0.5 would mean 30 stories at the level of highest popularity and 50% at each of remainining stories at the next 2 levels');
INSERT INTO vars (name, value, description) VALUES ('firehose_memcached_exptime', '600', 'Seconds to cache firehose data generally');
INSERT INTO vars (name, value, description) VALUES ('firehose_slice_points', '290,240 220,200 185,175 155,138 102,93 30,25 0,-20 -60,-999999', 'Seven pairs of numbers: the entry score and minimum score for each color slice (last min should be large negative)');
INSERT INTO vars (name, value, description) VALUES ('firehose_spam_score', '-50', 'Popularity score assigned to all firehose items with is_spam=yes');
INSERT INTO vars (name, value, description) VALUES ('firehose_color_labels', 'red|orange|yellow|green|blue|purple|violet|black', 'Firehose color labels');
INSERT INTO vars (name, value, description) VALUES ('firehose_anonval_param', '', 'String needed to be passed in anonval form param to validate requests, set to a string to enforce this validation');
INSERT INTO vars (name, value, description) VALUES ('firehose_logging', '0', 'Log firehose usage info?');
INSERT INTO vars (name, value, description) VALUES ('firehose_mcd_disp', '1', 'Cache dispFireHose results');

INSERT INTO firehose_tab VALUES (1,0,'Firehose','','createtime','DESC','indigo','fulltitle');
INSERT INTO firehose_tab VALUES (2,0,'Slashdot','story','createtime','DESC','black','full');
INSERT INTO firehose_tab VALUES (3,0,'Journals','journal','createtime','DESC','blue','full');
INSERT INTO firehose_tab VALUES (4,0,'User','"user:{nickname}"','createtime','DESC','black','full');

