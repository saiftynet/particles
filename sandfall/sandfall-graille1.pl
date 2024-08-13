use strict; use warnings;
use lib "./lib";
use Time::HiRes qw/sleep/;
use Term::Graille 0.12;

my $width=100;my $height=90;my $spout=20;my $cy=0;
  my $canvas = Term::Graille->new(
    width  => 100,    # pixel width
    height => 100,    # pixel height
    top=>3,          # row position in terminal (optional,defaults to 1)
    left=>10,        # column position (optional,defaults to 1)
    borderStyle => "double",  # 
    title =>   "Sandfall $width x $height",
  );

  my $world=Term::Graille->new(
    width  => 100,    # pixel width
    height => 100,    # pixel height
    top=>3,          # row position in terminal (optional,defaults to 1)
    left=>10,        # column position (optional,defaults to 1)
    borderStyle => "none",  # 
  );


wall(10+rand()*($width-20),rand()*($height-30),10+rand()*($width-20),rand()*($height-30));
wall(10+rand()*($width-20),rand()*($height-30),10+rand()*($width-20),rand()*($height-30));
wall(10+rand()*($width-20),rand()*($height-30),10+rand()*($width-20),rand()*($height-30));
wall(10+rand()*($width-20),rand()*($height-30),10+rand()*($width-20),rand()*($height-30));

for (0..1000){
	$canvas->draw();
	pour();
	fall();
	$spout=$width/2+20*sin($cy++/20);
}


sub fall{
	foreach my $y (1..$height){
		foreach my $x (0..$width-1){
			next if ($world->pixel($x,$y));
			if (sand($x,$y)){
				my ($left,$middle,$right)=(occupied($x-1,$y-1),occupied($x,$y-1),occupied($x+1,$y-1));
				unless ($left and  $middle and  $right){
					$canvas->unset($x,$y);
					if (!$middle){
						$canvas->set($x,$y-1,"reset");
					}
					elsif(!$right){  # check down and right clear
						if (!$left){# check down and left
							rand()>0.5?$canvas->set($x-1,$y-1):$canvas->set($x+1,$y-1);
						 }
						 else{                           # down and left not clear so set down and right;
							$canvas->set($x+1,$y-1);
						}
					}
					elsif(!$left){
							$canvas->set($x-1,$y-1);
					}
			    }
			}
		}
	}
}

sub occupied{
	my ($x,$y)=@_;
	return ($canvas->pixel($x,$y)) + ($world->pixel($x,$y));
}
sub sand{
	my ($x,$y)=@_;
	return ($world->pixel($x,$y))?0:$canvas->pixel($x,$y);
}

sub wall{
	my ($x1,$y1,$x2,$y2)=@_;
	$world->thick_line($x1,$y1,$x2,$y2,3);
	$canvas->line($x1,$y1,$x2,$y2);
}

sub pour{
	foreach (0..rand()*3){
		$canvas->set($spout+rand()*5,$height);
	}
}

