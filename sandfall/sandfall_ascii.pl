use strict; use warnings;
use Time::HiRes qw/sleep/;

my $width=100;my $height=30;my $spout=20;my $cy=0;

my $world=[map {[(" ") x $width]} (0..$height)];

for(10..35){                        # build a wall
	$world->[12+.2*$_][$_]="#";
	$world->[11+.2*$_][$_]="#";
}

for (0..1000){
	drawWorld();
	sleep .05;
	snow(3,5);
	fall();
	$spout=50+20*sin($cy++/20);
}


sub drawWorld{
	system($^O eq 'MSWin32'?'cls':'clear');   # clear screen,
	print @{$world->[$_]},"\n" foreach reverse (0..$height);
}

# fall directly down if there is an empty space below
# 

sub fall{
	foreach my $h (1..$height){                   
		foreach my $w (0..$width-1){
			if ($world->[$h][$w] eq "*"){
				if ($world->[$h-1][$w] eq " "){
					$world->[$h][$w]=" ";
					$world->[$h-1][$w]="*";
				}
				elsif(($w+1<$width)&&($world->[$h-1][$w+1] eq " ")){
					if (($w-1>0)&&($world->[$h-1][$w-1] eq " ")){
						$world->[$h][$w]=" ";
						if (rand()>0.5){
							$world->[$h-1][$w-1]="*";
						}
						else{
							$world->[$h-1][$w+1]="*";
						}
				     }
				     else{
						$world->[$h][$w]=" ";
					    $world->[$h-1][$w+1]="*";
					}
						 
				}
				elsif(($w-1>0)&&($world->[$h-1][$w-1] eq " ")){
						$world->[$h][$w]=" ";
					    $world->[$h-1][$w-1]="*";
				}
			}
		}
	}
}

sub snow{
	my ($rate,$size)=@_;
	$world->[$height][$spout+rand()*$size]="*" foreach (0..rand()*$rate)
}

sub blast{
	my ($ph,$pw,$r)=@_;
	foreach my $h ($ph-$r..$ph+$r){
		foreach my $w ($pw-$r..$pw+$r){
			$world->[$h][$w]=" ";
		}
	}
}
