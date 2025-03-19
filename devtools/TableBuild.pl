#!/usr/bin/perl
use strict;
use warnings;

# build PDF-Table distribution image
#
# consider copying MYMETA.* over META.* (before committing to GitHub)
# see if attrib +R Makefile.PL (after editing) eliminates Kwalitee warning. NO
#
use File::Path qw(make_path);
 
my $builder = 'Makefile.PL';
my $script  = 'Makefile';
my $hiDir   = 'PDF';
my $product = 'Table';
my $master  = 'Table.pm';
my $GHname  = 'PDF-Table';

my $VER;

unless (open($VER, "<", "version")) {
  die "Unable to open input 'version' control file to read! $!\n";
}
my $VERSION = <$VER>; chomp($VERSION);  # e.g., '3.011'
close $VER;
print "**** file 'version' contains '$VERSION'.\n";
to_continue();
# will auto-update .pm, .pl files below

unless (open($VER, "<", ".perl-version")) {
  die "Unable to open input '.perl-version' control file to read! $!\n";
}
my $PERL_version = <$VER>; chomp($PERL_version);  # e.g., '5.16.0'
close $VER;
print "**** file '.perl-version' contains '$PERL_version',
     and check $builder for proper PERL_version\n";
to_continue();
# future: 
#   * reformat PERL_version ('5.16.0' -> '5.16000') to read 
#     https://www.cpan.org/src/ Perl release dates, and warn if need to 
#     update minimum Perl version (BEFORE updating $builder)
#   * reformat PERL_version to something usable in $builder, (e.g.,
#     '5.16.0' -> '5.016000' and update that file with it, just like VERSION

print "**** have you rebuilt documentation and placed in INFO/?\n";
to_continue();

# -------------------------------------- configuration
my $make = 'gmake';  # dmake no longer available
my $desktop = "C:\\Users\\Phil\\Desktop\\";
my $temp = $desktop."temp";

# location of 7-Zip
$sevenZip = "\"C:\\Program Files\\7-Zip\\7z.exe\"";
$cmd7Zip  = $sevenZip . " a -r ";

# location of pod2html
$pod2html = "pod2html";   # should be in PATH

$baseDirSrc = $desktop . "$GHname\\";
#$outputBasename = "PDF-API2-" . substr($dirName, 1);

# absolute path so POD links will work
#$podBase = "/Free.SW/PDF-API2/$dirName/docs/lib/";
# --------------------------------------

# check for any files suffixed ~ or .bak (backup files) in source
if (checkForBackups($baseDirSrc)) {
    die "one or more backup or work files found -- remove\n";
}
# top level .pdf, .tmp, .html junk needs to go away

# grep -S  "2018" ..\*.* |grep -v "\~:" |grep -v "\.git" |grep -v "0x2018" |grep -v "\.cmap" |grep -v "\.data"
print "**** What is the current copyright year in various files? At some
     point did you go around and update all file copyrights?\n";
to_continue();
print "**** Anything listed in INFO/Deprecated to expire before this month?
     Consider removing deprecated items.\n";
to_continue();
#print "**** have you installed any prerequistes? if so, are the build
#     prereqs list in $builder and the optional library module
#     exclusion list in t/00-all-usable.t updated? press Enter.\n";
print "**** have you installed any prerequistes? if so, is the build
     prereqs list in $builder updated?\n";
to_continue();
print "**** are all working (bugfix) directories removed, or moved to
     another place?\n";
to_continue();
print "**** have you removed any old desktop\\temp directory?\n";
to_continue();
print "**** only $master should have \$VERSION defined:\n";
system("findstr /s /c:\"our \$VERSION =\" *.p?");
if_OK();
print "**** $product.pod should have version number updated (one line).\n";
to_continue();
print "**** Changes should have current date,
     and 'unreleased' notation removed.\n";
system("findstr /c:\"$VERSION\" Changes");
if_OK();
print "**** No file should be Read-Only.\n";
system("attrib /s *.* |grep \" R \" | grep -v \".git\" |more");
to_continue();

print "**** Have you remembered to update LAST_UPDATE everywhere changed?\n";
if_OK();
print "**** Have you 1) compared $GHname/ to /Strawberry, 2) run t-tests,
     3) run examples to thoroughly test? Have you 4) built all docs
     (.html) to check PODs? press Enter.\n";
to_continue();

system("attrib -R $builder");
update_with_version();
print "**** updated version in $builder (check). $master updated\n";
print "**** \$VERSION -- commit in GitHub. Press ENTER.\n";

