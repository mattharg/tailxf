#!perl -w
#
#
#    #!/bin/sh   
#    . $HOME/scripts/perl.sh.executor
$RELEASE = '4';                         # At every release to others
$MYNAME="$0"; $MYNAME =~ s/.*\///;      # MyName from filename.
$SCCS_VER="%W%     %G%";               
$RCS_VER='$Revision: 1.1 $'; $RCS_VER =~s/^\$\Revision//; $RCS_VER =~s/ \$$//;
$VER="$RCS_VER";                        # Select the source control being used....
$ME_SHORT = 'AE1-' . $RELEASE;          # My i/d short form
$ME = "$MYNAME" . $VER;                 # My i/d full  form
# File:             tailxf.pl
# Title             Multiple (log) file viewer, alla 'tail -f' on multi-files
# Require. Spec:              
# Description:        
# Author            Matthew S. Hargreaves
# Use               See sub usage() below...
#                   o Use this as basis for the NEXT AE1........ engine + + 
# BUGS              o The 'select' isn't WORKING............
#                   o perl's syslog isn't working
#                   o Use select to wait on many files at once. NOT WORKING - Why NOT?
# TODO              . trap ^C and exit gracefully... CACHE-ing file lengths, in order to 
#                     start at the same place in the file next time.....
#                   o option to start an Xterm with this.. 
#                     see sub tailx() below, mod if DISPLAY is set....
#                   o Detect truncation and absence and restart on that file...
#                       maybie the read <FILE> will help us with detecting this. (skulk OK)
#                   o Think up a good system to conditionally give ERROR, WARN NOTICE, INFO...
#                       ANSWERE! use logit, get it to accept a LEVEL as well as the other
#                       options. , $ALERT=9, $ERROR=8, $WARN=7, ...
#                       Also can have the call to syslog use this LEVEL!!!! heartbeat at DEBUG
#                   o Improve the names of things...
#                   o What about making it SUID to root...
#                   o Put in own heartbeat into this, viz, set timer, respond, syslog on
#                       local7.trace (ie. NOT local7.info).... use new logit fn
#                   o syslog should be inperl not logger - test using pcl
#                   o Allow NOLOG option in ae1.log.files
#                   o put signal traps in.
#                     o stop Gracefully
#                     o HUP restart
#                     o INT cancel
#                     o     report status to logfile
#                     o     restart viewers
#                   o tailf - if less is used, can make use of less functionality....
#                       less is better cause can also do searches and then return to tailf
#                       How about xterm -c "(tail -300 $ile; less -F $ile)"
#                   o Introduce File limit (syntax) into xref file
#                   o
#                   o
#                   o Make AE1 servable to multi-host::
#                     - AE1.CONFIG     look first for AE1.CONFIG.$HOSTNAME     (start|stop|stat)
#                     - ae1.xref.table look first for ae1.xref.table.$HOSTNAME (start|stop|stat)
#                     - ae1.log.files  look first for ae1.log.files.$HOSTNAME  (tailxf.pl)
#                   o
#                   o
#                   o
# MYLOGFILE(logit)  o default  use without going to a file, just like tailx...
#                   o -c fl    use going to a file *ONLY* for AE1 daemon.. (and logger)
#                   x -m fl    use as a monitor to the CENTRAL (MYLOGFILE) file. tail -f enough
#                   o
#                   o
# SUBROUNTINES
#                   o getdate()            Read the clock; 
#                   o usage()              Provide Usage on this prog.
#                   o logit()              Output formatted (collated) mssg to STDOUT or file. 
#                   o TRACE()              Print out tracing info - rm this use logit instead
#                   o getmylength()        Sync var. to files actual length (num lines)
#                   o introduce_files()    introduce the supplied files to list to be monitored
#                   o process_ae1_log_files   'Process' an ae1.log.files  -like file,
#                   o process_ae1_xref_table  'Process' an ae1.xref.table -like file
#                   o use_LOGFILE          Use the supplied file as the CENTRAL LOG FILE
#                   o monitor              (engine) monitor the file list, collating to STDOUT or CENTRAL
#                   o skulk                skulk a file
#                   o skulk_me             skulk the CENTRAL log file
#                   o
#                   o
#                   o
# 
#
#

