# 11/06/2013 It's finished (well, as much as I'm going to do).
# ie I haven't added any fancy functionality (eg save/load games, allow variable turns). I'll save that for the C# version.
# traders_script2.txt & traders_script4.txt play back perfectly :) Well done Andrew! Give yourself a pat on the back! 

# d:\code\starlanes\perl\
# cls & p510 StarLanes.pl --script ..\traders_script2.txt

# Test all code exec'd using...
#	set path=C:\Perl5.16.3\bin;%path%
#	perl -MDevel::Cover StarLanes.pl --script ..\traders_script2.txt
#	C:\Perl5.16.3\site\bin\cover.bat

#----------------------------------------------------------------------------
# Star Lanes (also known as Star Traders).
# Perl version by Andrew Vander. Ported from Basic version.
#
# According to http://www.classictw.com/viewtopic.php?f=14&t=11882 ...
# The original door game was written by Chris Sherrick.
# Chris was inspired by a game called Star Traders (aka Star Lanes) that was
# published in a book called The People's Book of Computer Games.
# Modified for 'Altair Basic 4.0' By S J Singer
#----------------------------------------------------------------------------

use strict;
use warnings;
use feature ':5.10'; # loads all features available in perl 5.10 - switch say state
use English '-no_match_vars';
use Carp;
use Getopt::Long;
use List::Util 'shuffle';
use Data::Dumper;
$Data::Dumper::Sortkeys	= 1;
$Data::Dumper::Indent	= 1;

use Script;

#autoflush STDOUT, 1;

$SIG{__WARN__} = sub { print STDERR "@_"; confess "\n"; };

# global variables

my $MARKER_VACANT			= ' ';
my $MARKER_OUTPOST			= '+';
my $MARKER_STAR				= '*';
my $MARKER_A				= 'A';
my $MARKER_B				= 'B';
my $MARKER_C				= 'C';
my $MARKER_D				= 'D';
my $MARKER_E				= 'E';
my $MARKER_GROUP_COMPANY    = '~'; # will not appear on map. used to represent 'all companies'

my $MAX_PLAYERS				= 4;
my $MAX_ROW					= 9;
my $MAX_COL					= 12;
my $MAX_LEGAL_MOVES			= 5;

my $MAX_SHARE_PRICE				= 3000;
my $SHARE_PRICE_STD_INC			= 100; # 100 standard share price increment
my $SHARE_PRICE_START_STAR		= 500;
my $SHARE_PRICE_START_NO_STAR	= 100;

my $NUM_SHARES_FOUNDER	= 5;

my $STARTING_CASH		= 6000;

my %TURNS = (
	's' => 48,	# The classic number of turns
	'm'	=> 60,
	'l'	=> 72,
);

my @COMPANY_NAMES =	qw(Altair Betelgeuse Capella Denebola Eridani);

my %COMPANY_TO_MARKER;
my %MARKER_TO_COMPANY;
for my $cpy (@COMPANY_NAMES) {
	$COMPANY_TO_MARKER{$cpy} = substr($cpy, 0, 1);
	$MARKER_TO_COMPANY{substr($cpy, 0, 1)} = $cpy;
}

my @galaxy; 	# map

my %companies; 	# keyed by company name

my @player_names;
my %players;	# keyed by player name

my $turn_num;
my $max_turns;
my $player_turn;

my $arg_script;
my $script_moves;
my $script_move; # shifted from @$script_moves
my $script_players;
my $script_first_player;

GetOptions(
	"script=s"	=> \$arg_script,
#	"verbose"	=> \$verbose,	  # flag
);

if (defined $arg_script) {
	my %script = Script::read_script($arg_script);
	#print __PACKAGE__." ".__LINE__.": script = ".Dumper \%script;
	$script_players 		= $script{players};
	$script_first_player 	= $script{first_player};
	$script_moves 			= $script{moves};
}

play_game();

#----------------------------------------------------------------------------