#print "**** git status, pull/merge, add, commit, push as necessary.\n";
to_continue();

print "**** .pl and .pm files update to latest version\n";
system("mkdir $temp");
system("mkdir $temp\\t");
system("mkdir $temp\\INFO");
system("xcopy /s .\\*.* $temp");
system("xcopy /s .\\*.p? $temp");
system("xcopy .\\.gitignore $temp");
system("xcopy .\\CONTRIBUTING.md $temp");
system("xcopy .\\t\\*.t $temp\\t\\");
system("xcopy /s .\\examples\\*.* $temp\\examples\\");
#unlink("$desktop\\temp\\$builder");

# all other .pm and .pl files should just have an empty '# VERSION' line
print "calling PDFversion.pl\n";
system("devtools\\PDFversion.pl . $VERSION");

system('for /R %G in (*.pl) do dos2unix "%G"');
system('for /R %G in (*.pm) do dos2unix "%G"');
print "**** If .pl and .pm files should now have good VERSION,
     and they should be [unix] format, not DOS format.\n";
if_OK();

##system("dos2unix INFO\\old\\dist.ini.old");
system("dos2unix .perlcritic");
system("dos2unix .perl-version");
system("dos2unix CONTRIBUTING.md");
system("dos2unix Changes");
system("dos2unix LICENSE");
system("dos2unix $builder");
system("dos2unix MANIFEST");
system("dos2unix MANIFEST.SKIP");
system("dos2unix PDFpref");
system("dos2unix README");
system("dos2unix README.md");
system("dos2unix INFO\\*.*");
system("dos2unix lib\\$hiDir\\$product.pod");
system("dos2unix examples\\*.*");
system("dos2unix t\\*.*");
system("dos2unix t\\lib\\*.*");
system("dos2unix util\\*.*");
print "**** all other text files should now be [unix] format, not DOS format.\n";
if_OK();

print "**** build $script\n";
#system("attrib +R $builder");  # didn't seem to help
system("$builder");
##print "**** edit $script to insert VERSION update (and erase $script~)\n";
##print "(tab)PDFversion.pl \$(DISTVNAME) \$(VERSION)\n";
# gzip -> devtools/gzip
update2_Makefile();
print "**** Check $script.\n";
if_OK();

print "**** $make all\n";
system("$make all");
print "**** Check blib, etc.\n";
if_OK();

print "**** run tests\n";
system("$make test");
print "**** Did tests run OK?\n";
if_OK();

print "**** build distribution (.tar.gz)\n";
system("$make dist");
print "**** Is .tar.gz looking all right?\n";
if_OK();

system("xcopy /s $desktop\\temp\\*.* .");
#system("git checkout $builder");
#print "**** run unVERSION.bat to reverse all the VERSION settings.\n";
print "**** erase Desktop/temp/ if everything is clean in build\n";
print "**** erase $script, etc. new stuff (EXCEPT .tar.gz)\n";
print "**** log on to PAUSE as OMEGA/RoadMap and upload .tar.gz file\n";
print "**** consider removing an old release from CPAN\n";
print "**** update motd.php on website\n";
print "**** copy .tar.gz to releases/ and git rm oldest\n";
print "**** version update, including $product.pod, to next release\n";
print "**** Changes update next version, add UNRELEASED\n";
print "**** git update with latest changes\n";
print "**** update Examples on catskilltech.com with any new examples\n";
print "**** update Documentation on catskilltech.com with fresh copy\n";

# not (yet) generating .html from POD
#print "Proceeding. Ignore error messages \"Cannot find $hiDir::$product...\" in podpath.\n";

# clean out existing output structure, create empty dirs in destination
#prepOutputDirs("$baseDirDst$dirName\\");
#print "**** finished creating empty dest structure\n";

# copy over source/ to dest/code/
#copyToCode($baseDirSrc, "$baseDirDst$dirName");
#print "**** finished copying source to dest\n";

# create documentation .pm -> .html
#makeHTML("$baseDirSrc"."lib\\", "$baseDirDst$dirName\\docs\\lib\\", '');
#print "**** finished making HTML documentation\n";

# create downloads .tar.gz, .zip
#makeDownloads("$baseDirDst$dirName");
#print "**** finished making downloadables\n";

# -----------------------------------------
sub to_continue {
  print "+++++ Press Enter to continue...";
  my $response = <>;
  print "\n";
  return;
}
sub if_OK {
  print "+++++ If OK, press Enter to continue...";
  my $response = <>;
  print "\n";
  return;
}

