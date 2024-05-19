use local::lib '/home/pi/perl5/','/home/pi/hub75/colorlight-display/local/';
use lib 'lib';
use lib '/home/pi/flipdot/flipdot-hanover-display/lib';
use Colorlight::Display;
use FlipDot::Hanover::Display;
use 5.32.0;

my $cd = Colorlight::Display->new(
    src_mac => "22:22:33:44:55:66",
    dst_mac => "11:22:33:44:55:66",
    dev => "eth0",
    rows => 32,
    cols => 128);
my $fhd = FlipDot::Hanover::Display->new(width => $cd->cols, height => $cd->rows);
$cd->send_colour(0,0,0);
# my $image = $fhd->text_to_image('/home/pi/flipdot/flipdot-hanover-display/fonts/ttf - Ac (aspect-corrected)/Ac437_ApricotPortable.ttf', "this is a test.\nnext line");
my $image = Imager->new(xsize => $cd->cols, ysize => $cd->rows, channels => 3);
# $image->read(file => '/home/pi/hub75/rpi-rgb-led-matrix/examples-api-use/runtext.ppm');
$image->read(file => '/home/pi/download.jpeg') or die "Cannot read: ", $image->errstr;
say "width: ", $image->getwidth();
say "height: ", $image->getheight();
#$cd->send_image($image);