sub play_game {

	print "\nWelcome to Starlanes!\n\n";

#	my $choice = prompt_for_choice("Would you like to load a previously saved game?", ["y", "n"]);
#	if ($choice eq "y") {
#		load_game();
#	}
#	else {
		setup_new_game();
#	}
#	setup_fake_game();

	while ($turn_num <= $max_turns) {

		if ($script_moves) {
			$script_move = shift @$script_moves;
			if (not $script_move) {
				confess "Doh! No more moves in script";
			}
			print "-------------------------------------------------------------\n";
			#print __LINE__.": ------------------------------------------------------------- turn_num=$turn_num\n";
			#print __LINE__.": \$script_move = ".Dumper $script_move;
			Script::check_map(\@galaxy, $script_move->{map_before});
		}

		display_score_board();
		#display_map();

		$player_turn = $player_names[($turn_num - 1) % @player_names];

		if ($script_moves) {
			if ($player_turn ne $script_move->{player}) {
				confess "Script error: Actual player '$player_turn' does not match script player '$script_move->{player}'";
			}

			if ($script_move->{scoreboard}) {

				# print __LINE__.": ".Dumper $players{$player_turn}{shares}; # die;
				for my $cpy (sort keys %{$players{$player_turn}{shares}}) {

					next if $players{$player_turn}{shares}{$cpy} == 0;

					my $cpy_letter = substr($cpy, 0, 1);

					if (not $script_move->{scoreboard}{$cpy_letter}) {
						die "Company $cpy_letter missing from script scoreboard";
					}

					if ($players{$player_turn}{shares}{$cpy} != $script_move->{scoreboard}{$cpy_letter}{qty}) {
						die "$player_turn has $players{$player_turn}{shares}{$cpy} shares in $cpy\n".
							"Script says $script_move->{scoreboard}{$cpy_letter}{qty}\n ";
					}

					if ($companies{$cpy}{share_price} != $script_move->{scoreboard}{$cpy_letter}{price_per_share}) {
						die "$cpy share price is $companies{$cpy}{share_price}\n".
							"Script says $script_move->{scoreboard}{$cpy_letter}{price_per_share}\n ";
					}
				}

				#my $num_shares = $players{$player}{shares}{$cpy} || 0;
				#$companies{$cpy}{share_price};
			}
		}

		my ($r, $c) = offer_moves();
		process_move($r, $c);
		buy_shares();
		$turn_num++;
	}

	end_game();

#	my $choice2 = prompt_for_choice("Another game?", ["y", "n"]);
#	if ($choice2 eq "n") {
#		last;
#	}
# 	would have to add reset of @galaxy %companies @player_names %players $turn_num etc to start of loop if I was to allow another game;

} # play_game

#----------------------------------------------------------------------------

sub display_map {
	my ($moves) = @_;

	print "\n                          ---: MAP OF THE GALAXY :---\n\n";
	print "                            a b c d e f g h i j k l\n\n";
	for my $row (0 .. @galaxy - 1) {
		printf "                          %1s ", $row + 1;
		for my $col (0 .. @{$galaxy[$row]} - 1) {

			# if legal moves have been passed, show them

			my $printed = 0;
			if ($moves) {
				#print Dumper $moves; die;
				for my $m (@$moves) {
					if (    $m->{row} == $row
					    and $m->{col} == $col
					   ) {
					   	print "? ";
					   	$printed = 1;
					}
				}
			}

			if (not $printed) {
				given($galaxy[$row][$col]) {
					when ($MARKER_A      ) { print "A "; }
					when ($MARKER_B      ) { print "B "; }
					when ($MARKER_C      ) { print "C "; }
					when ($MARKER_D      ) { print "D "; }
					when ($MARKER_E      ) { print "E "; }
					when ($MARKER_VACANT ) { print ". "; }
					when ($MARKER_OUTPOST) { print "+ "; }
					when ($MARKER_STAR   ) { print "* "; }
				}
			}
		}
		printf "%1s\n", $row + 1;
	}
	print "\n                            a b c d e f g h i j k l\n\n";
}

#----------------------------------------------------------------------------