# -----------------------------------------
# check for any files suffixed ~ or .bak (backup files) in source
#    also .swp, Thumbs.db files
# recursively call this routine for each level down
# returns TRUE if a backup found in this directory
sub checkForBackups {
  my $dir = shift;  # should end with \

  my $entry;
  my $DIR;
  my $result = 0; # nothing found yet

  # open this directory
  opendir($DIR, $dir) || die "unable to open dir '$dir': $!";

  my @dirList = ();
  my @fileList = ();
  while ($entry = readdir($DIR)) {
    if ($entry eq '.' || $entry eq '..') { next; }
    
    if (-d "$dir$entry") {
      push (@dirList, "$dir$entry");
    } else {
      push (@fileList, "$dir$entry");
    }
  }

  # done reading, so close directory
  closedir($DIR);

  while ($entry = shift(@fileList)) {
    # is a file... examine name
    # want to display all found, so don't quit on first
    if ($entry =~ m/\~$/ || $entry =~ m/\.bak$/ || 
	$entry =~ m/\.swp$/ || $entry eq 'Thumbs.db') {
      print "found backup or other undesirable file: $entry\n";
      $result++;  # local backup file count
    }
    # .html OK in docs\, but not elsewhere. will not be rolled up into build
    if ($entry =~ m/\.tmp$/  || # also check for .tmp
        $entry =~ m/\.pdf$/ && $dir ne $baseDirSrc."t\\resources\\" # also check for .pdf except in t/resources,
                            && $dir ne $baseDirSrc."examples\\resources\\"   # examples/resources
       ) {
      print "found work file or other undesirable file: $entry\n";
      $result++;  # local backup file count
    }
  }

  while ($entry = shift(@dirList)) {
    # some directories to ignore:
    if ($entry =~ m/\\dev$/) { next; }
    if ($entry =~ m/\\issue_scripts$/) { next; }
    if ($entry =~ m/\\releases$/) { next; }

    # is a directory... recursively call
    $result += checkForBackups("$entry\\");
  }

  return $result;
} # end checkForBackups()

# -----------------------------------------
# clean out existing output structure, create empty dirs in destination
sub prepOutputDirs {
  my $dir = shift;  # should end with \

 #my $parent = $dir;
 #$parent =~ s/v\d\.\d{3}\\$//;

  eraseDir($dir);
  # (re)create new directory
  mkdir($dir);

  # create code, docs, and downloads subdirectories
  mkdir($dir."code");
  mkdir($dir."docs");
  mkdir($dir."downloads");

  return;
} # end prepOutputDirs()

sub eraseDir {
  my $dir = shift;

  my $entry;
  my $DIR;

  # if $dir does exist, remove it recursively (must be empty for rmdir)
  if (-d $dir) {

    # open this directory
    opendir($DIR, $dir) || die "unable to open dir '$dir': $!";

    my @dirList = ();
    my @fileList = ();
    while ($entry = readdir($DIR)) {
      if ($entry eq '.' || $entry eq '..') { next; }
    
      if (-d "$dir$entry") {
        push (@dirList, "$dir$entry\\");
      } else {
        push (@fileList, "$dir$entry");
      }
    }

    # done reading, so close directory
    closedir($DIR);

    # erase all files in this dir
    while ($entry = shift(@fileList)) {
      unlink($entry);
    }
    # recursively visit all child directories
    while ($entry = shift(@dirList)) {
      eraseDir($entry);
    }

    # finally, remove THIS directory
    rmdir($dir);
  }

  return;
} # end eraseDir()

# -----------------------------------------
# copy over source/ to dest/code/
# inputs: source and destination dirs (/code will be added to dst)
sub copyToCode {
  my ($src, $dst) = @_;

  my $entry;

  $src .= "*.*";
  $dst .= "\\code\\";

  # put dir names in " " because they often have spaces in them
  system("xcopy \"$src\" \"$dst\" /E");


  return;
} # end copyToCode()

