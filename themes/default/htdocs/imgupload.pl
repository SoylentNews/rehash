#!/usr/local/bin/perl -w
# This code is a part of Slash, and is released under the GPL.
# Copyright 1997-2005 by Open Source Technology Group. See README
# and COPYING for more information, or see http://slashcode.com/.
# $Id$

use strict;
use utf8;

use Slash;
use Slash::Display;
use Slash::Utility;
use File::Path;
use File::Temp qw(:mktemp);

sub main {
        my $user = getCurrentUser();
        my $form = getCurrentForm();
        my $slashdb = getCurrentDB();
        my $constants = getCurrentStatic();

        return if (!$user->{is_admin});

        my $op = lc($form->{op});
        my $ops = {
                default         => {
                        function        => \&receive_upload,
                        seclev          => 1,
                },
        };

        $op = 'default' unless $ops->{$op};

        my $retval = $ops->{$op}{function}->($form, $slashdb, $user, $constants);
}

sub receive_upload {
        my($form, $slashdb, $user, $constants) = @_;

        my $r = Apache2::RequestUtil->request;
	my $req = Apache2::Request->new($r);
        my $upload = $req->upload("fileToUpload");
        my $fh = $upload->fh;

        http_send({ content_type => 'text/html' });

        if ($upload->filename && $form->{fhid}) {
                my $saveblob = $constants->{admin_use_blob_for_upload};
                my $savefile = !$saveblob;

                my($ofh, $tmpname, $data, $name, $suffix, $file);

                $name = $upload->filename;
                ($suffix) = $name =~ /(\.\w+)$/;

                mkpath("/tmp/upload", 0, 0755) unless -e "/tmp/upload";

                local $/;
                $data = <$fh>;

                $file->{action} = 'upload';
                $file->{fhid} = $form->{fhid};

                if ($savefile) {
                        ($ofh, $tmpname) = mkstemps("/tmp/upload/fileXXXXXX", $suffix );
                        print $ofh $data;
                        close $ofh;
                        $file->{file} = $tmpname;
                } elsif ($saveblob) {
                        my $blob = getObject("Slash::Blob");
                        $file->{blobid} = $blob->create({
                                data    => $data,
                                seclev  => 0,
                                filename => $name
                        });
                }

                $slashdb->addFileToQueue($file);
        }
}

createEnvironment();
main();
1;