sub display_score_board {

	print " SCOREBOARD ".($turn_num > $max_turns ? " - FINAL" : "($turn_num/$max_turns)")."\n\n";

	my $line_players = "                    ";
	my $line_div     = "                    ";

	for my $player (@player_names) {
		$line_players .= sprintf "%-12s", $player;
		$line_div 	  .= "----------- ";
	}

	my @lines;
	push @lines, $line_players, $line_div;

	my %players_share_qty_tot;
	my %players_share_qty_val;

	for my $cpy (@COMPANY_NAMES) {
		if ($companies{$cpy}) {
			my $line = sprintf " %-10s @ \$%4s", $cpy, $companies{$cpy}{share_price};
			for my $player (@player_names) {
				my $num_shares = $players{$player}{shares}{$cpy} || 0;
				$line .= sprintf "  %10s", $num_shares;
				$players_share_qty_tot{$player} += $num_shares;
				$players_share_qty_val{$player} += $num_shares * $companies{$cpy}{share_price};
			}
			push @lines, $line;
		}
	}

	my $line_share_tot	= " Total Share Value ";
	my $line_cash 		= " Cash              ";
	my $line_tot 		= " TOTAL             ";

	my $winning_player;
	my $winning_tot;

	for my $player (@player_names) {
		my $tot = ($players_share_qty_val{$player} || 0) + $players{$player}{cash};

		if (not $winning_tot or $tot > $winning_tot) {
			$winning_tot	= $tot;
			$winning_player = $player;
		}

		$line_share_tot	.= sprintf "  %10s", ($players_share_qty_val{$player} || 0);
		$line_cash 		.= sprintf "  %10s", $players{$player}{cash};
		$line_tot 		.= sprintf "  %10s", $tot;
	}

	push @lines, $line_div, $line_share_tot, $line_cash, $line_div, $line_tot;

	print join "\n", @lines, "";

	return $winning_player;
}

#----------------------------------------------------------------------------

sub offer_moves {

	print "\n$player_turn, here are your legal moves:\n  ";

	# generate legal moves

	my @moves;
	my $script_legal = $script_move ? $script_move->{legal} : undef;

	#print __LINE__.": \$script_legal = ".Dumper $script_legal;

#	if ($script_move->{choice} eq '3G') {
#		print "\nBING!\n";
#	}

	for my $move_num (0 .. $MAX_LEGAL_MOVES - 1) {

		my $is_legal = 1;
		my $move_row;
		my $move_col;

		do {
			# generate a random move

			if ($script_moves) {
				if (not @$script_legal) {
					print "\nAt least one legal move in the script was rejected.\n";
					print "Script   = ".Dumper $script_legal;
					print "Accepted = ".Dumper \@moves;
					die;
				}
				my $m = shift @$script_legal;
				my ($r, $c) = split //, $m;
				$move_row = $r - 1;
				$move_col = ord(lc $c) - ord('a');
			}
			else {
				$move_row = int rand $MAX_ROW;
				$move_col = int rand $MAX_COL;
			}

			#printf "\n".__LINE__.": Possible move %s%s\n", $move_row + 1, chr($move_col + ord('a'));

			# check it's currently a vacant space

			if ($galaxy[$move_row][$move_col] ne $MARKER_VACANT) {
				redo;
			}

			# check it's not the same as an existing move

			for my $move_num_prev (0 .. $move_num - 1) {
				if (	$move_row == $moves[$move_num_prev]{row}
					and $move_col == $moves[$move_num_prev]{col}
				   ) {
				   	$is_legal = 0;
				}
			}
			redo if not $is_legal;

			$is_legal = 0; # flip it

			# if there's a company not yet formed, it's legal

			for my $cpy (@COMPANY_NAMES) {
				if (not $companies{$cpy}) {
					$is_legal = 1;
				}
			}

			# if it's next to a company, it's legal
			if (is_next_to_company($move_row, $move_col)) {							# isNextToCompany
				$is_legal = 1;
			}

			# if it's next to an outpost or star, it's legal
			# C code has a '!' (not) at the start of this condition. Is that right? what does the basic code have?
			# 1/05/2013 Well, without the not, traders_script2.txt would fall over. So I've added it.
			if (not is_next_to_outpost_or_star_but_not_company($move_row, $move_col)) { # isNextToOutpostOrStarButNotCompany
				$is_legal = 1;
			}
		}
		while (not $is_legal);

		push @moves, {row => $move_row, col => $move_col};
	}

	foreach my $m (@moves) {
		printf "%s%s, ", $m->{row} + 1, chr($m->{col} + ord('a'));
	}

#	printf( "Save game, Quit.\n" );
	printf( "Quit.\n" );

	my ($r, $c);

	# only useful when not using script
	display_map(\@moves);

	# process keystrokes

	while (1) {
		print "Your choice? ";
		my $choice;
		if ($script_move) {
			$choice = lc $script_move->{choice};
			print "$choice\n";
		}
		else {
			$choice = lc <STDIN>;
		}
		chomp $choice;

		if ($choice eq 's') {
			vSaveGame();
			print "\nGAME SAVED!\n";
			print "\nPress <Enter> to continue... ";
			<STDIN>;
		}
		elsif ($choice eq 'q') {
			print "\nQUITTING!\n";
			exit;
		}
		elsif ($choice =~ /^([1-9])([a-l])$/) {
			for my $m (@moves) {
				if ($1 eq $m->{row} + 1 and $2 eq chr($m->{col} + ord('a'))) {
					$r = $m->{row};
					$c = $m->{col};
				}
			}
			last if defined $r;
		}
	} # while (1)

	return $r, $c;

} # offer_moves

