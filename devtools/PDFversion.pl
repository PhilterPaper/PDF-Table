#!/usr/bin/perl
    use strict;
    use warnings;

#my $ourLAST = 1;  # T: change my $LAST_UPDATE to our $LAST_UPDATE

    my $src = $ARGV[0];  # directory root to work in for this call
    my $VERSION = $ARGV[1];  # version to use (e.g., 3.005)

    my ($entry, $name, $line);
    my $pattern = '^# VERSION';
    my $newVer  = "our \$VERSION = '$VERSION'; # VERSION";

    my $outtemp = 'xxxxx.temp';

    update_version($src);

# ------------------
# update .pl and .pm files with empty # VERSION line
sub update_version {
    my $src = shift;

    my @types = ('pl', 'pm');  # places to look for pattern in
    my @read_only = (0, 0);  # places to expect to be R/O
    my ($SRC, $IN, $OUT);

    # open this directory for reading
    opendir($SRC, "$src") || die "unable to open dir '$src': $!";

    my @dirList = ();
    my @fileList = ();

    while ($entry = readdir($SRC)) {
        if ($entry eq '.' || $entry eq '..') { next; }
    
        if (-d "$src\\$entry") {
            push (@dirList, "$src\\$entry");
        } else {
            if ($entry !~ m/\.p[lm]$/) { next; }
	    if     ($entry =~ m/\.$types[0]$/) {
              push (@fileList, "$src\\$entry");
            } elsif ($entry =~ m/\.$types[1]$/) {
              push (@fileList, "$src\\$entry");
	    } # else ignore
        }
    }

    # done reading, so close directory
    # have list of files and subdirectories within this one
    closedir($SRC);

    while ($name = shift(@fileList)) {
        if ($name =~ m/ - Copy/) { next; }
        # $name is full file path and name
	my $ro_flag = 0;
	for (my $i=0; $i<scalar @types; $i++) {
	    if ($read_only[$i] && $name =~ m/$types[$i]/) { $ro_flag = 1; }
	}

	# make Read-Write
	if ($ro_flag) { system("attrib -R $name"); }

        unless (open($IN, "<", $name)) { 
            die "Unable to update $name with version\n";
        }
        unless (open($OUT, ">", $outtemp)) { 
            die "Unable to open temporary output file $outtemp\n";
        }
   
        while ($line = <$IN>) {
	    # $line still has line-end \n
            $line =~ s/$pattern/$newVer/;
	   #if ($ourLAST) {
	   #    $line =~ s/^my \$LAST_UPDATE/our \$LAST_UPDATE/;
	   #}
	    print $OUT $line;
        }
   
        close($IN);
        close($OUT);
        $outtemp =~ s#/#\\#g;
        $name =~ s#/#\\#g;
	system("copy $outtemp $name");
        unlink($outtemp);

	# restore Read-Only
	if ($ro_flag) { system("attrib +R $name"); }
    } # process a .pX file found in a directory

    while ($entry = shift(@dirList)) {
        # is a directory... recursively call
        update_version($entry);
    }

    return;
}