# -----------------------------------------
# inputs: source and destination base dirs, extra path built up
# create documentation .pm -> .html
# any .pm file found, see if looks like POD in it, if so run pod2html
# called recursively for each directory
#### unused
sub makeHTML {
  my ($src, $dst, $extra) = @_;
  # intially .../lib/, .../docs/lib/, ''. extra will change

  my ($entry, $input, $output, $isPOD, $outfile, $SRC, $OUT);
  # $podBase set up at top

  # open this directory for reading
  opendir($SRC, "$src$extra") || die "unable to open dir '$src$extra': $!";

  my @dirList = ();
  my @fileList = ();
  my @outputList = ();

  while ($entry = readdir($SRC)) {
    if ($entry eq '.' || $entry eq '..') { next; }
    
    if (-d "$src$extra$entry") {
      push (@dirList, $entry);
    } else {
      if ($entry !~ m/\.pm$/) { next; }

      # .pm file. does it contain =cut or =item?
      $isPOD = `grep -c -E "^=cut|^=item" "$src$extra$entry"`;
      if (substr($isPOD, 0, 1) ne '0') {
        push (@fileList, "$src$extra$entry");

        $entry =~ s/\.pm/.html/;
        push (@outputList, "$dst$extra$entry");
      }
    }
  }

  # done reading, so close directory
  closedir($SRC);

  while ($input = shift(@fileList)) {
    $output = shift(@outputList);

    # is a .pm file with POD content
    # $input is full file path and name
    # $output is full file path and name
    # if dir for output doesn't exist yet, mkdir it
    $outpath = $output;
    $outpath =~ s/^[a-z]://i;   # strip off drive
    $outpath =~ s/\\[^\\]+$//;
    if (!-d $outpath."\\") {
      make_path($outpath);
    }

    # --podroot and --podpath don't seem to work, so backpatch links
    # after creating the .html file
    $outfile = `pod2html \"$input\"`;  # string with HTML file
    while ($outfile =~ m#<a>(.*?)</a>#) {
      # outfile $output contains <a> in need of fixup
      # presumably we won't find orphan <a>'s with </a> on next line
      $href = $1;
      $href =~ s#::#/#g;  # globally change :: to /
      # expect href to start with PDF/, so podBase is /Free.SW...lib/
      $href = 'href="' . $podBase . $href . '.html"';  # absolute path, .html fileext
      $outfile =~ s/<a>/<a $href>/;
    }
    # write modified outfile to $output file
    unless (open($OUT, ">", $output)) { die "Unable to open POD output file '$output': $!\n"; }
    print $OUT $outfile;
    close($OUT); 

  } # process a .pm file found in a directory

  while ($entry = shift(@dirList)) {
    # is a directory... recursively call
    makeHTML($src, $dst, "$extra$entry\\");
  }


  return;
} # end makeHTML()

# -----------------------------------------
# create downloads .tar.gz, .zip
#### unused
sub makeDownloads {
  my ($dst) = shift;
  
  # dst/code is the source directory, and dst/downloads is the target directory
  # $outputBasename is like "$GHname-0.12"

  my $OUT;

  # also build dst/downloads/.downloads control file
  unless (open($OUT, ">", "$dst\\downloads\\.downloads")) {
    die "Unable to open output .downloads control file to write! $!\n";
  }

  # produce outputBasename.tar from dst/code
  system("$cmd7Zip $dst\\downloads\\$outputBasename.tar $dst\\code\\*");
  
  # produce dst/downloads/outputBasename.tar.gz from outputBasename.tar
  system("$cmd7Zip $dst\\downloads\\$outputBasename.tar.gz $dst\\downloads\\$outputBasename.tar");
   
  # erase outputBasename.tar
  unlink("$dst\\downloads\\$outputBasename.tar");
  print $OUT "$outputBasename.tar.gz\n";
  print $OUT "The complete package in GNU-zipped tarball.\n";
   
  # product dst/downloads/outputBasename.zip from dst/code
  system("$cmd7Zip $dst\\downloads\\$outputBasename.zip $dst\\code\\*");
  print $OUT "$outputBasename.zip\n";
  print $OUT "The complete package in Windows ZIP format.\n";
    
  close($OUT);


  return;
} # end makeDownloads()