#----------------------------------------------------------------------------
# Example:
# $companies{$cpy}{share_price} += $SHARE_PRICE_STD_INC + markers_count($MARKER_STAR, \@adj_markers) * $SHARE_PRICE_START_STAR;

sub markers_count {
	my ($marker_test, $markers) = @_;

	my $count = 0;

	for my $m (@$markers) {
		if ($marker_test eq $MARKER_GROUP_COMPANY) {
			if ($m ge $MARKER_A and $m le $MARKER_E) {
				$count = 1;
			}
		}
		else {
			if ($m eq $marker_test) {
				$count = 1;
			}
		}
	}

	return $count;

} # markers_count

#----------------------------------------------------------------------------
# Example:
# if (markers_all($MARKER_VACANT, \@adj_markers)) { ... }

sub markers_all {
	my ($marker_test, $markers) = @_;

	my $all = 1;

	for my $m (@$markers) {
		if ($m ne $marker_test) {
			$all = 0;
		}
	}

	return $all;

} # markers_all

#----------------------------------------------------------------------------

sub is_company {
	my ($marker) = @_;

	return $marker ge $MARKER_A and $marker le $MARKER_E;
}

#----------------------------------------------------------------------------

sub is_next_to_company {
	my ($r, $c) = @_;

	my @adj_markers;

	if ($r > 0				) { push @adj_markers, $galaxy[$r - 1][$c] }
	if ($r < $MAX_ROW - 1 	) { push @adj_markers, $galaxy[$r + 1][$c] }
	if ($c > 0				) { push @adj_markers, $galaxy[$r][$c - 1] }
	if ($c < $MAX_COL - 1 	) { push @adj_markers, $galaxy[$r][$c + 1] }

	return markers_count($MARKER_GROUP_COMPANY, \@adj_markers);
}

#----------------------------------------------------------------------------

sub is_next_to_outpost_or_star_but_not_company {
	my ($r, $c) = @_;

	my @adj_markers;

	if ($r > 0)				{ push @adj_markers, $galaxy[$r - 1][$c] }
	if ($r < $MAX_ROW - 1)	{ push @adj_markers, $galaxy[$r + 1][$c] }
	if ($c > 0) 			{ push @adj_markers, $galaxy[$r][$c - 1] }
	if ($c < $MAX_COL - 1)	{ push @adj_markers, $galaxy[$r][$c + 1] }

	if ((markers_count($MARKER_OUTPOST, \@adj_markers) or markers_count($MARKER_STAR, \@adj_markers))
		and not markers_count($MARKER_GROUP_COMPANY, \@adj_markers)
	   ) {
	   	return 1;
	}

	return 0;
}

#----------------------------------------------------------------------------

