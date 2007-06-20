#
# $Id: squidguard_conf.pm,v 2.7 2007/01/27 17:30:48 pv Exp $
#

package squidguard_conf;
use strict;
use vars qw(@ISA);
use subs qw(exit);
use Config::IniFiles;
use locale;

# You can get some additional Messages in STDERR (the apache error-logfile)
# if you set $DEBUG to 1.
my $DEBUG=0; # 0=off; 1=on

# We have to set some "hardcoded variables" for our configuration files:
my $blacklist_server_file = "/etc/squid/blacklist_servers";
my $squidguard_conf       = "/etc/squid/squidguard.conf";

if ($DEBUG){ use Data::Dumper; }


sub ReadSquidGuardConf{
  my $sg_config = shift;
  open(CONF, $sg_config);
    my @c=<CONF>;
  close(CONF);
  my @config=();

  for (my $i=0; $i < @c ; $i++) {
    next if (!$c[$i] );
#|| ($c[$i] =~ /^#/));
    if ($c[$i] =~ /^dbhome\s+(\S+)/) {
      # find dbhome
      my %section;
         $section{'sectype'}='dbhome';
         $section{'dbhome'}=$1;
         $section{'line'}=$i;
      push(@config, \%section);

    } 
     elsif ($c[$i] =~ /^logdir\s+(\S+)/) 
    {
      # find logdir
      my %section;
         $section{'sectype'}='logdir';
         $section{'logdir'}=$1;
         $section{'line'}=$i;
     push(@config, \%section);
    } 
# elsif ($c[$i] =~ /^\#\s+(dest|destination)\s+([-_.a-zA-Z0-9]+)(\s+(within|outside)\s+([-_.a-zA-Z0-9]+))?\s+\{\s*$/)
	elsif( $c[$i] =~ /^\#\s*(dest|destination)\s+([-_.a-zA-Z0-9]+)(\s+(within|outside)\s+([-_.a-zA-Z0-9]+))?\s+\{\s*$/)
	{
	 # destination is disabled
	 my %section;
        $section{'sectype'}='disabled_dest';
        $section{'secname'}=$2;
        $section{'line'}=$i;
	 while(($i <= scalar(@c)) && ($c[$i] !~ /^\#\s*\}/))
	 {
	  while ($c[$i] !~ /\}$/) {
			if ($c[$i] =~ /^\#\s+domainlist\s+(\S+)/)
			{
				$section{'disabled_domainlist'}=$1;
				$section{'disabled_domainlist_line'} = $i;
			}
			elsif ($c[$i] =~ /\#\s+urllist\s+(\S+)/)
			{
				$section{'disabled_urllist'}=$1;
				$section{'disabled_urllist_line'} = $i;
			}
			elsif ($c[$i] =~ /\#\s+expressionlist\s+(\S+)/)
			{
			  $section{'disabled_exprlist'}=$1;
			  $section{'disabled_exprlist_line'} = $i;
			}
			elsif ($c[$i] =~ /\#\s+log\s+(\S+)/)
			{
			  $section{'disabled_log'}=$1;
			  $section{'disabled_log_line'} = $i;
			}
	   $i++;
	  }
	  push(@config, \%section);
	 } # end while
	} # end if disabled_dest
     elsif ($c[$i] =~ /^(dest|destination)\s+([-_.a-zA-Z0-9]+)(\s+(within|outside)\s+([-_.a-zA-Z0-9]+))?\s+\{\s*$/) 
	{
      # find destination group
      my %section;
         $section{'sectype'}='dest';
         $section{'secname'}=$2;
         $section{'line'}=$i;
      while(($i <= scalar(@c)) && ($c[$i] !~ /^\s*\}/)) 
	  {
        while ($c[$i] !~ /\}/) {
	        if ($c[$i] =~ /^\s+domainlist\s+(\S+)/) 
			{
        	  $section{'domainlist'}=$1;
	          $section{'domainlist_line'} = $i;
    	    } 
             elsif ($c[$i] =~ /^\s+urllist\s+(\S+)/) 
			{
	          $section{'urllist'}=$1;
    	      $section{'urllist_line'} = $i;
        	} 
             elsif ($c[$i] =~ /^\s+expressionlist\s+(\S+)/) 
			{
    	      $section{'exprlist'}=$1;
	       	  $section{'exprlist_line'} = $i;
    	    }
			 elsif ($c[$i] =~ /^\s+log\s+(\S+)/)
            {
              $section{'log'}=$1;
              $section{'log_line'} = $i;
            }
         $i++;
        }
       push(@config, \%section);
      } # end while
    } # endif destgroup
 } # endfor 
 print STDERR "ReadSquidGuardConf: \n".Data::Dumper->Dump([@config]) if ($DEBUG);
 return wantarray ? @config : \@config;
} 



sub ReadBlacklistServers{
    my $this      = shift;
    my %dests;
    my @dests;
	my $i         = 1;
    my $ini       = new Config::IniFiles( -file => "$blacklist_server_file",
                                          -allowcontinue =>1);
    # usefull data? if not, display an error message
    if( ! $ini )
    {
        exit 1;
    }

  foreach my $section ( $ini->Sections()) 
  {
    my $serverurl = $ini->val($section, 'url');
        foreach my $line ($ini->val($section,'dests'))
		{
            my ($external,$local)=split /=>/,$line,2;
            my %section;
            $section{'sectype'}='bl_dest';
            $section{'local'}=$local;
            $section{'extern'}=$external;
            $section{'number'}=$i;
            push(@dests, \%section);
			$i++;
        }
        if ($DEBUG)
		{
            print STDERR "My Section: ".$section."\n";
            print STDERR "\nDestinations:\n".Data::Dumper->Dump([@dests]);
        }
  }
 return $ini;
}


sub writeBlacklistServer{
    use File::Temp qw(tempfile);
    my $this           = shift;
    my $edit           = shift;
    my $servername     = shift;
    my $old_servername = shift;
    my $serverurl      = shift;
    my $serveractive   = shift || 'no';
    my $serverdests    = shift || '';
    my $filename       = $blacklist_server_file;
    my $ini       = new Config::IniFiles( -file => '/etc/squid/blacklist_servers',
                                          -allowcontinue =>1 );
    # usefull data? if not, display error message
    if( ! $ini )
	{
        exit 1;
    }
    if ( ($serveractive eq '1') || ($serveractive eq 'yes')) 
	{
        $serveractive = 'yes';
    } 
     else 
	{
        $serveractive = 'no';
    }
    if ($DEBUG) 
	{
        print STDERR "\n\nHere is writeBlacklistServer...\n";
        print STDERR "Edit: $edit\n";
        print STDERR "Servername: $servername\n";
        print STDERR "Serverurl : $serverurl\n";
        print STDERR "Serverdests: $serverdests\n";
        print STDERR "Active    : $serveractive\n";
    }
    my $err='';
    # add a new entry or edit an existing one?
    if ( $edit eq "new") 
	{
        $ini->AddSection($servername);
        $err  .= $ini->newval($servername, 'url', $serverurl);
        $err  .= $ini->newval($servername, 'dests', $serverdests);
        $err  .= $ini->newval($servername, 'active', $serveractive);
    } 
     elsif ( $edit eq "delete") 
	{
        $ini->DeleteSection($servername);
        $err = 'delete';
    } 
     else 
	{
        if ($old_servername ne $servername) 
		{
            $ini->AddSection($servername);
            $ini->DeleteSection($old_servername);
            $err  .= $ini->newval($servername, 'url', $serverurl);
            $err  .= $ini->newval($servername, 'dests', $serverdests);
            $err  .= $ini->newval($servername, 'active', $serveractive);
        } 
         else 
		{
            $err  .= $ini->setval($servername, 'url', $serverurl);
            $err  .= $ini->setval($servername, 'dests', $serverdests);
            $err  .= $ini->setval($servername, 'active', $serveractive);
        }
    }
    # define error-message
    if ( $err eq '111') 
	{
        $err = "successful";
    } 
     elsif ( $edit eq 'delete' ) 
	{
        $err = "successful";
    } 
     else 
	{
        $err = "failed";
    }
    # save new config to a temporary file
    my ($fh, $file) = tempfile(DIR => "/tmp/");
    if(! $ini->WriteConfig( $file ))
	{
        $err= "bl_unable_to_save";
        exit 1;
    }
    close $fh;
    # write contents of the tempfile to $blacklist_servers
    my $saved .= "save_bl_server :";
    if( ! open $fh, $file)
	{
        $err="bl_unable_to_save";
        exit 1;
    }
    my @file = <$fh>;
    chomp(@file);
## FIXME: do some magic to avoid use of suad here
##    my $msg = $session->save_read2session($filename, $filename);
##    if( $msg->code() ne "OK" ) {
##        if( $msg->code() eq "MD5SUM" ) 
##		{
##            $err = "<font color=\"green\">".$message->{'successful'}."</font>";
##            exit;
##        } else 
##		{
##            $err = "<font color=\"red\">".$message->{'failed'}."</font>";
##            exit;
##        }
##    }
##    my $ret = $session->suad_save(\@file, $filename);
##    if(  $ret->code() ne "OK" ) 
##	{
##        $err = "<font color=\"red\">".$message->{'failed'}."</font>";
##        exit;
##    }
    unlink($file);
    close $fh;
    my $status = "";
    $saved .= "";
## display message
    exit;
}


sub recompileBlacklist{
    my $this       = shift;
    my $file       = shift || "all";
    my $ERRORS     = '';
    my @sgconfig   = &ReadSquidGuardConf("$squidguard_conf");
    my $sec        = &find_section( 'config'  => \@sgconfig,
                                    'sectype' => 'dbhome' );
    my $dbpath     = $sec->{'dbhome'};
##	my $ret        = $session->suad_stdout_exec("chown -R squid.nogroup $dbpath");
##	$ret           = $session->suad_stdout_exec("find $dbpath -type f -exec chmod 640 {} \;");
##	$ret           = $session->suad_stdout_exec("find $dbpath -type d -exec chmod 750 {} \;");
##  $ret           = $session->suad_stdout_exec("/usr/sbin/squidGuard -c $squidguard_conf -C $file");
##	$ret           = $session->suad_stdout_exec("chown -R squid.nogroup $dbpath");
    # display message
##    if ($ret->code() =~/^OK/) 
##	{ $ERRORS .= "<tr><td>".$message->{'recompiling'}." $file</td><td>".$message->{'successful'}."</td></tr>\n"; } 
##     else 
##	{ $ERRORS .= "<tr><td>".$message->{'recompiling'}." $file</td><td>".$message->{'failed'}."<br>$2</td></tr>\n"; }
 return $ERRORS;
}



sub UpdateBlacklist{
    my $this        = shift;
    my $bl_serv_ref = shift;
    my $servers     = $this->ReadBlacklistServers();
    my ($ERROR,$urls);
    my @bl_serv;
    # check for other processes
    if (-f "/var/run/get_blacklist.pid") 
	{
        print STDERR "another_process_is_running";
        exit 1;
    }
    # give the user a message
    # first probe if we should update from all servers
    if ( ! defined($bl_serv_ref) || $bl_serv_ref eq '') 
	{
            print STDERR "\nHere is UpdateBlacklist : I've to update ALL active servers!\n" if ($DEBUG);
            foreach my $section ( $servers->Sections()) { push @bl_serv,$section; }
    } 
     else
    {
		foreach my $l (@$bl_serv_ref)
		{
			push @bl_serv,$l;
		}

	}

    # now do the work...
    foreach my $server (@bl_serv) 
	{
		$urls  .= $servers->val($server, 'url')." ";
    }

	# fork in the background 
	my $kind = fork();
	if ($kind)
	{ return 0; }
	 else 
	{
##	    my $ret = $session->suad_stdout_exec("/usr/sbin/get_blacklist $urls &");
		return;
	}
# return 0; #$ret;
}


sub saveDomains{
	use File::Basename;
	my $this      = shift;
    my $file      = shift;
    my $content   = shift;
    my $ERRORS    = '';
    my (@domains,@urls);
    my $tp;
    # get the language-specific messages
	my @temp = split "\n",$content;
    foreach my $l ( @temp )
	  {
       $l =~ s/\r//mg;
       $l =~ s/\n\s+\n/\n/mg;
       $l =~ s/\n\n/\n/mg;   # trim double endlines 
	   $l =~ s/^\s+//;       # trim whitespaces from the start
	   $l =~ s/\s+$//;       # trim whitespaces from the end
       chomp $l;             # not really necessary - only security ;-)
	   next if ( $l eq '' ); # skip empty lines
       if ( $l =~ /:/ ){ 	 # remove protocoll information
		$l = (split /:\/\//,$l)[1]; 
	   }
	   if ( $l =~ /\// ) { # => it's an url
		push @urls, $l;
	   } else { # => it's a domain
		push @domains, $l;
	   }
    }
    # first do some checks to avoid errors 
##	open()
##    my $ret = $session->suad_read($file);
##    if(!($ret->code() =~ /^OK/)) 
#	{ # something is bad - perhaps the file or directory doesn't exist?
        # check the directory:
        my @paths=split(/\//,$file);
        pop @paths;
        $tp=$paths[0];
        for (my $i=1; $i<@paths; $i++)
		{
             if( ! opendir(DIR, "$tp/$paths[$i]") ) 
			 {
#                $ret = $session->suad_mkdir("$tp/$paths[$i]",775);
#                $ret = $session->suad_chown("$tp/$paths[$i]", 'squid', 'nogroup');
print STDERR "$tp/$paths[$i] do not exist!\n";
exit 1;
             }
            closedir(DIR);
            $tp .= "/".$paths[$i];
        } # endfor
#    } # endif
	$tp=dirname($file);
	# save files
	# domains
	sort @domains;
##   $ret    = $session->suad_save(\@domains, $file);
##   $ret    = $session->suad_chown($file, 'squid', 'nogroup');
##   $ret    = $session->suad_chmod($file, '750');
    if ( 1 ) 
	{ $ERRORS .= "saving $file successful\n"; } 
     else 
	{ $ERRORS .= "saving $file failed\n"; }
	# urls
	sort @urls;
#    $ret    = $session->suad_save(\@urls, "$tp/urls");
#    $ret    = $session->suad_chown("$tp/urls", 'squid', 'nogroup');
#    $ret    = $session->suad_chmod("$tp/urls", '750');
    if ( 1 ) 
	{ $ERRORS .= "saving $tp/urls successful\n"; }
     else 
	{ $ERRORS .= "saving $tp/urls failed\n"; }
 return $ERRORS;
}


sub ConfigBlacklist{
    my $this            = shift;
    my $q               = $this->{'cgi'};
    my $save_blserver   = $q->param('new_serversave');
    my $new_servername  = $q->param('new_servername');
    my $old_servername  = $q->param('old_servername');
    my $new_active      = lc($q->param('serveractive'));
    my $new_serverurl   = $q->param('new_serverurl');
    my $new_dests       = $q->param('new_dests');
    my $bl_add          = $q->param('bl_add');
    my $bl_delete       = $q->param('bl_delete');
    my $edit            = $q->param('edit');
    my @bl_servers      = $q->param('bl_servers');
    my $bl_update       = $q->param('bl_update');
    my $bl_config       = $q->param('bl_config');
	my $bl_reload_list  = $q->param('bl_reload_list');
    my $conf_server     = $bl_servers[0];
    my $editserver      = '';
    my @blacklist_server= ();
	my @localdests      =($message->{'ignore_list'});
    my %dests;

    # Make an Blacklist update from the given servers
    if (defined $bl_update && $bl_update ne '' && defined @bl_servers) 
     { $this->UpdateBlacklist(\@bl_servers); }
    
	# Get Blacklist-Servers from file
    my $ini = new Config::IniFiles( -file => "$blacklist_server_file",
                                    -allowcontinue =>1 );
    # usefull data? if not, display an error message
    if( ! $ini )
	{
        $this->display_error($message->{'bl_unable_to_open'},
               $confParam->{cgi_path}."/squidguard_conf.pl?sessionID=$sessionID\&tab=$tab\&stab=$stab");
        exit;
    }
  	foreach my $section ( $ini->Sections()) 
	{
		next if ("$section" eq "global");
    	push @blacklist_server, $section;
	}
	
	# Get domainlist from SquidGuards configuration
    my @sgconfig = &ReadSquidGuardConf("$squidguard_conf");
	foreach my $sec (@sgconfig)
	{
		if ( ($sec->{'sectype'} eq "dest") && (($sec->{'secname'} ne 'bad') && ($sec->{'secname'} ne 'good')))
		{ push @localdests,$sec->{'secname'}; }
	} 

    # Save entries?
    if ((defined($save_blserver) && $save_blserver ne '') || (defined($bl_delete) && $bl_delete ne '')) 
	{
        my $ERROR='';
        if ($new_active eq ''){ $new_active='no'; } 
		else { $new_active='yes'; }
        # check required fields
        if ($new_servername eq '') { $ERROR .= '<tr><td>'.$message->{'no_servername'}.'</td></tr>'; }
        if ($new_serverurl eq '') { $ERROR .= '<tr><td>'.$message->{'no_serverurl'}.'</td></tr>'; } 
		elsif ( $new_serverurl !~ /(ftp|http):\/\//i ) { $ERROR .= "<tr><td>".$message->{'no_url'}."</td></tr>"; }
        # Add a new entry?
        if ( defined($edit) && $edit eq 'new') 
		{
            foreach my $server ( $ini->Sections()) 
			{
                if ( $server eq $new_servername ) 
				{ $ERROR .= '<tr><td>'.$message->{'servername_exists'}.$new_servername.'</td></tr>'; }
            }
        } 
        # display errors or save server
        unless (defined($old_servername) && $old_servername ne ''){ $old_servername = ''; }
        if ( $ERROR eq '') 
		{
            # should we delete a server?
            if ($bl_delete ne '') { $edit = 'delete' };
            # Let's do it...
            $this->writeBlacklistServer($edit,$new_servername, $old_servername, $new_serverurl,$new_active,$new_dests);
        } 
         else 
		{
            $this->display_head();
            print $q->start_table({width=>'100%'}).$q->start_Tr().$q->start_td();
            print "<H1>$message->{reload}</H1>";
            print $q->end_td().$q->end_Tr().$q->end_table()."\n";
            print $q->start_table({width=>'100%'})."\n";
            print $ERROR;
            print $q->end_table()."\n";
            $this->display_footer("$confParam->{cgi_path}/squidguard_conf.pl?sessionID=$sessionID\&tab=$tab\&stab=$stab");
            exit 1;
        }
    }

    # configure blacklist server?
    if (( defined($conf_server) && $conf_server ne '' ) || (defined($bl_add) && $bl_add ne '')){
        my ($servername, $old_servername, $serverurl, $serverdests, $dests) = '';
        my (@serverdests);
        my $serveractive = '1';
        if ($bl_add eq '') {
            foreach my $server ( $ini->Sections()) {
				next if ("$server" eq "global");
                if ( $server eq $conf_server ) {
                    $servername     = $conf_server;
                    $old_servername = $conf_server;
                    $serverurl      = $ini->val($server,'url');
                    $serveractive   = $ini->val($server,'active');
                    if (( $serveractive eq 'yes') || ( $serveractive eq 'Yes') || ( $serveractive eq 'YES')) { $serveractive='1';} 
					else { $serveractive='0'; }
                	# read destinations
                    foreach my $value ($ini->val($server,'dests')) 
					{
                        my ($external,$local)=split /=>/,$value,2;
						if ( defined($bl_reload_list) && $bl_reload_list ne '')
						{
							my $ret = $session->suad_stdout_exec("/usr/sbin/get_blacklist -g $serverurl");
							my $result = $ret->code();
							$result =~ s/^OK: 0\s+//mg;
							$result =~ tr/ //s;
							chomp($result);
							@serverdests = split(/ /,$result);
						}
                         else 
						{ push @serverdests, $external; }
                      $dests{$external}=$local;
                    } # end foreach
				} # endif
			} # end foreach
            $editserver .= $q->hidden(-name=>'edit', -value=>'edit');
            $editserver .= $q->hidden(-name=>'old_servername', -value=>$old_servername);
        } # end edit existing server
         else 
        { # get a new server
            $editserver .= $q->hidden(-name=>'edit', -value=>'new');
        }
        # html output
        $editserver .= $q->Tr( $q->td({-align=>"center",-colspan=>3},'<hr noshade size="2">'));
        $editserver .= $q->Tr( $q->td({-align=>"right"}, $message->{bl_server}.":"),
                               $q->td({-align=>"left"},  $q->textfield(-name=>'new_servername',
                                                                       -default=>$servername,
                                                                       -size=>75,
                                                                       -maxlength=>120,
                                                                       -override=>1)));
        $editserver .= $q->Tr( $q->td({-align=>"right"}, $message->{bl_server_url}.":"),
                               $q->td({-align=>"left"},  $q->textfield(-name=>'new_serverurl',
                                                                       -default=>$serverurl,
                                                                       -size=>75,
                                                                       -maxlength=>250,
                                                                       -override=>1)));
         $editserver .= $q->start_Tr();
         $editserver .=   $q->td({-align=>"right"}, $message->{bl_dests}.":");
         $editserver .=   $q->start_td();
         $editserver .=     $q->start_table({-width=>"100%"});
         $editserver .= $q->Tr($q->td({-align=>"left"}, $message->{'ext_list'}."&nbsp;:"),
                               $q->td({-align=>"center"}, "&nbsp;&nbsp;&nbsp;&nbsp;"),
                               $q->td({-align=>"left"}, $message->{'local_list'}."&nbsp;:"));

         foreach my $line (@serverdests)
		 {
			my $default='';
			foreach my $l (@localdests)
            {
				if ($dests{$line} eq $l){ $default = $l; }
			}
    		$editserver .= 		$q->Tr($q->td({align=>"left"}, $line),
                                $q->td({-align=>"center"}, "&nbsp;&nbsp;=>&nbsp;&nbsp;"),
                                $q->td({-align=>"left"}, $q->popup_menu( -name=>"localdests.$line.$default",
																		 -values=>\@localdests,
                                                                         -default=>$default,
                                                                         -labels=>\%dests,
																		 -override=>1)));
         }

         $editserver .=      $q->end_table();
         $editserver .=    $q->end_td();
         $editserver .=  $q->end_Tr();

		 $editserver .= $q->Tr( $q->td("&nbsp;"),$q->td({-align=>"left"},
                        $q->submit(-class=>"button",-name=>'bl_reload_list', -value=>$message->{'bl_reload_list'})));

         $editserver .= $q->Tr( $q->td({-align=>"right"}, $message->{bl_server_active}),
                                $q->td({-align=>"left"}, $q->checkbox( -name=>'serveractive',
                                                                       -checked=>$serveractive,
                                                                       -value=>$serveractive,
                                                                       -label=>'')));
         $editserver .= $q->Tr( $q->td("&nbsp;"),$q->td({-align=>"right"}, 
                                $q->submit(-class=>"button",-name=>'bl_delete', -value=>$message->{'delete'}), 
                                $q->submit(-class=>"button",-name=>'new_serversave', -value=>$message->{'save'})));

         $editserver .= $q->Tr( $q->td({-align=>"center",-colspan=>3},'<hr noshade size="2">'));
    } # end if (edit bl_server or new_bl_server)

    # Let's start the HTML-Output
    my $html= $q->start_table({-class=>'AdminBorder', -cellspacing=>2, -cellpadding=>0, -width=>'100%'});
    $html .=     $q->start_Tr();
    $html .=         $q->start_td();
    $html .=             $q->start_table({-cellspacing=>0, -cellpadding=>3, -width=>'100%'});
    $html .=                 $q->Tr( [ $this->help_th(2, $message->{squidguard_conf},'SQUIDGUARD'),
                    				   $q->td({-class=>'AdminSubHeader',-colspan=>'2'}, $message->{bl_server})
                    				]);

    $html .=         $q->start_multipart_form(-action=>$confParam->{cgi_path}.'/squidguard_conf.pl').
                     $q->hidden(-name=>'sessionID', -value=>"$sessionID").
                     $q->hidden(-name=>'tab', -value=>"$tab").
                     $q->hidden(-name=>'stab', -value=>"$stab");

    # get a view of configured blacklist servers:
    $html .=    $q->start_Tr();
#	$html .= 	 $q->start_td();
#	$html .=	  $q->start_table({-cellspacing=>0, -cellpadding=>3, -width=>'100%'});
#	$html .=	   $q->start_Tr();
	$html .=	  	  $q->td({-align=>'right'}, $message->{active_bl_servers});
	$html .=          $q->td({-align=>'left'}, $q->scrolling_list(  -name=>'bl_servers',
                                                                    -multiple=>'true',
                                                                    -value=>\@blacklist_server,
                                                                    -size=>7 ));
#    $html .=       $q->end_Tr();
#	$html .=      $q->end_table();
#	$html .=     $q->end_td();
#	$html .=	$q->end_Tr();
#	$html .=	$q->end_table();
#	$html .=	$q->end_td();
	$html .= 	$q->end_Tr();

    # insert fields for editing or adding a blacklist server, if exists
	$html .=	$editserver;

    # bottom buttons
    $html .=         $q->Tr( $q->td({-align=>'center', -colspan=>'3'},
							 $q->submit(-class=>"button",-name=>'squidguard',-value=>$message->{back}),
#	$html .=	 $q->start_td({-align=>'left', -colspan=>'3'});
#	$html .=				$q->start_table({-cellspacing=>0, -cellpadding=>3, -width=>'100%'});
#	$html .= 					$q->Tr(   $q->td({-align=>'left'},
                                 $q->submit(-class=>"button",-name=>'bl_update', -value=>$message->{bl_update}),
#    $html .=    				$q->Tr(   $q->td({-align=>'left'},
                                 $q->submit(-class=>"button",-name=>'bl_config', -value=>$message->{bl_config}),
#    $html .=    				$q->Tr(   $q->td({-align=>'left'},
                                 $q->submit(-class=>"button",-name=>'bl_add',    -value=>$message->{bl_add})));
#	$html .=				$q->end_table();
#	$html .=	 $q->end_td();
#    $html .=             $q->end_table();
#    $html .=         $q->end_td();
    $html .=     $q->end_Tr();
    $html .= $q->end_table();
    $html .= $q->end_form();

    $this->SUPER::display($html);

}

sub reload{
    my $this            = shift;
    my @gooddom_content = $q->param('gooddom_content');
    my @baddom_content  = $q->param('baddom_content');
    my @sgconfig = &ReadSquidGuardConf("$squidguard_conf");
    my $sec      = &find_section( 'config'  => \@sgconfig,
                                  'sectype' => 'dbhome' );
    my $dbpath   = $sec->{'dbhome'};
    my $gooddom  = &find_section( 'config'  => \@sgconfig,
                                  'sectype' => 'dest',
                                  'secname' => 'good' );
    my $baddom   = &find_section( 'config'  => \@sgconfig,
                                  'sectype' => 'dest',
                                  'secname' => 'bad' );

    my $ERRORS=$this->saveDomains($dbpath.'/'.$gooddom->{'domainlist'}, 'gooddom_content');
    print $ERRORS;
    $ERRORS=$this->saveDomains($dbpath.'/'.$baddom->{'domainlist'}, 'baddom_content');
    print $ERRORS;

    # recompile squidGuards blacklists
    $ERRORS=$this->recompileBlacklist($dbpath.'/'.$gooddom->{'domainlist'});
    print $ERRORS;
    $ERRORS=$this->recompileBlacklist($dbpath.'/'.$baddom->{'domainlist'});
    print $ERRORS;
    $ERRORS=$this->recompileBlacklist($dbpath.'/'.$gooddom->{'urllist'});
    print $ERRORS;
    $ERRORS=$this->recompileBlacklist($dbpath.'/'.$baddom->{'urllist'});
    print $ERRORS;

    # reload squid
##    my $ret = $session->suad_service_exec('squid', 'reload');
##    $ret->code() =~ /OK:\s(\d+?)\s(.*)/ms;
##    if( $1 != 0 ){
        $ERRORS="reload_squid failed\n";
#    } else {
        $ERRORS="reload_squid successful\n";
#    }
    print $ERRORS;
}


sub find_section {
  my %args=@_;
  my $c;
  foreach $c (@{$args{'config'}}) {
    my $ok=1;
    for (keys %args) {
      next if ($_ eq 'config');
      if ($c->{$_} !~ /^$args{$_}$/) {
        $ok=0;
        last;
      }
    }
    return $c if ($ok);
  }
 return undef;
}

sub check_and_create {
	my $this = shift;
	my $file = shift;
#	my $ret = $session->suad_read($file);
#	if($ret->code() !~ /^OK/) {
		print STDERR "$file not found - creating\n" if ( $DEBUG );
		my @foo = ('');
#		$session->suad_save(\@foo,$file);
#		$session->suad_chmod($file, '750' );
#		$ret = $session->suad_chown($file, 'squid', 'nogroup');
#	}
#	if ( $ret->code() =~ /^OK/) {
#		return 0;
#	} else {
#		return 1;
#	}
}

1;

