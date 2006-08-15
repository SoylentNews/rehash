#
# $Id$
#
INSERT INTO ajax_ops VALUES (NULL, 'firehose_fetch_text', 'Slash::FireHoses, 'fetchItemText, 'ajax_base', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_firehose', 'Slash::FireHose', 'tags_write', 'ajax_base', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_reject', 'Slash::FireHose', 'rejectItem', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_user_firehose', 'Slash::Firehose', 'ajaxGetUserFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_create_for_firehose', 'Slash::FireHose', 'ajaxCreateForUrl', 'ajax_tags_write', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_up_down', 'Slash::FireHose', 'ajaxUpDownFirehose', 'ajax_tags_write', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'tags_get_admin_firehose', 'Slash::Firehose', 'ajaxGetAdminFirehose', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'firehose_save_note', 'Slash::FireHose', 'ajaxSaveNoteFirehose', 'ajax_admin', 'createuse');
INSERT INTO css (rel, type, media, file, title, skin, page, admin, theme, ctid, ordernum, ie_cond) VALUES ('stylesheet','text/css','screen, projection','firehose.css','','','firehose','no','',2,0, '');
