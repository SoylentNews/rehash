#
# $Id$
#

INSERT INTO reskey_resources VALUES (100, 'ajax_base', 'no');
INSERT INTO reskey_resources VALUES (101, 'ajax_admin', 'no');
INSERT INTO reskey_resources VALUES (102, 'ajax_user', 'no');
INSERT INTO reskey_resources VALUES (103, 'ajax_subscriber', 'no');
INSERT INTO reskey_resources VALUES (104, 'ajax_tags_read', 'no');
INSERT INTO reskey_resources VALUES (105, 'ajax_tags_write', 'no');
INSERT INTO reskey_resources VALUES (106, 'ajax_base_static', 'yes');
INSERT INTO reskey_resources VALUES (107, 'ajax_admin_static', 'yes');
INSERT INTO reskey_resources VALUES (108, 'ajax_user_static', 'yes');


##### ajax_base

INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (100, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (100, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (100, 'duration_max-failures', 1, 'how many failures per reskey');


##### ajax_admin

INSERT INTO reskey_resource_checks VALUES (NULL, 101, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 101, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 101, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 101, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (101, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (101, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (101, 'duration_max-failures', 1, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (101, 'user_is_admin', 1, 'Requires user to be admin');
INSERT INTO reskey_vars VALUES (101, 'user_seclev', 100, 'Minimum seclev to use resource');


##### ajax_user

INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 102, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (102, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (102, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (102, 'duration_max-failures', 1, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (102, 'user_seclev', 1, 'Minimum seclev to use resource');


##### ajax_subscriber

INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 103, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (103, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (103, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (103, 'duration_max-failures', 1, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (103, 'user_is_subscriber', 1, 'Requires user to be subscriber');
INSERT INTO reskey_vars VALUES (103, 'user_seclev', 1, 'Minimum seclev to use resource');



##### ajax_tags_read

INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 104, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (104, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (104, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (104, 'duration_max-failures', 1, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (104, 'tags_canread_stories', 1, 'Requires user to have permission to read tags');
INSERT INTO reskey_vars VALUES (104, 'user_seclev', 1, 'Minimum seclev to use resource');


##### ajax_tags_write

INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);
INSERT INTO reskey_resource_checks VALUES (NULL, 105, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (105, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (105, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (105, 'duration_max-failures', 1, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (105, 'tags_canwrite_stories', 1, 'Requires user to have permission to write tags');
INSERT INTO reskey_vars VALUES (105, 'user_seclev', 1, 'Minimum seclev to use resource');


##### ajax_base_static

INSERT INTO reskey_resource_checks VALUES (NULL, 106, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 106, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 106, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 106, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 106, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);

INSERT INTO reskey_vars VALUES (106, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (106, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');


##### ajax_admin_static

INSERT INTO reskey_resource_checks VALUES (NULL, 107, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 107, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 107, 'all', 'Slash::ResKey::Checks::ACL',                 201);

INSERT INTO reskey_vars VALUES (107, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (107, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (107, 'user_is_admin', 1, 'Requires user to be admin');
INSERT INTO reskey_vars VALUES (107, 'user_seclev', 100, 'Minimum seclev to use resource');


##### ajax_user_static

INSERT INTO reskey_resource_checks VALUES (NULL, 108, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 108, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 108, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 108, 'all', 'Slash::ResKey::Checks::AL2::AnonNoPost',     301);
INSERT INTO reskey_resource_checks VALUES (NULL, 108, 'all', 'Slash::ResKey::Checks::AL2::NoPostAnon',     401);
INSERT INTO reskey_resource_checks VALUES (NULL, 108, 'all', 'Slash::ResKey::Checks::AL2::NoPost',         501);

INSERT INTO reskey_vars VALUES (108, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (108, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (108, 'user_seclev', 1, 'Minimum seclev to use resource');


##### remarks

INSERT INTO ajax_ops VALUES (NULL, 'remarks_create', 'Slash::Remarks', 'ajaxFetch', 'ajax_admin', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'remarks_fetch',  'Slash::Remarks', 'ajaxFetch', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'remarks_config', 'Slash::Remarks', 'ajaxFetchConfigPanel', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'remarks_config_save', 'Slash::Remarks', 'ajaxConfigSave', 'ajax_admin', 'createuse');

# signoff
INSERT INTO ajax_ops VALUES (NULL, 'admin_signoff', 'Slash::Admin', 'ajax_signoff', 'ajax_user_static', 'createuse');

# slashboxes
INSERT INTO ajax_ops VALUES (NULL, 'admin_slashdbox', 'Slash::Admin', 'ajax_slashdbox', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'admin_storyadminbox', 'Slash::Admin', 'ajax_storyadminbox', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'admin_authorbox', 'Slash::Admin', 'ajax_authorbox', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'admin_perfbox', 'Slash::Admin', 'ajax_perfbox', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'admin_recenttagnamesbox', 'Slash::Tags', 'ajax_recenttagnamesbox', 'ajax_admin', 'createuse');
INSERT INTO ajax_ops VALUES (NULL, 'admin_learnword', 'Slash::Admin', 'admin_learnword', 'ajax_admin', 'createuse');


INSERT INTO ajax_ops VALUES (NULL, 'admin_neverdisplay', 'Slash::Admin', 'ajax_neverdisplay', 'ajax_admin_static', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'admin_submit_memory', 'Slash::Admin', 'ajax_sub_memory', 'ajax_admin_static', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'getTopVendorStory', 'Slash::SlashdotJournal', 'ajaxShowVendorStory', 'ajax_user', 'createuse');

INSERT INTO ajax_ops VALUES (NULL, 'page_save_user_boxes', 'Slash::Page', 'ajaxSaveUserBoxes', 'ajax_user_static', 'use');


##### d2 stuff
INSERT INTO code_param VALUES (NULL, 'd2_comment_q', 0, 'All');
INSERT INTO code_param VALUES (NULL, 'd2_comment_q', 1, 'Tiny');
INSERT INTO code_param VALUES (NULL, 'd2_comment_q', 5, 'Medium');
INSERT INTO code_param VALUES (NULL, 'd2_comment_q', 9, 'Large');

INSERT INTO code_param VALUES (NULL, 'd2_comment_limits', 1, 5);
INSERT INTO code_param VALUES (NULL, 'd2_comment_limits', 5, 25);
INSERT INTO code_param VALUES (NULL, 'd2_comment_limits', 9, 50);