# R e q u i r e s
#####################
require "ctime.pl";

#  S t d   N a m e s 
###########################
@asci_dow=('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat');
@asci_mon=('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
           'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec');
&getdate;
$LOG=$ENV{"HOME"} . "/log";
##$WHOAMI=`whoami`; chop($WHOAMI);  # how about perl id cmmd....
$WHOAMI=getlogin;

##$TMPFILE_BASE="/tmp/$ME.tmp.$DATE.$$";  #DO I use these .....
##$TMPFILE_IN ="${TMPFILE_BASE}.IN";
##$TMPFILE_OUT="${TMPFILE_BASE}.OUT";
##$TMPFILE_ERR="${TMPFILE_BASE}.ERR";

# C o n f i g u r a t i o n 
###########################

select ; $|=1; #ensure stdout is unbuffered

# C o l l e c t    A E 1   E n v   V a r s 
##########################################
##&getdate();

# Defaults
$COMPRESS_CMMD     ="/bin/compress"; 
$PERMANENT_DIR     ="/tmp"; 
$MY_MAX_LENGTH     =5000;
$XTERM             ="/usr/bin/x11/xterm";

$TRACE_LEVEL       =$ENV{'AE1_TRACE_LEVEL'};      # This pro's tracing
$HOST              =$ENV{'AE1_HOST_NAME'};        # The host I'm running on
$GET_DATE_CMMD     =$ENV{'AE1_DATE_COMMAND'};     # Command to get a date string...
$HERE              =$ENV{'AE1_HERE'};             # The HOME/HERE/LOCATION for this appl
$MY_LOG_FILE       =$ENV{'AE1_LOG_FILE'};         # Where I log to.
$MY_MAX_LENGTH     =$ENV{'AE1_MAX_LENGTH'};       # Max lines before truncate self
$MAX_CHANGE_IN_LOG =$ENV{'AE1_MAX_CHANGE_IN_LOG'};# Max change in log before IGNORING
$GET_AE1CONS_PIDS  =$ENV{'AE1_PIDFROMUSERID'};# cmmd to get PIDs of ae1cons
$SLEEP_TIME        =$ENV{'AE1_SLEEP_TIME'};# time to sleep in seconds 
$COMPRESS_CMMD     =$ENV{'AE1_COMPRESS'}          # Command to compress a permanent skulk
                    if (defined $ENV{'AE1_COMPRESS'});
$PERMANENT_DIR     =$ENV{'AE1_PERMANENT_DIR'}     # Where to store PERMANENT skulks
                    if (defined $ENV{'AE1_PERMANENT_DIR'});
$XTERM             =$ENV{'AE1_XTERM'}  if (defined $ENV{'AE1_XTERM'});

$XREF              =$HERE . '/etc/ae1.xref.table';# ae1's first config file 
$LOGFILES          =$HERE . '/etc/ae1.log.files'; # ae1's second config file

# OTHER LOCAL VARS
##################
$TRUE = 1; $FALSE = 0; $NOTTHERE = 'NOTTHERE'; $DONT_LOG = '-';
$MY_LENGTH =0;
$USING_LOGFILE=$FALSE;

