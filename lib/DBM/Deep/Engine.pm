package DBM::Deep::Engine;

use strict;

use Fcntl qw( :DEFAULT :flock :seek );

sub open {
	##
	# Open a fh to the database, create if nonexistent.
	# Make sure file signature matches DBM::Deep spec.
	##
    my $self = shift;
    my $obj = shift;

	if (defined($obj->_fh)) { $self->close( $obj ); }
	
    eval {
        local $SIG{'__DIE__'};
        # Theoretically, adding O_BINARY should remove the need for the binmode
        # Of course, testing it is going to be ... interesting.
        my $flags = O_RDWR | O_CREAT | O_BINARY;

        my $fh;
        sysopen( $fh, $obj->_root->{file}, $flags )
            or $fh = undef;
        $obj->_root->{fh} = $fh;
    }; if ($@ ) { $obj->_throw_error( "Received error: $@\n" ); }
	if (! defined($obj->_fh)) {
		return $obj->_throw_error("Cannot sysopen file: " . $obj->_root->{file} . ": $!");
	}

    my $fh = $obj->_fh;

    #XXX Can we remove this by using the right sysopen() flags?
    # Maybe ... q.v. above
    binmode $fh; # for win32

    if ($obj->_root->{autoflush}) {
        my $old = select $fh;
        $|=1;
        select $old;
    }
    
    seek($fh, 0 + $obj->_root->{file_offset}, SEEK_SET);

    my $signature;
    my $bytes_read = read( $fh, $signature, length(DBM::Deep->SIG_FILE));
    
    ##
    # File is empty -- write signature and master index
    ##
    if (!$bytes_read) {
        seek($fh, 0 + $obj->_root->{file_offset}, SEEK_SET);
        print( $fh DBM::Deep->SIG_FILE);
        $obj->_create_tag($obj->_base_offset, $obj->_type, chr(0) x $DBM::Deep::INDEX_SIZE);

        my $plain_key = "[base]";
        print( $fh pack($DBM::Deep::DATA_LENGTH_PACK, length($plain_key)) . $plain_key );

        # Flush the filehandle
        my $old_fh = select $fh;
        my $old_af = $|; $| = 1; $| = $old_af;
        select $old_fh;

        my @stats = stat($fh);
        $obj->_root->{inode} = $stats[1];
        $obj->_root->{end} = $stats[7];

        return 1;
    }
    
    ##
    # Check signature was valid
    ##
    unless ($signature eq DBM::Deep->SIG_FILE) {
        $self->close( $obj );
        return $obj->_throw_error("Signature not found -- file is not a Deep DB");
    }

	my @stats = stat($fh);
	$obj->_root->{inode} = $stats[1];
    $obj->_root->{end} = $stats[7];
        
    ##
    # Get our type from master index signature
    ##
    my $tag = $obj->_load_tag($obj->_base_offset);

#XXX We probably also want to store the hash algorithm name and not assume anything
#XXX The cool thing would be to allow a different hashing algorithm at every level

    if (!$tag) {
    	return $obj->_throw_error("Corrupted file, no master index record");
    }
    if ($obj->{type} ne $tag->{signature}) {
    	return $obj->_throw_error("File type mismatch");
    }
    
    return 1;
}

sub close {
    my $self = shift;
    my $obj = shift;

    if ( my $fh = $obj->_root->{fh} ) {
        close $fh;
    }
    $obj->_root->{fh} = undef;

    return 1;
}

1;
__END__