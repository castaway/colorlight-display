package Colorlight::Display;

use v5.30;
no warnings "experimental::signatures";
use feature 'signatures';
use warnings;
use Moo;

use Net::Frame::Layer::ETH;
use Net::Write::Layer2;
use Net::Frame::Simple;
use Net::Frame::Dump::Online;

use Imager;

use Data::Dumper;

use Time::HiRes 'sleep';

'fixme: make these default.';
has 'src_mac', is => 'rw';
has 'dst_mac', is => 'rw';
has 'dev', is => 'rw';
has 'cols', is => 'rw';
has 'rows', is => 'rw';

sub capture($f, $data) {
    my $raw            = $f->{raw};
    my $firstLayerType = $f->{firstLayer};
    my $timestamp      = $f->{timestamp};
    my $layer = Net::Frame::Layer::ETH->new(raw => $raw);

    say $layer->type;
    say $layer->print;
}

sub detect($self) {
    my $eth = Net::Frame::Layer::ETH->new(
	src => $self->src_mac,
	dst => $self->dst_mac,
	type => 0x700,
	);
    $eth->payload(chr(0) x 270);
    $eth->pack();
    say "Payload len " . $eth->getPayloadLength();
    say $eth->dump;
    my $writer = Net::Write::Layer2->new( dev => $self->dev );
    my $dumper = Net::Frame::Dump::Online->new(
	dev => $self->dev,
#	onRecv => \&capture,
	#	onRecvCount => 5
	promisc => 1,
	);
    $dumper->start;

    my $simple = Net::Frame::Simple->new( layers => [ $eth ] );

    $writer->open();
    $simple->send($writer);
    $writer->close();

    my $count = 0;
    while ($count < 5) {
	if (my $f = $dumper->next) {
	    $count++;
	    my $raw            = $f->{raw};
	    my $firstLayerType = $f->{firstLayer};
	    my $timestamp      = $f->{timestamp};
	    my $layer = Net::Frame::Layer::ETH->new(raw => $raw);

	    printf("type: 0x%x\n", $layer->type);
	    say $layer->print;
	}
    }
    print Dumper($dumper->getStats());
    $dumper->stop;
    # until ($dumper->timeout) {
    # 	if (my $recv = $simple->recv($dumper)) {
    # 	    say $recv->print;
    # 	    last;
    # 	}
    # }
}

sub set_brightness($self) {
    my $eth = Net::Frame::Layer::ETH->new(
	src => $self->src_mac,
	dst => $self->dst_mac,
	type => 0xaff,
	);
    $eth->payload(chr(0xff) x 3 . chr(0) x 60);
    $eth->pack();
    say "Payload len " . $eth->getPayloadLength();
    say $eth->dump;
    my $writer = Net::Write::Layer2->new( dev => $self->dev );
    my $simple = Net::Frame::Simple->new( layers => [ $eth ] );

    $writer->open();
    $simple->send($writer);
    $writer->close();
}

sub send_0107($self) {
    my $eth = Net::Frame::Layer::ETH->new(
	src => $self->src_mac,
	dst => $self->dst_mac,
	type => 0x0107,
	);
    $eth->payload(chr(0) x 20 . chr(0xff) . chr(5) . chr(0) . chr(0xff) x 3 . chr(0) x 72);
    $eth->pack();
    say "Payload len " . $eth->getPayloadLength();
    say $eth->dump;
    my $writer = Net::Write::Layer2->new( dev => $self->dev );
    my $simple = Net::Frame::Simple->new( layers => [ $eth ] );

    $writer->open();
    $simple->send($writer);
    $writer->close();
}

sub send_0101($self) {
    return;
    
    my $eth = Net::Frame::Layer::ETH->new(
	src => $self->src_mac,
	dst => $self->dst_mac,
	type => 0x0101,
	);
    $eth->payload(chr(0) x 98);
    $eth->pack();
    say "Payload len " . $eth->getPayloadLength();
    say $eth->dump;
    my $writer = Net::Write::Layer2->new( dev => $self->dev );
    my $simple = Net::Frame::Simple->new( layers => [ $eth ] );

    $writer->open();
    $simple->send($writer);
    $writer->close();
}

sub send_image($self, $image) {
    $self->send_0101;
    $self->set_brightness();
    
    for(my $y = 0; $y < $self->rows; $y++) {
	my $eth = Net::Frame::Layer::ETH->new(
	    src => $self->src_mac,
	    dst => $self->dst_mac,
	    type => 0x5500,
	    );
	my @payload = ($y, 0, 0, $self->cols >> 8, $self->cols & 0xFF, 0x08, 0x88);
	for (my $x = 0; $x < $self->cols; $x++) {
	    # say "$x, $y";
	    my ($pixel) = $image->getpixel(x=>$x, y=>$y);
	    my ($r, $g, $b, $a);
	    if ($pixel) {
		($r, $g, $b, $a) = $pixel->rgba;
	    } else {
		($r, $g, $b, $a) = (0, 0, 0, 1);
	    }
	    if ($image->getchannels() == 1) {
		$g=$r;
		$b=$r;
	    }
	    # our display is bgr instead of rgb.  Annoying, no?
	    $payload[7 + 3*$x + 0] = $b;
	    $payload[7 + 3*$x + 1] = $g;
	    $payload[7 + 3*$x + 2] = $r;
	}
	$eth->payload(join('', map {chr $_} @payload));
	$eth->pack();
	say "Payload len " . $eth->getPayloadLength();
	say $eth->dump;
	my $writer = Net::Write::Layer2->new( dev => $self->dev );
	my $simple = Net::Frame::Simple->new( layers => [ $eth ] );

	$writer->open();
	$simple->send($writer);
	$writer->close();    
    }
    sleep 0.02;
    
    $self->send_0107();
}

sub send_color {
    send_colour(@_);
}

sub send_colour($self, $r, $g, $b) {
    $self->send_0101();
    $self->set_brightness();
    for(my $x = 0; $x < $self->rows; $x++) {
	my $eth = Net::Frame::Layer::ETH->new(
	    src => $self->src_mac,
	    dst => $self->dst_mac,
	    type => 0x5500,
	    );
	my @payload = ($x, 0, 0, $self->cols >> 8, $self->cols & 0xFF, 0x08, 0x88);
	for (my $y = 0; $y < 3*$self->cols; $y+=3) {
	    $payload[7 + $y + 0] = $b;
	    $payload[7 + $y + 1] = $g;
	    $payload[7 + $y + 2] = $r;
	}
	$eth->payload(join('', map {chr $_} @payload));
	$eth->pack();
	say "Payload len " . $eth->getPayloadLength();
	say $eth->dump;
	my $writer = Net::Write::Layer2->new( dev => $self->dev );
	my $simple = Net::Frame::Simple->new( layers => [ $eth ] );

	$writer->open();
	$simple->send($writer);
	$writer->close();    
    }
    sleep 0.02;
    
    $self->send_0107();
}
1;