sub process_move {
	my ($r, $c) = @_;

	my %result; # for checking against script
	my @adj_markers;
	my $cpy;

	if ($r > 0				) { push @adj_markers, $galaxy[$r - 1][$c] }
	if ($r < $MAX_ROW - 1 	) { push @adj_markers, $galaxy[$r + 1][$c] }
	if ($c > 0				) { push @adj_markers, $galaxy[$r][$c - 1] }
	if ($c < $MAX_COL - 1 	) { push @adj_markers, $galaxy[$r][$c + 1] }

	#print __LINE__.": adj_markers = ".Dumper \@adj_markers;

	if (markers_all($MARKER_VACANT, \@adj_markers)) {
		$galaxy[$r][$c] = $MARKER_OUTPOST;
	}
	else {
		# count cpys adjacent to the chosen spot

		my %adj_markers_by_cpy;
		for my $m (@adj_markers) {
			if (is_company($m)) {
				$adj_markers_by_cpy{$MARKER_TO_COMPANY{$m}}++;
			}
		}
		#print __LINE__.": adj_markers_by_cpy = ".Dumper \%adj_markers_by_cpy;

		if (keys %adj_markers_by_cpy >= 2) {			# adjacent to two different companies? merge & new spot becomes largest company
			($cpy, $result{merge}) = merge_companies(keys %adj_markers_by_cpy);
			$galaxy[$r][$c] = $COMPANY_TO_MARKER{$cpy};
			# DON'T push share price up, even if there's a start adjacent
			$companies{$cpy}{num_markers}++;
		}
		elsif (keys %adj_markers_by_cpy == 1) {			# adjacent to one company? new spot becomes adj company
			($cpy) = keys %adj_markers_by_cpy;
			$galaxy[$r][$c] = $COMPANY_TO_MARKER{$cpy};
			$companies{$cpy}{share_price} += $SHARE_PRICE_STD_INC + markers_count($MARKER_STAR, \@adj_markers) * $SHARE_PRICE_START_STAR;
			$companies{$cpy}{num_markers}++;
		}
		else {											# not adjacent to a company? create one, or an outpost
			#if (not markers_count($MARKER_GROUP_COMPANY, \@adj_markers))

			# toi: (in basic code)
			# tof: (in basic code) midway through?

			for my $cpy_test (@COMPANY_NAMES) {
				if (not $companies{$cpy_test}) {
					$cpy = $cpy_test;
					last;
				}
			}
			if ($cpy) {
				spec_ann_new_company($cpy);
				$galaxy[$r][$c] = $COMPANY_TO_MARKER{$cpy};
				$companies{$cpy}{share_price} = $SHARE_PRICE_STD_INC + markers_count($MARKER_STAR, \@adj_markers) * $SHARE_PRICE_START_STAR;
				$companies{$cpy}{num_markers} = 1;
				$players{$player_turn}{shares}{$cpy} = $NUM_SHARES_FOUNDER;
				$result{new_cpy} = substr($cpy, 0, 1);
			}
			else {
				$galaxy[$r][$c] = $MARKER_OUTPOST;
#				$result{outpost} = 1;
			}
		}
	}

	# toj: (in basic code) - convert outpost adj to new company marker to same company

	if ($cpy) { # ie a company marker was created

		for my $adj ([$r - 1, $c], [$r + 1, $c], [$r, $c - 1], [$r, $c + 1]) {
			my ($r_adj, $c_adj) = @$adj;

			next if $r_adj < 0 or $c_adj < 0 or $r_adj > $MAX_ROW - 1 or $c_adj > $MAX_COL - 1; # off map

			#print "r_adj=$r_adj, c_adj=$c_adj\n";

			if ($galaxy[$r_adj][$c_adj] eq $MARKER_OUTPOST) {

				$galaxy[$r_adj][$c_adj] = $galaxy[$r][$c];

				$companies{$cpy}{share_price} += $SHARE_PRICE_STD_INC;
				$companies{$cpy}{num_markers} += 1;
			}
		}
	}

	for my $cpy_test (sort keys %companies) {		# iterates over companies that exist, as opposed to @COMPANY_NAMES which includes non-existent companies
#print __LINE__.": $cpy_test share_price = $companies{$cpy_test}{share_price}\n";
		if ($companies{$cpy_test}{share_price} >= $MAX_SHARE_PRICE) {
			spec_ann_split_2for1($cpy_test);
			$result{'split'}{$cpy_test} = 1;
		}
	}

	# add interest

	#print __LINE__.": \$players{$player_turn} = ".Dumper $players{$player_turn};

	for my $cpy (sort keys %companies) {		# iterates over companies that exist, as opposed to @COMPANY_NAMES which includes non-existent countries
		$players{$player_turn}{cash} += 0.05 * ($players{$player_turn}{shares}{$cpy} || 0) * $companies{$cpy}{share_price};
	}

    if ($script_move) {

		if ($turn_num == $max_turns) {
			for my $player (@player_names) {
				$result{end_game}{$player}{cash} = $players{$player}{cash};
				for my $cpy (@COMPANY_NAMES) {
					if ($companies{$cpy}) {
						my $num_shares = $players{$player}{shares}{$cpy} || 0;
						$result{end_game}{$player}{stock_val} += $num_shares * $companies{$cpy}{share_price};
					}
				}
			}
		}

    	#print "\n\nGame     result = ".(Dumper \%result)."Scripted result = ".(Dumper $script_move->{result})."\n";

		$Data::Dumper::Useqq = 1; # So both Dumper calls incl ' (or not)

    	if (Dumper(\%result) ne Dumper($script_move->{result})) {
    		#confess "Result '$result' does not match scripted result '$script_move->{result}'";
    		confess "\nGame result = ".	 (Dumper \%result).
    				"Scripted result = ".(Dumper $script_move->{result}).
    				"do not match";
    	}
    } # if ($script_move)

} # process_move()