##############################
# T a b l e s   - construction    
##############################
sub process_ae1_log_files { $AE1LOGFILES=$_[0];
	local @intro_list=();
	print "$ME: NOTICE.  Introducing log files from $AE1LOGFILES\n" if ($TRACE_STARTUP);
	open(AE1LOGFILES, "<$AE1LOGFILES") || die "$ME:ERROR, Cant open $AE1LOGFILES\n";
	while (<AE1LOGFILES>) { if ($_ !~ '^#') {
		@args=split; $logfile=shift @args; 
		push @intro_list, $logfile;

		$SK_LINES{$logfile} = 0;  # if +ve, skulking will take place after n lines
		$SK_LEVEL{$logfile} = 0;  # if +ve, skulking 'age' levels, ie. file.1, file.2 file.3
		$SK_KEEP{$logfile}  = 0;  # if +ve, skulking will keep this many lines in the file
		$SK_PERM{$logfile}  = 0;  # if +ve, skulking will copy to permanent location, eg. /tmp

		foreach $PARAM (@args) { #rest of args
			$P_TYPE  = substr($PARAM, 0, 2);    $P_VALUE = substr($PARAM, 2);
##			print "TRACE: arg ,$PARAM, P_TYPE .$P_TYPE. P_VALUE ,$P_VALUE,\n";
			   if ($P_TYPE eq 'KP') {  $SK_KEEP{$logfile} = $P_VALUE; }
			elsif ($P_TYPE eq 'LN') { $SK_LINES{$logfile} = $P_VALUE; }
			elsif ($P_TYPE eq 'LV') { $SK_LEVEL{$logfile} = $P_VALUE; }
			elsif ($P_TYPE eq 'PM') {  $SK_PERM{$logfile} = 1; }
		} #done rest of args...
	} }
	close(LOGFILES);
	&introduce_files(@intro_list);
	print "$ME: NOTICE.  Completed Introducing log files from $AE1LOGFILES\n" if ($TRACE_STARTUP);
}

