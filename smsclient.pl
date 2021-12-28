#!/usr/bin/perl
#
#    SMS client for the Multicom MultiConnect rCell 100
#    https://github.com/WillCodeForCats/rcell-smsclient
#
#  Created: November 10, 2016
#  Released: October 9, 2021
#
#    rcell-smsclient: SMS client for the Multicom MultiConnect rCell 100
#    Copyright (C) 2021  Seth Mattinen
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

use strict;
use Getopt::Std;
use REST::Client;
use JSON;
use Fcntl;
use Fcntl qw(:flock);
use LWP::UserAgent;
use IO::Socket::SSL;
use Data::Dumper;

#
# BEGIN Configuration
#

# smshost
# URL of your multitech rcell
my $smshost = "https://rcell";

# rcelluser
# username used to connect to the api to submit messages
my $rcelluser = "rcelluser";

# rcellpassword
# password for 'rcelluser'
my $rcellpassword = "rcellpassword";

# SSL Configuration Options
# The rCell uses a self-signed certificate by default, which will not verify.
# If you change the certificate on the rCell, change the SSL settings here.
# 
my $ua = LWP::UserAgent->new();
$ua->ssl_opts( 
        verify_hostname => 0,
        SSL_verify_mode => SSL_VERIFY_NONE,
        #SSL_ca_file => '',
        #SSL_ca_path => '',
        );
        
#
# END Configuration
#


my %options = ();
getopts("hvp:", \%options);
my $doDebug = ($options{'v'}) ? 1 : 0;

if (defined($options{'h'}) || !defined($options{'p'})) {
    print <<'EOF';

Usage: smsclient.pl -p number

    Takes SMS content on standard input and sends on EOF

    Example:
    echo "test message" | smsclient.pl -p 9995550100

    Required options:
    -p  Phone number to send SMS to

    Other options:
    -v  Verbose mode
    -h  Show this help message

    Developed for the Multicom MultiConnect rCell 100
    https://github.com/WillCodeForCats/rcell-smsclient
EOF
exit;

}

# 10 digit NANP
if ($options{'p'} !~ /^[0-9]{10}$/) {
    die ("Invalid format for phone number.");
}

my $sms = REST::Client->new({ useragent => $ua });
$sms->setHost($smshost);
my $json = JSON->new->allow_nonref;

# get token
my $token = datafile("token");

# check token
$sms->GET("/api/whoami?token=$token");

if ($sms->responseCode() eq '500' ){
    print Dumper($sms) if $doDebug;
    die $sms->responseContent();
}

# anything other than a 200 means we need to log in
if ($sms->responseCode() ne '200' ){
    # log in
    print "Logging in..." if $doDebug;
    $sms->GET("/api/login?username=$rcelluser&password=$rcellpassword");

    # force logout
    if ($sms->responseCode() eq '409') {
        print " forcing logout..." if $doDebug;
        $sms->GET("/api/logout?username=$rcelluser&password=$rcellpassword");
        $sms->GET("/api/login?username=$rcelluser&password=$rcellpassword");
    }
    print " ok!\n" if $doDebug;
    print Dumper($sms) if $doDebug;

    # save token to file
    my $resp = $json->decode( $sms->responseContent() );
    datafile("token", $resp->{result}->{token});
    $token = $resp->{result}->{token};
}

print "Ready!\n" if $doDebug;

# read message from stdin and trim to 160
my $smsMessage = "";
while (<STDIN>) {
    s/\r?\n$/ /;
    $smsMessage .= $_;
}
$smsMessage = substr ($smsMessage, 0, 160);

# assemble for submission
my $smsRcpt = $options{'p'};
my $smsScalar =  {
    recipients => [ "$smsRcpt" ],
    message => "$smsMessage",
};
my $smsJson = $json->encode ($smsScalar);

print "\n$smsJson\n" if $doDebug;

# send the message
my $retries = 0;
do {
    $sms->POST(
            "/api/sms/outbox?token=$token",
            $smsJson,
            {'Content-type' => 'application/json'}
            );
    if ($sms->responseCode() ne '200') {
        $retries++;
        sleep 2;
    }
    else {
        $retries = 6;
    }
} while ($retries < 5);

print $sms->responseContent() if $doDebug;

exit;


sub datafile {
    my ($key, $value) = @_;
    my $instance = "smsclient.dat";
    my $tmpdir = "/tmp";
    my %pref;

    my $PREFS = $tmpdir."/$instance";
    my $SEMAPHORE = $tmpdir."/$instance.lock";

    open(LOCK, ">$SEMAPHORE") or die "Can't open $SEMAPHORE ($!)";
    flock(LOCK, LOCK_EX);

    # get current key-value pairs
    if (-r $PREFS) {
    open(DATA, $PREFS) or die "Can't open $PREFS ($!)";
        while (<DATA>) {
            s/\r?\n$//;
            s/^#//;
            if (/([^=]+)=(.*)/) {
                $pref{substr($1, 0, 512)} = substr($2, 0, 512);
            }
        }
    }

    if ($value) {
        $pref{$key} = $value;       
        
        open(DATA, ">$PREFS") or die "Can't open $PREFS ($!)";
        print DATA "# DO NOT ALTER THIS FILE!\n";
        for (sort keys %pref) {
            print DATA "$_=$pref{$_}\n";
        }
        close DATA;
    }

    close LOCK;

    return $pref{$key};
}

