=pod

jock - first
fred

map (stars only)

turn
	legal moves
	chosen move

	special anouncement?

	buy/sell shares?

	check map is consistent

	check scoreboard is consistent


winner

=cut

package Script;

use strict;
use warnings;
use feature ':5.10'; # loads all features available in perl 5.10 - switch say state
use English '-no_match_vars';
use Carp;
use Data::Dumper;

my @lines;
my $line_num;

#-------------------------------------------------------------------------------

sub read_script {
	my ($fn_in) = @_;

	$line_num = 0;

	open(my $fh, '<', $fn_in) or confess "Failed to open '$fn_in' for reading: $!";
	while (<$fh>) {
		s/^\s+|\s+$//g;					# strip leading and trailing spaces
		push @lines, $_;
	}
	close $fh;
	#print __PACKAGE__." ".__LINE__.": lines = ".Dumper \@lines;

	my @players2;

	while (1) {
		$_ = get_line();
		if (
				$_ eq "traders.exe"
			or 	$_ eq "**********   STAR TRADERS   **********"
			or 	$_ eq "THE CLASSIC GAME WRITTEN BY S.J. SINGER"
			or 	$_ eq "?"
			or 	/^HOW MANY PLAYERS  \(2-4\)  \? \d$/
			or 	$_ eq "DOES ANY PLAYER NEED INSTRUCTIONS  ? n"
		      ) {
			next;
		}
		elsif (/^PLAYER         \d             WHAT IS YOUR NAME  \? (\w+)$/) {
			push @players2, $1;
		}
		else {
			if (@players2) {
				last;
			}
			die "Unexpected line:\n$_\nMissing player. Line $line_num.";
		}
	}

	#print __PACKAGE__." ".__LINE__.": players2 = ".Dumper \@players2;

	die "Unexpected line:\n$_\nMissing first player. Line $line_num." if not /^(\w+) IS THE FIRST PLAYER TO MOVE\.$/;
	my $first_player = $1;

	$_ = get_line();
	die "Unexpected line:\n$_\nMissing [order=player|player...]. Line $line_num." if not /^\[order=(.+)\]$/;
	my @players = split /\|/, $1;
	if ($players[0] ne $first_player) {
		die "'$first_player' should be first in [order=player|player...]";
	}

	my @moves;

	$_ = get_line();

	while (1) {
		my %move;

		if (	$_ eq "?"
			or	$_ eq "WHAT IS YOUR MOVE ? M"
		   ) {
		   	$_ = get_line();
		   	next;
		}

		die "Unexpected line:\n$_\nMissing map. Line $line_num." if not /^MAP OF THE GALAXY$/;
		$move{map_before} = get_map();

		$_ = get_line();
		die "Unexpected line:\n$_\nMissing legal moves heading. Line $line_num." if not /^(\w+), HERE ARE YOUR LEGAL MOVES FOR THIS TURN$/;
		$move{player} = $1;

#-->check it is the expected player

		$_ = get_line();
		die "Unexpected line:\n$_\nMissing legal moves. Line $line_num." if not /^\d [A-L]  \d [A-L]  \d [A-L]  \d [A-L]  \d [A-L]$/;
		my @legals = split /  /;
		map { s/ //g } @legals;
		$move{legal} = \@legals;

		$_ = get_line();
		MOVE:
#		if (/^WHAT IS YOUR MOVE \? M$/) {
#			get_map();
#		}
		if (/^WHAT IS YOUR MOVE \? S$/) {
			$move{scoreboard} = get_scoreboard();
			goto MOVE;
		}
		elsif (/^WHAT IS YOUR MOVE \? (\d[A-L])$/) {
			$move{choice} = $1;
		}
		elsif (/^\[choice=(\d[A-L])\]$/i) {
			$move{choice} = uc $1;
		}
		elsif (/^\[(\d[A-L])\]$/i) {
			$move{choice} = uc $1;
		}
		elsif (/^\[end]$/i) {
			last;
		}
		else {
			die "Unexpected line:\n$_\nMissing choice. Line $line_num.";
		}

		if (not grep {$_ eq $move{choice}} @{$move{legal}}) {
			die "Choice '$move{choice}' is not one of the legal moves:\n@{$move{legal}}\nLine $line_num.";
		}

		$_ = get_line();
		$_ = get_line() if $_ eq "?";
		$_ = get_line() if $_ eq "SPECIAL ANNOUNCEMENT !!!";

		if ($_ eq "A NEW SHIPPING COMPANY HAS BEEN FORMED !") {
			$_ = get_line();
			die "Unexpected line:\n$_\nMissing new company name. Line $line_num." if not /^IT\'S NAME IS  \'(.+)\'$/;
			$move{result}{new_cpy} = substr($1, 0, 1);
			$_ = get_line();
		}

		if (/\'(.+?)\' HAS JUST BEEN MERGED INTO \'(.+?)\'/) {
			my $old_cpy = substr($1, 0, 1);
			my $new_cpy = substr($2, 0, 1);
			#die "$1 - $2";

			my %res = (old_cpy => $old_cpy, new_cpy => $new_cpy);

			$_ = get_line();
			die "Unexpected line:\n$_\nMissing merge note. Line $line_num." if not /^PLEASE NOTE THE FOLLOWING TRANSACTIONS.$/;

			$_ = get_line();
			die "Unexpected line:\n$_\nMissing merge companies. Line $line_num." if not /^OLD STOCK = /;

			$_ = get_line();
			die "Unexpected line:\n$_\nMissing merge titles. Line $line_num." if not /^PLAYER   OLD STOCK   NEW STOCK   TOTAL HOLDINGS     BONUS PAID$/;

			while (1) {
				$_ = get_line();
				last if not /^(\w+)\s+(\w+)\s+(\w+)\s+(\w+)\s+\$ (\w+)$/;
				$res{by_player}{$1} = {old_s => $2, new_s => $3, total => $4, bonus => $5};
#				$res{by_player}{$1} = {old_s => $2 + 0, new_s => $3 + 0, total => $4 + 0, bonus => $5 + 0}; # + 0 so Dumper outputs 1714 rather than '1714' - nope, didn't work
#				$res{by_player}{$1}{old_s} = $2 + 0; # nope, doesn't work
#				$res{by_player}{$1}{new_s} = $3 + 0;
#				$res{by_player}{$1}{total} = $4 + 0;
#				$res{by_player}{$1}{bonus} = $5 + 0;

			}

			die "Unexpected line:\n$_\nMissing merge table. Line $line_num." if not $res{by_player};

			$move{result}{merge} = \%res;
		}

		$_ = get_line() if $_ eq "SPECIAL ANNOUNCEMENT !!!";

		while (/^THE STOCK OF  \'(.+?)\'\s+HAS SPLIT 2 FOR 1 \!$/) {
			my $cpy = $1;
			#die $cpy;
			($cpy) = split /[\s\,]/, ucfirst lc $cpy;
			$move{result}{'split'}{$cpy} = 1; # there may be more than one split
			$_ = get_line();
		}

		while (1) {
			my ($cpy, $qty, $price);

			#print __PACKAGE__." ".__LINE__.": $_\n";

			if (/^YOUR CURRENT CASH= \$ \d+$/) {
				$_ = get_line();
			}

			#BUY HOW MANY SHARES OF 'ALTAIR STARWAYS' AT $ 2825

			if (/^BUY HOW MANY SHARES OF \'(.+)\' AT \$\s*(\d+)/) {
				$cpy = $1;
				$price = $2;
				$_ = get_line();
				die "Unexpected line:\n$_\nMissing new own amount. Line $line_num." if not /^YOU NOW OWN\s+-?\d+ \?\s*(\d+)$/;
				$qty = $1;
			}
			elsif (/^\[BOUGHT (\d+) SHARES? IN (\w+)\]/) {
				($cpy, $qty) = ($2, $1);
			}
			elsif (/^\[B (\w) (-?\d+)\]/i) {
				($cpy, $qty) = (lc($1), $2);
				my @cpys_l = qw(Altair Betelgeuse Capella Denebola Erandini);
				my %cpys_h;
				foreach my $c (@cpys_l) {
					$cpys_h{lc substr($c, 0, 1)} = $c;
				}
				$cpy = $cpys_h{$cpy};
			}
			else {
				last;
			}

			#if ($qty) {
				($cpy) = split /[\s\,]/, ucfirst lc $cpy;
				#push @{$move{buy}}, {$cpy => $qty};
				$move{buy}{$cpy} = $qty;
			#}

			if ($price) {
				$move{price}{$cpy} = $price;
			}

			$_ = get_line();
		}

=pod
               THE GAME IS OVER - HERE ARE THE FINAL STANDINGS
PLAYER   CASH VALUE OF STOCK    CASH ON HAND
                                                 NET WORTH
andrew   $ 374200               $ 138790         $ 512990
alex     $ 286000               $ 109394         $ 395394

PRESS ANY KEY TO RETURN TO MENU
=cut
		if (/^THE GAME IS OVER - HERE ARE THE FINAL STANDINGS$/) {

			$_ = get_line();
			die "Unexpected line:\n$_\nMissing end of game headings. Line $line_num." if not /^PLAYER   CASH VALUE OF STOCK    CASH ON HAND$/;

			$_ = get_line();
			die "Unexpected line:\n$_\nMissing end of game headings. Line $line_num." if not /^NET WORTH$/;

			while (1) {
				$_ = get_line();
				last if not defined $_;
				s/\$\s+/\$/g;
				last if not /^(\w+)\s+\$(\d+)\s+\$(\d+)\s+\$(\d+)$/;
				die "Bad game result:\n$_\nLine $line_num." if $2 + $3 != $4;
				$move{result}{end_game}{$1} = {stock_val => $2, cash => $3};
			}
		}

		if (not $move{buy}) {
			die "Unexpected line:\n$_\nMissing buy amount. Line $line_num.";
		}

		foreach my $k (qw(legal choice)) {
			if (not $move{$k}) {
				die "move is missing $k";
			}
		}

		push @moves, \%move;

		last if $move{result}{end_game};
	}

	#print __PACKAGE__." ".__LINE__.": moves = ".Dumper \@moves;

	#if (@lines) {
	#	die "\nUnhandled lines remain. First unhandled line:\n$lines[0]\n  ";
	#}

	return moves => \@moves, players => \@players;
}

#----------------------------------------------------------------------------

sub get_line {

	my $line = "";
	while ($line eq "" or $line =~ /^\/\//) {
		$line_num++;
		$line = shift @lines;
		last if not defined $line;
	}
	return $line;
}

#----------------------------------------------------------------------------

sub get_map {

	my @m;
	$_ = get_line();
	die "Unexpected line:\n$_\nMissing map star heading. Line $line_num." if $_ ne "*******************";
	$_ = get_line();
	die "Unexpected line:\n$_\nMissing map col headings. Line $line_num." if $_ ne "A  B  C  D  E  F  G  H  I  J  K  L";
	foreach my $row (1..9) {
		$_ = get_line();
		die "Unexpected line:\n$_\nMissing map row. Line $line_num." if not /^$row   (.+)$/;
		push @m, $1;
		$m[-1] =~ s/ //g;
		$m[-1] =~ s/\./ /g;
	}
	#print __PACKAGE__." ".__LINE__.": map = ".Dumper \@m;
	return \@m;
}

#----------------------------------------------------------------------------

sub check_map {
	my ($actual, $script) = @_;

	#print __PACKAGE__." ".__LINE__.": actual = ".Dumper $actual;
	#print __PACKAGE__." ".__LINE__.": script = ".Dumper $script;

	my @actual_rows;
	my @rows_diff;

	for my $row (0 .. @$actual - 1) {
		push @actual_rows, join '', @{$actual->[$row]};
#		if ($actual_rows[$row] ne $script->[$row]) {
#			push @rows_diff, $row;
#		}
	}

	if ("@actual_rows" ne "@$script") {
#	if (@rows_diff) {
#		print "Actual = ".Dumper \@actual_rows;
#		print "Script = ".Dumper $script;
		print "Actual = '@actual_rows'\n";
		print "Script = '@$script'\n";
		confess "Differ at row(s) [@rows_diff]";
	}
}

#----------------------------------------------------------------------------

sub get_scoreboard {
	my ($lines) = @_;

=pod

STOCK                        PRICE PER SHARE     YOUR HOLDINGS
'ALTAIR STARWAYS'             900                 4
'BETELGEUSE,LTD.'             600                 3
'CAPELLA FREIGHT CO.'         300                 -8

=cut

	my %s;
	$_ = get_line();
	if (/^\?$/) {
		$_ = get_line();
	}
	die "Unexpected line:\n$_\nMissing scoreboard heading. Line $line_num." if $_ ne "STOCK                        PRICE PER SHARE     YOUR HOLDINGS";
	while (1) {
		$_ = get_line();
		if (/\'(\w).+?\'\s+(\d+)\s+(-?\d+)$/) {
 			$s{$1} = {price_per_share => $2, qty => $3}
 		}
 		else {
 			last;
 		}
 	}

	#print __PACKAGE__." ".__LINE__.": scoreboard = ".Dumper \%s;
	return \%s;
}

#----------------------------------------------------------------------------
#----------------------------------------------------------------------------
#----------------------------------------------------------------------------

1;

# end