$num_xrefs=0;
sub process_ae1_xref_table { $AE1XREFTABLE=$_[0];
	local @intro_list=();
	print "$ME: NOTICE.  Introducing matches from $AE1XREFTABLE\n" if ($TRACE_STARTUP);
	open(AE1XREFTABLE, "<$AE1XREFTABLE") || die "$ME:ERROR, Cant open $AE1XREFTABLE\n";
	while (<AE1XREFTABLE>) { if ($_ !~ '^#') {
		$xref = $_; $num_xrefs += 1;
##		$XTABLE_ACTION {$num_xrefs} = '';      # undefined is better
##		$XTABLE_REPLACE{$num_xrefs} = ''; # undefined is better
##		$XTABLE_REGEXP {$num_xrefs} = ''; # undefined is better

		# NB FORMAT IS
		# ^act.my.script     !ACTION!My reg.* expression[s]*!REPLACEMENT! perhaps a replacement
		# NB  HOW ABOUT....
		# ^act.my.script     !ACTION!!FILE filename FILE!Myreg.* expression[s]*!REPLACEMENT! perhaps a replacement
		# To limit to only the ONE File.......

		if ($xref =~ s/^(.*)!ACTION!//)      {  $XTABLE_ACTION{$num_xrefs} = "$1"; }
		if ($xref =~ s/!REPLACEMENT!(.*)$//) { $XTABLE_REPLACE{$num_xrefs} = "$1"; }
		chop($xref);                            $XTABLE_REGEXP{$num_xrefs} = $xref;

##		print("action:$XTABLE_ACTION{$num_xrefs}, regexp:$XTABLE_REGEXP{$num_xrefs}, replace:$XTABLE_REPLACE{$num_xrefs}, \n" );
	} }
	close(AE1XREFTABLE);
	if ($TRACE_STARTUP) { print "\n"; foreach $a (keys %XTABLE_REGEXP) {
		printf "%40s::", $XTABLE_REGEXP{$a};
		if (defined $XTABLE_ACTION{$a})  { print "action::$XTABLE_ACTION{$a}::";  }
		if (defined $XTABLE_REPLACE{$a}) { print "replace::$XTABLE_REPLACE{$a}::"; }
		print "\n";
	} }
	print "$ME: NOTICE.  Complete Introducing matches from $AE1XREFTABLE\n" if ($TRACE_STARTUP);
}

# F u n c t i o n s 
###################

sub getdate {
	($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$SHORT_DATE=sprintf("%02d.%02d.%2d.%02d:%02d:%02d", 
		$mday, $mon, $year, $hour, $min, $sec);
	$DATE=sprintf("%3s %02d/%3s %02d:%02d:%02d", 
	$asci_dow[$wday], 
	$mday, 
	$asci_mon[$mon], 
	$hour, 
	$min, 
	$sec);
}

sub TRACE {
	# Flesh this out abit....
	print "@_\n";
}

sub usage {
	print "
$ME:D E S C R I P T I O N\n
$ME: 
$ME: (x) This program allows for the monitoring of a group (x) of files
$ME: (f) in a simillar manner to 'tail -f' (f),
$ME:     Also it produces ONE CENTRAL COLLATED logfile image .
$ME:     with each log message timestamped.
$ME: It's features include:
$ME:  o logfile management, viz skulking logfiles on their length
$ME:  o pattern matching, to convert, or filter out, log messages.
$ME:  o automatic actions on receipt of messages (regexp pattern match).
$ME: 
$ME:U S A G E
$ME: 
$ME: $MYNAME 
$ME: $MYNAME {PARAMS}\*
$ME: Without parameters, it will view the ouput of any running $MYNAME deamons.
 {file}*      Introduce these files to be monitored, and monitor them.
 -c {file}    Run in the background, collating onto the central file 
 -m {file}    Monitor the central file only.
 -l logfile   Get a list of files to monitor from logfile. 
              (allows logfile management options, eg. skulking)
 -x xreffile  Get a list of matches from xreffile 
              (allows filtering, replacing, and triggering actions)
 -t           Trace. Report on the logfiles and patterns introduced. 
 -s           Status. Report on any running daemons, 
                their recent daemon history, and default CONFIG values.
 -? | -h      Give this help message and abort.
                
                
$ME: 
$ME:C O N F I G U R A T I O N 
$ME:Other than the command line parameters, $MYNAME can be configured
$ME: by environment variables. Here are some of them.
$ME:   AE1_ROOT     defines the root of a subtree holding AE1 files.
$ME:                \$\AE1_ROOT/etc/AE1.CONFIG is a ksh source '.' 
$ME:                file holding default values. 
$ME: 	LOGPATH      the directory where the central collated file is held
$ME: 	AE1_PERMANENT_DIR   the directory for 'permanent' skulk's
$ME: 	AE1_LOG_FILE     the full pathname of the collated file
$ME: 	AE1_XTERM        the xterm program to use for monitoring windows
$ME: 	NICEPARAMS       the params to supply to nice when deamonising 
$ME: 	AE1_TRACE_LEVEL  a number indicating the trace level
$ME: 	AE1_MAX_LENGTH   maximum length of the collated file before skulking it.
$ME: 	AE1_SLEEP_TIME   number of secs to sleep after watching each file
$ME: 	AE1_COMPRESS     program to use to compress the 'permanent skulks'
$ME: 
";
}

#  L o c a l  F u n c t i o n s 
###############################

$alldescriptors="";  # bitmap to hold the list of open file descriptors for the select call
sub introduce_files { local @files=@_;
	# Get Info For each file, file handle, numlines, basename, ...
	printf STDOUT "leng : hd : Basename             : Full Path\n" if ($TRACE_STARTUP);
	printf STDOUT "---- : -- : --------             : ---- ----\n" if ($TRACE_STARTUP);
	for (@files) { if (!-r $_) { 
			select STDOUT; $|=1; #Make sure STDOUT is unbuffered, how we like it for viewing.
			printf STDOUT "$ME: WARNING - File is NOT readable - %s\n", $_;
		} else { # file is readable...
			$handles{$_}="$_";                 # Here we say $handles{"/tmp/fred"}="/tmp/fred";
			$RET=open($handles{$_}, "<" . $_); # Here we say open(/tmp/fred, "</tmp/fred");
																				 # ie. the name of the handle is the name of the file.
																				 # once you've used that name for the handle you cant rename it.
			if (!defined $RET) { 
				printf STDOUT "Cant open file $_ \n"; 
				delete $handles{$_};
			} else { 
				$numlines{$_}=0;            # since this is defined, it exists.
				($bn{$_} = $_) =~ s#.*/##;  # since this is defined, it exists.
				select $handles{$_}; $|=0; # Make the i/p file buffered for use by select...
		##		print "$_ return $RET on open\n";
		##		$h_vec=""; vec($h_vec, fileno($handles{$_}), 1)=1;
		##		$alldescriptors=$alldescriptors | $h_vec;
				vec($alldescriptors, fileno($handles{$_}), 1)=1;
				select STDOUT; $|=1; #Make sure STDOUT is unbuffered, how we like it for viewing.
				printf STDOUT "%4d : %2d : %20s : %s\n", length($alldescriptors), fileno($handles{$_}), $bn{$_}, $_ if ($TRACE_STARTUP);
			}
	} }
	select STDOUT; $|=1;
	$ori=$alldescriptors;
}

sub monitor { 
	print "\n\n$ME:  Waiting for new lines to appear\n" if ! $USING_LOGFILE;
	$firsttime=1;  $timeout=500;
	##print "nfound=$nfound rout=$rout wout=$wout eout=$eout tmout=$timeout \n";
	while (1) {
	##	print "Checking to see if any files have changed.\n";
		# NB none of these select's BLOCK!  I wish I new how to do this.!!!!
	##	$nfound=select($rout=$alldescriptors, $wout=undef, $eout=undef, $timeout);
		$nfound=select($rout=$alldescriptors, $wout=undef, $eout=undef, 0);
	##	$nfound=select($rout=$alldescriptors, $wout=undef, $eout=undef, "");
	##	$nfound=select($rout=$alldescriptors, $wout=undef, $eout=undef, NULL);
	##	print "nfound=$nfound rout=$rout wout=$wout eout=$eout tmout=$timeout \n";
		if ($ori ne $alldescriptors) { printf "CHANGED\n"; }

		#
		# Looping on all handles, ...
		#
		for $file (keys %handles) { if (defined $bn{$file}) {   # better way than this...
			$tmp_fh=$handles{$file};  # why use a tmp_fh??
			while (<$tmp_fh>) { ++ $numlines{$file}; if (! $firsttime) { chop($_);

					$lin = $_;
					#
					# T h e   B I G   M a t c h 
					#
					foreach $M (keys %XTABLE_REGEXP) {
						$MATCH = $lin =~ $XTABLE_REGEXP{$M};
						if ($MATCH) {
							if (defined($XTABLE_REPLACE{$M}) ) { 
								&logit($bn{$file}, ' R', $XTABLE_REPLACE{$M}) if length($XTABLE_REPLACE{$M});
							} else {
								&logit($bn{$file}, ' M', $lin);
							}
							if (defined($XTABLE_ACTION{$M})) { 

								# Hey ! what if we match TWICE.....
								# MATT NB   Must Have MUCH MUCH Better Logging of the results of the action
								# have it parametric whether to give all this logging.....
								# DONT FORCE IT TO BE A KSH...

								&logit($bn{$file}, 'ACTION begin', $XTABLE_ACTION{$M});
								$my_tmp_str = '/usr/bin/ksh ' . $HERE .  '/actions/' . $XTABLE_ACTION{$M} .  "  \" " . $lin .  " \"   >/tmp/AE1.ACTION.OUT  2>/tmp/AE1.ACTION.ERR";
								&logit($bn{$file}, 'ACTION cmmd', $my_tmp_str);

								$RET = system($my_tmp_str);

								# NB # CAVEAT # XTABLE_ACTION[M] may have trailing spacesss
								###########################################################
								&logit($bn{$file}, 'ACTION end  ', $XTABLE_ACTION{$M} . ' returned ' .  $RET);
							}
							# The match has been processed, break out of this for M loop
							# which is searching for the match, and do the next lin
							last;
						}
					}
				if (!$MATCH) { &logit($bn{$file}, 'NM', $lin); }

			} }  # while <FH>, and NOT firsttime..
			if ( defined $SK_LINES{$file} && 
				   $SK_LINES{$file} &&
					($SK_LINES{$file} <= $numlines{$file}) ) { 
				logit($bn{$file}, 'SK', 
					"About to Skulk file $file. It has $numlines{$file}:Skulk level is $SK_LINES{$file}\n"); 
				&skulk($file, $SK_KEEP{$file}, $SK_LEVEL{$file}, $SK_PERM{$file});
				close($handles{$file}) || logit($bn{$file}, "AE1-ERROR", "While skulking, can't close the handle for $file");
		##	   delete($handles{$file}) || logit($bn{$file}, "AE1-ERROR", "While skulking, can't delete the handle for $file");
			$RET=open($handles{$file}, '<' . $file) ||  logit($bn{$file}, "AE1-ERROR", "Failed to reopen $file. Returned $RET"); 
			}
		} }  # for $file  and defined $bn...
		if (defined $SLEEP_TIME && $SLEEP_TIME) { sleep $SLEEP_TIME; } ;
##		&getdate; printf "$DATE %20s [%5d]>No New Lines\n", "M A R K ", 0 ; 
		if ($MY_LENGTH >=$MY_MAX_LENGTH) {
			logit($MY_LOG_FILE, "AE1-ADVISE", 
				"Ready to skulk, I am $MY_LENGTH. Skulk at $MY_MAX_LENGTH");
			skulk_me(); 
		}
		$firsttime=0;
	} # while [ 1 ] ;

} # sub monitor

sub END {
	for $file (keys %handles) { close($handles{$file}) ;  }; # move to cleanup...
}

sub getmylength { $MYLOGFILE=$_[0];
	$MY_LENGTH = 0;
##	$GET_MY_LENGTH     ='/bin/wc -l ' . $MY_LOG_FILE; # How to determine my length
##	$STATUS_STRING = open(GET_MY_LENGTH, $GET_MY_LENGTH . '|') || die "$ME:ERROR, Cant open $GET_MY_LENGTH pipe\n";
##	close(GET_MY_LENGTH);
	$MY_LENGTH=`wc -l $MYLOGFILE`; 
	$MY_LENGTH =~m/\s*(\n)+\s+.*/; $MY_LENGTH=$1;
}

$USING_LOGFILE=$FALSE; 
sub use_LOGFILE { $MYLOGFILE=$_[0];
	open(MYLOGFILE_FH, ">>$MYLOGFILE") || die "$ME:ERROR, Cant open collated file $MYLOGFILE.\n";
	$USING_LOGFILE=$TRUE; 
##	autoflush MYLOGFILE_FH; # cant find..
	select MYLOGFILE_FH; $|=1; select STDOUT;
	&getmylength($MYLOGFILE);
}


sub logit {  local($LOGBASE, $type, $mssg) = @_;
	&getdate;  $LOGSTR="$DATE ($HOST) -";
	if (defined($USING_LOGFILE) && ($USING_LOGFILE) ) { 
		printf MYLOGFILE_FH "%s [%s] [%s] %s\n", $LOGSTR, $type, $LOGBASE, $mssg;
		$MY_LENGTH++;
		#
		# MSH Use perl's logger facility *NOT* this stupid call to system to sh to /bin/logger to...
		#
		#  WHILE TESTING  D O   N O T   S Y S L O G . . .. . .
##		system('logger -t ae1 -p local7.info  [' . $type . '] [' . $LOGBASE .  "] '" . $mssg . "' >/dev/null 2>&1");
	}
	else { # Just using STDOUT
##		printf "$DATE %20s [%5d]>$_", $bn{$file}, $numlines{$file} ; 
		printf STDOUT "%s [%s] [%s] %s\n", $LOGSTR, $type, $LOGBASE, $mssg;
	}
}


$BARLINE="----------------------------------------";
sub skulk { local($file, $keeplines, $pushlevel, $permanent) = @_;
##	print STDOUT "fl $file, line $keeplines level $pushlevel perm $permanent \n";
    $PREV = '.ae1.prev.'; $PERM = '.ae1.perm.'; $TEMPORARY = '.ae1.temp.'; 
		$QUIETLY = ' 2>/dev/null';
    ## MUST have a temporary . need to do a tail and a head successively
    ## look out for changing ownership and modes here ! ! ! !

    `# !! START OF Little sh script to do the part of the skulk
##		set -x
		# this is necessary to keep ownership/modes
		/bin/cp -p $file  ${file}${TEMPORARY};              # this may blow the fs...
    if [ "0$keeplines" -ne 0 ] ; then
			/bin/cp /dev/null $file;
	    echo "$BARLINE $DATE Skulked by    a e 1   retaining last $keeplines lines. $BARLINE " >> $file;

			/bin/tail -$keeplines ${file}${TEMPORARY} >>$file;
	    echo "$BARLINE $DATE Skulked by    a e 1   end of $keeplines retained lines. $BARLINE " >> $file;
    else   #dont keep any of the old lines
	    echo "$BARLINE $DATE Skulked by    a e 1   NOT RETAINING LINES $BARLINE" > $file;
    fi 
		# !! END OF Litlle sh script to do part of the skulk`;

    if ($pushlevel) {
			for ($level = $pushlevel; ($level - 1); $level--) {
				$doline="/bin/mv $file$PREV" . ($level - 1) . "  ${file}${PREV}${level} ${QUIETLY}";
				`$doline`;
		} }

	# NEXTSTEP this is mearly to retain ownership/modes. should use an economical method
	`/bin/cp -p   $file$TEMPORARY     $file${PREV}1`;
	$LEN=`/bin/wc -l ${file}${TEMPORARY}`; $LEN =~m/\s*(\d+)\s+.*/; $LEN="$1";

	## To avoid the duplication of lines across the push levels q/? is it worth it?
##	system('head -' . ($LEN - $keeplines) . ' ' . $file . $TEMPORARY . ' > ' .  $file . $PREV . '1');
	$HEAD_CMMD="head -" . ($LEN - $keeplines) . " ${file}${TEMPORARY} > ${file}${PREV}1";
##	print "LEN is $LEN; HEAD CMMD is $HEAD_CMMD\n";
	`#
##	set -x
	$HEAD_CMMD`;

	$PERMANENT_STR="FALSE";
	if ($permanent) {
		$PERMANENT_STR="TRUE";
		# An incremental number would be good here.
		$basename = $file; $basename =~ s,.*/,,;      # MyName from filename.
##		$basename=$bn{$file};
		`#
##		set -x
		/bin/cp -p ${file}${TEMPORARY}    ${PERMANENT_DIR}/${basename}${PERM}${SHORT_DATE};
		$COMPRESS_CMMD                    ${PERMANENT_DIR}/${basename}${PERM}${SHORT_DATE};
		#`;

	}
	`#
##	set -x; 
	/bin/rm  ${file}${TEMPORARY}`;
	&logit($bn{$file}, $ME_SHORT, "Skulked.  Kept $keeplines. pushlevel=$pushlevel. perm=$PERMANENT_STR");
	# MUST NOW RESET $file ! !  ! ! ! ! !  !
	$numlines{$file}=2+$keeplines; 

}

sub skulk_me {
	# skulk the ae1 log file 
	&logit($MY_LOG_FILE, $ME_SHORT, '================================================================================');
	&logit($MY_LOG_FILE, $ME_SHORT, '!!!   T H I S    F I L E    I S   A B O U T   T O   B E     S K U L K E D !!  ');
	&logit($MY_LOG_FILE, $ME_SHORT, '!!!   R E S T A R T    Y O U R    a e 1  (c o n s)   s e s s i o n !!  ');
	&logit($MY_LOG_FILE, $ME_SHORT, '================================================================================');
	##	system("sleep 10")
	&skulk($MY_LOG_FILE, 200, 3, 1);
	close(MY_LOG_FILE) || logit("AE1", "ERROR", "While skulking, can't close the handle for $MY_LOG_FILE");
	#
	# gotta reopen the MY_LOG_FILE here....
	#
	&use_LOGFILE($MY_LOG_FILE); 
	#
	&logit($MY_LOG_FILE, $ME_SHORT, ' + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +');
	&logit($MY_LOG_FILE, $ME_SHORT, '!!!   A L L    a e 1 c o n s    O K    n o w    !!  ');
	&logit($MY_LOG_FILE, $ME_SHORT, ' + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + + +');

	# if ae1's own file, then 
	# send signal to all ae1cons  accounts for them to re-read the file

	open(AE1_PIDS, "$GET_AE1CONS_PIDS |") || die "$ME:ERROR, Cant open $file for piping\n";

##	while (<AE1_PIDS>) {
##		$NUM_ON_LINE = (@pids = split(' ', $_));
##		for ($p = 0; $p <= $NUM_ON_LINE; $p++) {
##			if ($pids[$p] && $pids[$p] =~ /\s*[0-9]+\s*/) {
##				&logit($MY_LOG_FILE, $ME_SHORT, 'Signalling ae1cons PID ' . $pids[$p] . ' to hangup');
##				kill -1, $pids[$p]; 
##			}
##		}
##	}
	while (<AE1_PIDS>) { foreach (split) { if (! /PID/) {
		&logit($MY_LOG_FILE, $ME_SHORT, "Signalling ae1cons PID $_ to hangup");
		kill -1, $_; 
	} } }
	close(AE1_PIDS);
	&getmylength($MY_LOG_FILE);
}

sub tailf() {
	if (defined $ENV{"DISPLAY"}) {
		$DISP=$ENV{"DISPLAY"}; 
		print "Opening a display window on disply $DISP\n";
		exec "/bin/tail -f $_[0]";
	} else {
		exec "/bin/tail -f $_[0]";
	}
}


# A n n o u n c e
##################
print "$ME $VER Commencing.\n";

# P r o c e s s   A r g s 
#########################
if (!@ARGV) {
	&usage; exit 1;
} else {
	local @args_file_list=();
	while ($ARGV[0]) { $param=shift @ARGV;
		   if ($param eq '-h') { &usage; exit 0; }
		elsif ($param eq '-s') { &status; }
		elsif ($param eq '-t') { $TRACE_STARTUP=1; }
		elsif ($param eq '--t'){ $TRACE_STARTUP=0; }
		elsif ($param eq '-l') { &process_ae1_log_files(shift @ARGV); }
		elsif ($param eq '-L') { &process_ae1_log_files($LOGFILES); }
		elsif ($param eq '-x') { &process_ae1_xref_table(shift @ARGV); }
		elsif ($param eq '-X') { &process_ae1_xref_table($XREF); }
		elsif ($param eq '-c') { &use_LOGFILE(shift @ARGV); }
		elsif ($param eq '-C') { &use_LOGFILE($MY_LOG_FILE); }
		elsif ($param eq '-m') { &tailf(shift @ARGV); }
		elsif ($param eq '-M') { &tailf($MY_LOG_FILE); }
		elsif ($param eq '-skulk') { &skulk(@ARGV); exit}
		else { #$param NOT EQUAL to std. flag
			if ($param =~ m/^-.+/) {
				print "$ME: Unknown Parameter - $param\n"; exit 2;  
			} else { push(@args_file_list, $param); }
		}
	}
	&introduce_files(@args_file_list) if (@args_file_list) ;
}

# D o  I t
##########
&monitor;
print "$ME $VER Completed.\n";


# C l e a n u p  
###############
# This keeps things quiet when using the -w flag.  Awful I know ....
$JUNK="";

$NOTTHERE=$JUNK;
$GET_DATE_CMMD=$JUNK;  # don't use this in perl..
$TRACE_LEVEL=$JUNK;
$SCCS_VER=$JUNK; 
$LOG=$JUNK; 
$MAX_CHANGE_IN_LOG=$JUNK;
$timeout=$JUNK; 
$nfound=$JUNK; 
$DONT_LOG=$JUNK;
$WHOAMI=$JUNK; 

$wout=$JUNK; $mday=$JUNK; $year=$JUNK; $wday=$JUNK; $yday=$JUNK; 
##$asci_mon=$JUNK; $asci_dow=$JUNK; 
$isdst=$JUNK; $mon=$JUNK; $eout=$JUNK; $rout=$JUNK; 

##$TMPFILE_IN=$JUNK; 
##$TMPFILE_OUT=$JUNK; 
##$TMPFILE_ERR=$JUNK; 

##$RCS_VER=$JUNK; 
##$RELEASE=$JUNK; 
##
##$PERMANENT_DIR=$JUNK;
##$SLEEP_TIME=$JUNK;
##$GET_MY_LENGTH=$JUNK;
##$TRUE=$JUNK;
##$HOST=$JUNK;
##$XREF=$JUNK;
##$FALSE=$JUNK;
##$GET_AE1CONS_PIDS=$JUNK;
##$MY_MAX_LENGTH=$JUNK;
##$ME_SHORT=$JUNK;
