package Slash::Clout;

#sub insert_nextgen {
#        my($g, $insert_ar) = @_;
#        my $slashdb = getCurrentDB();
#        for my $hr (@$insert_ar) {
#                $hr->{gen} = $g; 
#                $slashdb->sqlInsert('tags_peerweight', $hr);
#        }
#}       
#        
#sub update_tags_peerweight {
#        my($insert_ar) = @_;
#        for my $hr (@$insert_ar) {
#                $tags_peerweight->{ $hr->{uid} } = $hr->{weight}; 
#        } 
#}               
#                
#sub B_copy_peerweight_sql {
#        my $slashdb = getCurrentDB();
#        $slashdb->sqlDo("SET AUTOCOMMIT=0");
#        $slashdb->sqlDo("DELETE FROM users_param WHERE name='tagpeerval2'");
#        $slashdb->sqlDo("INSERT INTO users_param SELECT NULL, uid, 'tagpeerval2', ROUND(weight,6)+0 FROM tags_peerweight");
#        $slashdb->sqlDo("COMMIT");
#        $slashdb->sqlDo("SET AUTOCOMMIT=1");
#}