#----------------------------------------------------------------------------

sub merge_companies {
	my @cpys = @_;

	# Work out which company has the most markers

	my $merge_into_cpy = $cpys[0];
	for my $c (@cpys) {
		if ($companies{$c}{num_markers} > $companies{$merge_into_cpy}{num_markers}) {
			$merge_into_cpy = $c;
		}
	}


	my $result;

	# merge others into this company

	for my $c (@cpys) {
		next if $c eq $merge_into_cpy;
		$result = spec_ann_merge($merge_into_cpy, $c);
	}

	return $merge_into_cpy, $result;

} # merge_companies

#----------------------------------------------------------------------------

sub spec_ann_new_company {
	my ($cpy) = @_;

	# tok: (in basic code)
	print "                              Special Announcement!\n\n";

	print "A new shipping company has been formed. It's name is $cpy.\n";
	print "As founder, $player_turn has been allocated $NUM_SHARES_FOUNDER shares.\n";;

} # spec_ann_new_company

#----------------------------------------------------------------------------

sub spec_ann_split_2for1 {
	my ($cpy) = @_;

	# split_2_for_1: (in basic code)
	print "                              Special Announcement!\n\n";

	print "$cpy stock has split 2 for 1.\n\n";

	$companies{$cpy}{share_price} /= 2;

	for my $p (@player_names) {
		if ($players{$p}{shares}{$cpy}) {
			$players{$p}{shares}{$cpy} *= 2;
		}
	}

} # spec_ann_split_2for1

#----------------------------------------------------------------------------

