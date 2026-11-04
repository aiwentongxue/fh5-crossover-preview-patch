use strict;
use warnings;

my ($original, $alias) = @ARGV;
open my $in, '<:raw', $original or die "$original: $!";
local $/;
my $pe = <$in>;
sub u16 { unpack('v', substr($pe, $_[0], 2)) }
sub u32 { unpack('V', substr($pe, $_[0], 4)) }
die "Invalid DOS header\n" unless substr($pe, 0, 2) eq 'MZ';
my $nt = u32(0x3c);
my $opt = $nt + 24;
die "Expected x64 PE32+\n" unless substr($pe, $nt, 4) eq "PE\0\0" && u16($nt + 4) == 0x8664 && u16($opt) == 0x20b;
my $sections = $opt + u16($nt + 20);
sub offset_for {
    my ($rva) = @_;
    for my $index (0 .. u16($nt + 6) - 1) {
        my $section = $sections + 40 * $index;
        my ($va, $length, $start) = map { u32($section + $_) } (12, 16, 20);
        return $start + $rva - $va if $rva >= $va && $rva - $va < $length;
    }
    die "Invalid export address\n";
}
my $directory = offset_for(u32($opt + 112));
my $name = offset_for(u32($directory + 12));
die "Unexpected export name\n" unless substr($pe, $name, 10) eq "d3d12.dll\0";
substr($pe, $name, 9) = 'apd12.dll';
open my $out, '>:raw', $alias or die "$alias: $!";
print {$out} $pe or die "$alias: $!";
close $out or die "$alias: $!";
