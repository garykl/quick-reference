#!/usr/bin/env perl6
use v6;


###############################################################################
##
#  TODOs:
#    - think about not using the .qr-file
#    - can I provide functionality with the file?
#      + links can be expired after some time
#      + one can collect some statistics, usage over time


class QuickFolder {
    has Str $.shot;
    has Str $.path;
    has Date $.date is rw;

    method enter() {
        $.date = Date.today;
        say "cd $.path";
    }
}


class QuickDB {

    has QuickFolder @.folders is rw;

    method enter(Str $quick-shot) {
        for @.folders -> $quick-folder {
            if $quick-shot eq $quick-folder.shot {
                $quick-folder.enter;
                return;
            }
        }
        say "no directory related to $quick-shot";
    }

    method add($shot, $path) {
        @.folders.push(QuickFolder.new(
                              shot => $shot,
                              path => $path,
                              date => Date.today));
    }

    method remove($shot) {
        my @fs;
        for @.folders -> $f {
            if $f.shot ne $shot {
                @fs.push($f);
            }
        }
        @.folders = @fs;
    }

    method expire() {
        my Int $expire-threshold = 30; # expire after 30 days
        my @fs;
        for @.folders -> $f {
            if Date.today - $f.date < $expire-threshold {
                @fs.push($f);
            }
        }
        @.folders = @fs;
    }
}


sub line-to-quick-folder($line) {
    my Str @tpl = $line.words;
    my @h = @tpl[2].split('-');
    return QuickFolder.new(shot => @tpl[0],
                           path => @tpl[1],
                           date => Date.new(@h[0], @h[1], @h[2]));
}


sub quick-folder-to-line($quick-folder) {
    my $date = $quick-folder.date;
    my $date-string = $date.year ~ '-' ~ $date.month ~ '-' ~ $date.day;
    return $quick-folder.shot ~ ' ' ~ $quick-folder.path ~ ' ' ~ $date-string;
}


my $data-folder = '/home/gary/.qr/';
my $data-file = $data-folder ~ '.qr';

sub read-data() {

    my $content = '';
    if ($data-file.IO ~~ :e) {
        $content = slurp $data-file;
    } else {
        say "file $data-file doesn't exist, creating it.";
        open($data-file, :w).close;
    }

    return QuickDB.new(folders => $content.lines.map(&line-to-quick-folder));
}

sub write-data(QuickDB $shots) {

    spurt $data-file, (reduce(sub ($a, $b) { return $a ~ "\n" ~ $b; },
                              $shots.folders.map(&quick-folder-to-line)));
}


multi sub MAIN('list') {
    my $shots = read-data;
    for $shots.folders -> $qf {
        say $qf.shot ~ ': ' ~ $qf.path;
    }
}

multi sub MAIN('add', Str $shot) {
    my $shots = read-data;
    my $path = q:x/pwd/.chomp;
    $shots.add($shot, $path);
    write-data $shots;
}

multi sub MAIN('add') {
    my @pwd = q:x/pwd/.chomp.split('/');
    MAIN('add', @pwd.pop);
}

multi sub MAIN('remove', Str $shot) {
    my $shots = read-data;
    $shots.remove($shot);
    write-data $shots;
}

multi sub MAIN('remove') {
    my @pwd = q:x/pwd/.chomp.split('/');
    MAIN('remove', @pwd.pop);
}

multi sub MAIN('cd', Str $shot) {
    my $shots = read-data;
    $shots.enter($shot);
    write-data $shots;
}

multi sub MAIN('links') {
    for dir($data-folder) -> $file {
        if $file ne $data-file {
            unlink($file);
        }
    }
    my $shots = read-data;
    for $shots.folders -> $folder {
        symlink($data-folder ~ $folder.shot, $folder.path);
    }
}