sub spec_ann_merge {
	my ($merge_into_cpy, $c) = @_;

	print "                              Special Announcement!\n\n";

	print "$c has merged into $merge_into_cpy.\n\n";

	print "Please note the following transactions.\n";
	print "Old stock = $c  New stock = $merge_into_cpy\n";
	print "               old       new          total         bonus\n";
	print " Player        stock     stock        holdings      paid\n";

	my %result;
	$result{new_cpy} = substr($merge_into_cpy, 0, 1);
	$result{old_cpy} = substr($c, 			   0, 1);

	my $shares_all_players = 0;
	for my $player (@player_names) {
		$shares_all_players += $players{$player}{shares}{$c};
	}

	for my $player (@player_names) {
		my $bonus = 10 * $companies{$c}{share_price} * $players{$player}{shares}{$c} / $shares_all_players;
		$bonus = int $bonus;
		my $old_shares_now_new = int(($players{$player}{shares}{$c} + 1) / 2);
		$players{$player}{shares}{$merge_into_cpy} += $old_shares_now_new;
		$players{$player}{cash} += $bonus;

		#      " Player        stock     stock        holdings      paid\n";
		#		 123456789 123456789 123456789 123456789012345 123456789

		printf " %-9s %9s %9s %15s %9s\n",
			$player,
			$players{$player}{shares}{$c},
			$old_shares_now_new,
			$players{$player}{shares}{$merge_into_cpy},
			'$'.$bonus,
		;

		$result{by_player}{$player}{old_s} = $players{$player}{shares}{$c};
		$result{by_player}{$player}{new_s} = $old_shares_now_new;
		$result{by_player}{$player}{total} = $players{$player}{shares}{$merge_into_cpy};
		$result{by_player}{$player}{bonus} = $bonus;

		$players{$player}{shares}{$c} = 0;
	}

	for my $row (0 .. @galaxy - 1) {
		for my $col (0 .. @{$galaxy[$row]} - 1) {
			if ($galaxy[$row][$col] eq $COMPANY_TO_MARKER{$c}) {
				$galaxy[$row][$col] = $COMPANY_TO_MARKER{$merge_into_cpy};
			}
		}
	}

	$companies{$merge_into_cpy}{num_markers} += $companies{$c}{num_markers};
	$companies{$merge_into_cpy}{share_price} += $companies{$c}{share_price};
	delete $companies{$c};

	return \%result;

} # spec_ann_merge

#----------------------------------------------------------------------------

sub buy_shares {
	# end_chosen_pos_processing: (in basic code)

	# TOL means end of turn, so reverse logic - huh?

	#print __LINE__.": \$players{$player_turn}{shares} = ".Dumper $players{$player_turn}{shares};
	#print __LINE__.": \%companies = ".					  Dumper \%companies;

	if ($script_move) {
		#print __LINE__.": \$script_move->{buy} = ".Dumper $script_move->{buy};
	}

	# --> Should we continue to just iterate though (sort keys %companies)??? This means the player can't first sell E to fund purchase of A. Or do we stay true to the original?

	for my $cpy (sort keys %companies) {		# iterates over companies that exist, as opposed to @COMPANY_NAMES which includes non-existent countries

		# TOM: (in basic code)
		# TOQ: (in basic code)
		# previous code checked if the player afford a share in the company, but what if they want to sell?

		#print __LINE__.": \$players{$player_turn}{shares}{$cpy} = ".Dumper $players{$player_turn}{shares}{$cpy};
		#print __LINE__.": \$companies{$cpy}{share_price} = ".		Dumper $companies{$cpy}{share_price};

		my $num_shares = $players{$player_turn}{shares}{$cpy} || 0;
		print "\n$player_turn, you own $num_shares $cpy shares valued at \$$companies{$cpy}{share_price} each.\n";
		print "You have \$$players{$player_turn}{cash} cash.\n";

		my $buy_min = $num_shares ? 1 - $num_shares : 0; # actually sell_max. at least one share must be retained
		my $buy_max = int($players{$player_turn}{cash} / $companies{$cpy}{share_price});

		my $choice;

		if ($script_move) {
			$choice = 0;
			if (exists 	  		 $script_move->{buy}{$cpy}) {
				$choice = delete $script_move->{buy}{$cpy};
			}
			print "Buying $choice shares\n";

			if (exists $script_move->{price}{$cpy}) {
				#print STDERR "Checking $script_move->{price}{$cpy} vs $companies{$cpy}{share_price}\n";
				if ($script_move->{price}{$cpy} != $companies{$cpy}{share_price}) {
					# Timing issue here - traders_script2.txt causes Altair: script price=1900, actual price=2400
					die "$cpy: script price=$script_move->{price}{$cpy}, actual price=$companies{$cpy}{share_price}";
				}
			}
		}
		else {
			do {
				print "How many shares would you like to buy or sell ($buy_min to $buy_max) ? ";
				$choice = <STDIN>;
				chomp $choice;
				$choice = 0 if $choice eq "";
			}
			while ($choice !~ /^-?\d+$/ or $choice < $buy_min or $choice > $buy_max);
		}

		# TON: (in basic code)
		# if statement in original code just sets max sell amount so that at least one share is retained. done above.
		$players{$player_turn}{shares}{$cpy} += $choice;
		$players{$player_turn}{cash} -= $choice * $companies{$cpy}{share_price};
	}

	if ($script_move and keys %{$script_move->{buy}}) {
		my $err;
		foreach my $c (sort keys %{$script_move->{buy}}) {
			if ($script_move->{buy}{$c}) {
				$err .= $c;
			}
		}

		confess "Script error: Unactioned buys for $err = ".Dumper $script_move->{buy} if $err;
	}

} # buy_shares

