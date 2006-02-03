#
# $Id$
#

##### ajax_base

INSERT INTO reskey_resources VALUES (100, 'ajax_base');

INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::User',                101);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'use', 'Slash::ResKey::Checks::Post',                151);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::ACL',                 201);
INSERT INTO reskey_resource_checks VALUES (NULL, 100, 'all', 'Slash::ResKey::Checks::Duration',            601);

INSERT INTO reskey_vars VALUES (100, 'adminbypass', 1, 'If admin, bypass checks for duration, proxy, and user');
INSERT INTO reskey_vars VALUES (100, 'acl_no', 'reskey_no_ajax', 'If this ACL present, can\'t use resource');
INSERT INTO reskey_vars VALUES (100, 'duration_max-failures', 1, 'how many failures per reskey');
INSERT INTO reskey_vars VALUES (100, 'duration_uses', 30, 'min duration (in seconds) between uses');




##### remarks

INSERT INTO ajax_ops VALUES (NULL, 'remarks_create', 'Slash::Remarks', 'ajaxFetch', '');
INSERT INTO ajax_ops VALUES (NULL, 'remarks_fetch',  'Slash::Remarks', 'ajaxFetch', '');

INSERT INTO reskey_resources VALUES (101, 'ajax_remarks');
INSERT INTO reskey_resource_checks VALUES (NULL, 101, 'all', 'Slash::ResKey::Checks::User', 101);
INSERT INTO reskey_vars VALUES (101, 'user_is_admin', 1, 'Requires user to be admin');

