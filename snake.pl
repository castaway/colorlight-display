#!/usr/bin/perl

use strict;
use warnings;

use local::lib '/home/pi/perl5/','/home/pi/hub75/colorlight-display/local/';
use Term::ReadKey;
use Imager;
use Imager::Font;
use Getopt::Long;
use IO::Async::Loop;
use IO::Async::Handle;
use IO::Async::Stream;
use IO::Async::Channel;
use IO::Async::Routine;
use IO::Async::Timer::Periodic;
use feature 'say';
use Data::Dumper;
use DateTime;
use List::Util qw/shuffle any/;
use Time::HiRes 'time';
    
use lib 'lib/';
use Colorlight::Display;

my $display = Colorlight::Display->new(
    src_mac => "22:22:33:44:55:66",
    dst_mac => "11:22:33:44:55:66",
    dev => "eth0",
    rows => 32,
    cols => 128);
my $loop = IO::Async::Loop->new();

my $length = 2;
my $snakeY = 6;
my $snakeX = 2;
my $snakeY2 = 6;
my $snakeX2 = 3;
my $dir = 'x+';
my @snake  = ();

my @dots = ();
my $dotcount = 3;

ReadMode 3;
create_snake();
# update_dots();
draw_all([$snakeX, $snakeY, $snakeX2, $snakeY2]);

my $snake_in = IO::Async::Channel->new();
my $snake_out = IO::Async::Channel->new();
my $snake_write = IO::Async::Routine->new(
    channels_in => [$snake_in],
    channels_out => [$snake_out],
    code => sub {
        #say Carp::longmess;
        #say "Called Routine: @_";
        while(1) {
            # say "Routine";
            my $new_snake = $snake_in->recv;
            # say "Routine dir: $dir";
            # my $new_snake = update_snake($dir);
            # say "Routine got ", Dumper($new_snake);
            my $t = time();
            draw_all($new_snake);
            say time - $t;
            $snake_out->send([1]);
        }
    },
    on_finish => sub {
        print "Snake routine aborted early\n";
        $loop->stop;
    },
);

$loop->add(
    IO::Async::Stream->new(
        read_handle => \*STDIN,
        read_len => 1,
        on_read => sub {
            my ($self, $buffref, $eof) = @_;
            while( $$buffref =~ s/^(.)// ) {
                my $input = $1;
            # while( sysread(\*STDIN, $input, 1) ) {
                print "Received input: $input\n";
                if($input eq q{'}) {
                    # turn up
                    $dir = 'y+';
                } elsif($input eq '/') {
                    # turn down
                    $dir = 'y-';
                } elsif($input eq 'z') {
                    # turn down
                    $dir = 'x-';
                } elsif($input eq 'x') {
                    # turn down
                    $dir = 'x+';
                }
                say "Dir: $dir";
                # $snake_in->send($dir);
            }
            return 1;
        }
    ));


$loop->add($snake_write);

$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 0.1,
        on_tick => sub {
            # blocks until done?
            $snake_out->recv->on_done( sub {
                my $draw_done = shift;
                if ($draw_done && $draw_done->[0]) {
                    my $new_snake = update_snake();
                    # say "new snake, mode: ", $snake_in->{mode}, Dumper($new_snake);
                    $snake_in->send($new_snake);
                }
            });
            # update_dots();
            # update_snake();
            # draw_all();
        }
    )->start
);

$loop->add(
    IO::Async::Timer::Periodic->new(
        interval => 5,
        on_tick => sub {
            $dotcount++;
        }
    )->start
);
my $new_snake = update_snake();
$snake_in->send($new_snake);

$loop->run;

# list of x,y snake values
sub create_snake {
    # default snake, 2x6,3x6
    # head is first item!
    @snake = ([$snakeX,$snakeY],[3,6]);

}

sub update_snake {
    # my $dir = shift;
    # 1. remove last item (snake is moving away from it)
    # pop(@snake);

    # 2. add new item to front, in direction snake is going
    if($dir eq 'x+') {
        $snakeX2 = $snakeX + $length;
        $snakeY2 = $snakeY;
        $snakeX++;
        $snakeX = $display->cols-$length if $snakeX > $display->cols-$length;
        say "x+";
    } elsif($dir eq 'x-') {
        $snakeX2 = $snakeX - $length;
        $snakeY2 = $snakeY;
        $snakeX--;
        $snakeX = 0 if $snakeX < 0;
        say "x-";
    } elsif($dir eq 'y+') {
        $snakeY2 = $snakeY - $length;
        $snakeX2 = $snakeX;
        $snakeY--;
        $snakeY = 0 if $snakeY < 0;
        say "y+";
    } elsif($dir eq 'y-') {
        $snakeY2 = $snakeY + $length;
        $snakeX2 = $snakeX;
        $snakeY++;
        $snakeY = $display->rows-$length if $snakeY > $display->rows-$length;
        say "y-";
    }
    say "$snakeX, $snakeY, $snakeX2, $snakeY2";

    return [$snakeX, $snakeY, $snakeX2, $snakeY2];
}

sub update_dots {
    # ensure we have enough dots left
    my @allpossible;
    # surely there's a List::Utils for this?
    for my $x (0 .. $display->cols - 1) {
        for my $y (0 .. $display->rows - 1 ) {
            push @allpossible, [$x,$y];
        }
    }

    # add missing dots
    foreach my $index ($#dots .. $dotcount) {
        my @shuff = shuffle(@allpossible);
        my $newdot = shift(@shuff);
        while (any { $newdot->[0] == $_[0] && $newdot->[1] == $_[1] } @dots ||
               any { $newdot->[0] == $_[0] && $newdot->[1] == $_[1] } @snake ) {
            $newdot = shift(@allpossible);
        }
        push @dots, $newdot;
    }
}

# needs to cope with turning corners!
sub draw_all {
    my ($snake) = shift;
    # say "Draw snake ", Dumper($snake);
    my ($snakeX, $snakeY, $snakeX2, $snakeY2) = @$snake;
    my $image = Imager->new(xsize => $display->cols, ysize => $display->rows, channels => 1);

    $image->line(color => 'white',
                 x1=> $snakeX, x2 => $snakeX2,
                 y1=> $snakeY, y2 => $snakeY2);
    $display->send_image($image);
    # my $packet = $display->imager_to_packet($image);
    # #            say $packet;
    # open my $portfh, '>/dev/ttyUSB0' or die "can't open /dev/ttyUSB0: $!";
    # my $termios = POSIX::Termios->new;
    # $termios->getattr($portfh->fileno);
    # $termios->setispeed(POSIX::B4800());
    # $termios->setospeed(POSIX::B4800());
    # $termios->setattr($portfh->fileno, POSIX::TCSANOW());
    # $portfh->print($packet) or die "Couldn't write packet: $!";
    # close $portfh or die "Couldn't close: $!";
}
    
