#
# $Id$
#

DELETE FROM reskey_resources WHERE rkrid >= 100;
DELETE FROM reskey_resource_checks WHERE rkrid >= 100;
DELETE FROM reskey_vars WHERE rkrid >= 100;


INSERT INTO reskey_resources VALUES (100, 'ajax_base');
INSERT INTO reskey_resources VALUES (101, 'ajax_admin');
INSERT INTO reskey_resources VALUES (102, 'ajax_user');
INSERT INTO reskey_resources VALUES (103, 'ajax_subscriber');


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
INSERT INTO reskey_vars VALUES (100, 'duration_uses', 10, 'min duration (in seconds) between uses');


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




##### remarks

INSERT INTO ajax_ops VALUES (NULL, 'remarks_create', 'Slash::Remarks', 'ajaxFetch', 'ajax_admin', 'use');
INSERT INTO ajax_ops VALUES (NULL, 'remarks_fetch',  'Slash::Remarks', 'ajaxFetch', 'ajax_admin', 'use');