# -----------------------------------------
# insert $VERSION into dist.ini, $builder, META.json, META.yml
# also dist.ini.old, although it is not currently used ## FOR TIME BEING, IGNORE
# $builder is no longer R/O
sub update_with_version {
    my ($f, $line);

    my ($IN, $OUT);

    my $outtemp = 'xxxxx.temp';
#   my @name = ("$builder", 'dist.ini', 'META.json', 'META.yml');
#   my @pattern = ('^(  "VERSION" => ")\d\.\d{3}(",\s)$',
#           '^(version = )\d\.\d{3}(\s)$', 
#           '^(   "version" : ")\d\.\d{3}(",\s)$',
#           '^(version: \')\d\.\d{3}(\'\s)$'
#          );
##  my @name = ("lib\\$hiDir\\$master");
##  my @pattern = ('^(\s*my \$version\s*=\s*\')\d\.\d{3}(\';.*)$',
##  		   '^(our \$VERSION = \')\d\.\d{3}(\'; # VERSION)',
##	           '^(version = )\d\.\d{3}(\s)$');
    my @name = ("lib\\$hiDir\\$master");
    my @pattern = ('^(\s*my \$version\s*=\s*\')\d\.\d{3}(\';.*)$',
    		   '^(our \$VERSION = \')\d\.\d{3}(\'; # VERSION)');

    foreach my $f (0 .. $#name) {
       #if ($f == 0) { system("attrib -R $name[0]"); }
        unless (open($IN, "<", $name[$f])) { 
            die "Unable to update $name[$f] with version\n";
        }
        unless (open($OUT, ">", $outtemp)) { 
            die "Unable to open temporary output file $outtemp\n";
        }
   
        while ($line = <$IN>) {
            $line =~ s/$pattern[$f]/$1$VERSION$2/;
	    print $OUT $line;
        }
   
        close($IN);
        close($OUT);
	system("copy $outtemp $name[$f]");

	system("dos2unix $name[$f]");

       #if ($f == 0) { system("attrib +R $name[0]"); }
    }
    system("erase $outtemp");

    return;
}

# -----------------------------------------
# update all .pm or .pl files in a directory
#### no longer called
sub update_VERSION {
    my $src = shift;  # single directory to work in for this call
    my $ro_flag = shift;  # true if expect R/O file

    my ($entry, $name, $entry, $line);
    my $pattern = '^# VERSION';
    my $newVer  = "our \$VERSION = '$VERSION'; # VERSION";

    my $outtemp = 'xxxxx.temp';
    my ($SRC, $IN, $OUT);

    # open this directory for reading
    opendir($SRC, "$src") || die "unable to open dir '$src': $!";

    my @dirList = ();
    my @fileList = ();

    while ($entry = readdir($SRC)) {
        if ($entry eq '.' || $entry eq '..') { next; }
    
        if (-d "$src$entry") {
            push (@dirList, "$src$entry/");
        } else {
            if ($entry !~ m/\.p[lm]$/) { next; }

            # .pm or .pl file
            push (@fileList, "$src$entry");

        }
    }

    # done reading, so close directory
    # have list of files and subdirectories within this one
    closedir($SRC);

    while ($name = shift(@fileList)) {

        # $name is a .pm file and is expected to be Read-Only
	# OR $name is a .pl file and is expected to be Read-Write
        # $name is full file path and name

	# make Read-Write
	if ($ro_flag) { system("attrib -R $name"); }

        unless (open($IN, "<", $name)) { 
            die "Unable to update $name with version\n";
        }
        unless (open($OUT, ">", $outtemp)) { 
            die "Unable to open temporary output file $outtemp\n";
        }
   
        while ($line = <$IN>) {
            $line =~ s/$pattern/$newVer/;
	    print $OUT $line;
        }
   
        close($IN);
        close($OUT);
        $outtemp =~ s#/#\\#g;
        $name =~ s#/#\\#g;
	system("copy $outtemp $name");
        system("erase $outtemp");

	# restore Read-Only
	if ($ro_flag) { system("attrib +R $name"); }
    } # process a .pm file found in a directory

    while ($entry = shift(@dirList)) {
        # is a directory... recursively call
        update_VERSION($entry, $ro_flag);
    }

    return;
}

sub update2_Makefile {
    # file should be ./Makefile
    # gzip --best --> devtools\gzip --best
    my @pattern = (
		   "gzip --best",
	          );
    my @newpat  = (
		   "devtools\\gzip --best",
	          );

    my ($IN, $OUT);

    my $infile = $script;
    my $outtemp = "xxxx.tmp";
    unless (open($IN, "<", $infile)) {
	die "Unable to read $infile for update\n";
    }
    unless (open($OUT, ">", $outtemp)) {
	die "Unable to write temporary output file for $infile update\n";
    }

    my ($line, $i, @frags);
    while ($line = <$IN>) {
	# $line still has line-end \n
	for ($i=0; $i<scalar(@pattern); $i++) {
	    if ($line =~ m/$pattern[$i]/) {
	        $line =~ s/$pattern[$i]/$newpat[$i]/;
		last;
	    }
	}
	print $OUT $line;
    }

    close($IN);
    close($OUT);
    system("copy $outtemp $infile");
    unlink($outtemp);

    return;
} # end update2_Makefile()

