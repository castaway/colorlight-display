use local::lib '/home/pi/perl5/','/home/pi/hub75/colorlight-display/local/';
use lib 'lib';
use Colorlight::Display;

my $cd = Colorlight::Display->new(
    src_mac => "22:22:33:44:55:66",
    dst_mac => "11:22:33:44:55:66",
    dev => "eth0");
$cd->detect();