#----------------------------------------------------------------------------

sub end_game {

	print "                              Special Announcement!\n\n";

	my $winning_player = display_score_board();

	print "\n$winning_player is the winner! Congratulations!\n";
}

#----------------------------------------------------------------------------

=pod

sub save_game {

	print "Game saved successfully.\n";
}

#----------------------------------------------------------------------------

sub load_game {

	print "Game loaded successfully.\n";
}

=cut

#----------------------------------------------------------------------------

sub setup_new_game {

	for my $row (0 .. $MAX_ROW - 1) {
		for my $col (0 .. $MAX_COL - 1) {
			$galaxy[$row][$col] = $MARKER_VACANT;
		}
	}

	if ($script_moves) {
		my $m = $script_moves->[0]{map_before}; # $script_move not assigned yet
		#print Dumper $m; die;
		for my $row (0 .. @$m - 1) {
			my @cols = split //, $m->[$row];
			for my $col (0 .. @cols - 1) {
				if ($cols[$col] eq "*") {
					$galaxy[$row][$col] = $MARKER_STAR;
				}
			}
		}
	}
	else {
		# Assign stars to between 3 and 7 positions
		for (1 .. 3 + (int rand 4)) {
			$galaxy[int rand $MAX_ROW][int rand $MAX_COL] = $MARKER_STAR;
		}
	}

	$turn_num = 1;

	if ($script_players) {
		@player_names = @$script_players;
	}
	else {
		my $num_players;

		do {
			print "How many players (2 to 4) ? ";
			$num_players = <STDIN>;
			chomp $num_players;
			exit if lc $num_players eq "q";
		}
		while ($num_players !~ /^\d+$/ or $num_players < 2 or $num_players > 4);

		print "\n";

		for my $i (1 .. $num_players) {
			print "Please enter the name of player $i: ";
			my $p = <STDIN>;
			chomp $p;
			redo if $p eq '';
			push @player_names, $p;
		}

		# mix up @player_names and take the first
		@player_names = shuffle(@player_names);
	}

	for my $p (@player_names) {
		$players{$p}{cash} = $STARTING_CASH;
	}

	print "\n$player_names[0] will have the first turn.\n\n";

	# --> my addition. Due we stay true to the original and hardcode 48? (the classic number of turns)
	$max_turns = $TURNS{s};

#	do {
#		printf "Short/Classic (%d turn), Medium (%d turn) or Long (%d turn) game (s/m/l) ? ", $TURNS{s}, $TURNS{m}, $TURNS{l};
#		my $t = <STDIN>;
#		chomp $t;
#		$max_turns = $TURNS{lc $t}
#	}
#	while (not $max_turns);

} # setup_new_game

#----------------------------------------------------------------------------
# eg my $choice = prompt_for_choice($msg, ["reprocess", "abort"]);

sub prompt_for_choice {
	my ($msg, $ra_valids) = @_;

	my @valids_lc = map { lc $_ } @$ra_valids;

	print "\n$msg\n";
	my $choice = "";
	while (not is_element_of_array($choice, @valids_lc)) {
		print "Enter one of '".join("', '", @valids_lc)."': ";
		$choice = lc <STDIN>;
		chomp $choice;
	}

	return $choice;
}

#----------------------------------------------------------------------------

sub is_element_of_array {
	my ($element, @data_list) = @_;

	if (ref $data_list[0]) {
		confess "data_list is a reference. It should be a real array/list.";
	}
	for my $i (0 .. @data_list - 1) {
		if ($element eq $data_list[$i]) {
			return 1;
		}
	}
	return 0;
}

#----------------------------------------------------------------------------
# end
