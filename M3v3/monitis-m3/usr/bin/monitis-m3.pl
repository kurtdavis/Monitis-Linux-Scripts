#!/usr/bin/perl -w

use strict;
use Getopt::Long;
use MonitisMonitorManager;
use File::Temp qw/tempfile/;

my $monitis_config_dir = "/etc/m3.d";
defined($ENV{M3_CONFIG_DIR}) and $monitis_config_dir = $ENV{M3_CONFIG_DIR};
require "$monitis_config_dir/M3Templates.pm";

# print usage
sub usage() {
	my $command = $0;
	$command =~ s#^.*/##;
	print "$command [--dry-run] [--once] [--raw RAW_COMMAND] [--test-config] [--help] configuration.xml" . "\n";
	print "Example for raw command: $command --raw \"add_monitor memory RRD_localhost_munin_memory free:free:Bytes:2;active:active:Bytes:2\"" . "\n";
	print "Example for raw command: $command --raw \"update_data memory RRD_localhost_munin_memory free:305594368;active:879394816\"" . "\n";
	exit;
}

# return a skeleton XML with just the API and secret keys
sub get_basic_xml() {
	my ($fh, $filename) = tempfile();

	# create a basic XML
	print $fh "<?xml version=\"1.0\"?>" . "\n";
	print $fh "<config>" . "\n";
	print $fh "<apicredentials apikey=\"%API_KEY%\" secretkey=\"%SECRET_KEY%\"/>" . "\n";
	print $fh "</config>" . "\n";

	close $fh;
	return $filename;
}

sub main() {
	my $dry_run = 0;
	my $once = 0;
	my $help = 0;
	my $test_config = 0;
	my $raw = "";
	GetOptions(
		"d|dry-run" => \$dry_run,
		"o|once" => \$once,
		"r|raw=s" => \$raw,
		"t|test-config" => \$test_config,
		"h|help" => \$help);

	# display help
	if ($help) {
		usage();
	}

	# get the configuration XML
	my $xmlfile = shift @ARGV || "";

	# if test_config is defined - run once and as a dry run - DUH!
	(1 == $test_config) and $dry_run = 1 and $once = 1;

	# if an XML was not specified - use a simple one just with API and
	# secret key
	my $tmp_xml_file_created = "";
	if ($xmlfile eq "") {
		$tmp_xml_file_created = $xmlfile = &get_basic_xml();
	}

	# initialize M3
	my $M3 = MonitisMonitorManager->new(
		configuration_xml => $xmlfile,
		dry_run => $dry_run,
		test_config => $test_config);

	# invoke all the agents
	if ($raw ne "") {
		$M3->handle_raw_command($raw);
	} else {
		if ($once == 1) {
			$M3->invoke_agents();
		} else {
			$M3->invoke_agents_loop();
		}
	}

	# cleanup a tmp xml if it was created
	$tmp_xml_file_created ne "" and unlink $tmp_xml_file_created;
}

&main()
