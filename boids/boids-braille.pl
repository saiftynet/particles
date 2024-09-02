use strict; use warnings;
binmode(STDOUT, ":encoding(UTF-8)");
#https://vanhunteradams.com/Pico/Animal_Movement/Boids-algorithm.html

#my $world=new BoidWorld({maxX=>200,maxY=>200,maxZ=>200,minX=>0,minY=>0,minZ=>0,});

my $world=new BoidWorld({maxX=>140,maxY=>100,minX=>0,minY=>0,});

foreach (0..100){
	$world->randEntity();
}
for (1..300){
	$world->pass1();
	$world->pass2();
}
package Vec;
# Simple vector maths module that works with 2D or 3D Geometries

sub Add{
	my ($vecA,$vecB)=@_;
	return [map{$vecA->[$_]+$vecB->[$_]}(0..$#$vecA)]
}

sub Sub{
	my ($vecA,$vecB)=@_;
	return [map{$vecA->[$_]-$vecB->[$_]}(0..$#$vecA)]
}

sub Sum{
	my $sum=[];
	foreach my $vec(@_){
		foreach (0..$#$vec){
			$sum->[$_]//=0;
			$sum->[$_]+=$vec->[$_]
		}
	}
	return $sum;
}

sub Mul{
	my ($vec,$scale)=@_;
	return [map{$vec->[$_]*$scale}(0..$#$vec)];
}

sub Div{
	my ($vec,$scale)=@_;
	return [map{$vec->[$_]/$scale}(0..$#$vec)];
}

sub Rand{
	my ($max,$min)=@_;
	$min//=[(0) x @$max];
	return[map{int(rand()*($max->[$_]-$min->[$_])+$min->[$_])} (0..$#$max)]
}

sub Scalar{
	my ($vector)=@_;
	my $sumSquare=0;
	$sumSquare+=$vector->[$_]*$vector->[$_] foreach  (0..$#$vector);
	return sqrt $sumSquare;
}

sub Print{
	my ($vector)=@_;
	die caller unless ref $vector eq "ARRAY";
	print Vec::toString($vector),"\n";
}

sub toString{
	my ($vector)=@_;
	die caller unless ref $vector eq "ARRAY";
	return "[".join(",",map{sprintf ("%.2f",$_)}@$vector)."]";
}

package BoidWorld;

	sub new{
	   my ($class,$params)=@_;
	   my $self={};
	   $self->{bounds}=$params->{bounds}//{
		   max=>$params->{max}?$params->{max}:[$params->{maxX},$params->{maxY},$params->{maxZ}?$params->{maxZ}:()],
		   min=>$params->{min}?$params->{min}:[$params->{minX},$params->{minY},$params->{minZ}?$params->{maxZ}:()],
		};
		$self->{height}=$self->{bounds}->{max}->[1]-$self->{bounds}->{min}->[1];
		$self->{width} =$self->{bounds}->{max}->[0]-$self->{bounds}->{min}->[0];
		$self->{dim}=scalar  @{$self->{bounds}->{max}};
		$self->{margin}=10;
		print "Max bounds:-",join(",",@{$self->{bounds}->{max}}),"\n";
		print "Min bounds:-",join(",",@{$self->{bounds}->{min}}),"\n";
		$self->{grid}=[];
		foreach (0..$self->{height}){
		  vec($self->{grid}[$_],$self->{width},1)=0;
		};
	   $self->{entities}=[];
	   bless $self,$class;
	}

	sub insert{
		my ($self,$entity)=@_;
		push @{$self->{entities}},$entity;
	}
	
	sub worldGrid{
		my $self=shift;
	}


	sub draw{
			my ($self,$windowX,$windowY,$height,$width)=@_;
			my @block=();
			for (my $row=$windowY;$row<$height-4;$row+=4){
				my $r="";
				for (my $column=$windowX;$column<$width;$column+=2){
					$r.=$self->blockToBraille($column,$row);
				}
				push @block,$r;
			}
			#system($^O eq 'MSWin32'?'cls':'clear');
			print "\e[2J\ec";
			print join ("\n",@block);
		
	}

	   
	sub blockToBraille{
		my ($self,$x,$y)=@_;
		return chr(0x2800|oct("0b".join("",vec($self->{grid}->[$y+3],$x+1,1).vec($self->{grid}->[$y+3],$x,1).
										   vec($self->{grid}->[$y+2],$x+1,1).vec($self->{grid}->[$y+1],$x+1,1).
										   vec($self->{grid}->[$y],$x+1,1).vec($self->{grid}->[$y+2],$x,1).
										   vec($self->{grid}->[$y+1],$x,1).vec($self->{grid}->[$y],$x,1) )));
	}

	sub plot{
		my($self,$vec) =@_;
		vec($self->{grid}->[$vec->[1]],$vec->[0],1)=1;
	}

	sub point{
		my($self,$vec) =@_;
		return vec($self->{grid}->[$vec->[1]],$vec->[0],1);
	}

	sub unplot{
		my($self,$vec) =@_;
		vec($self->{grid}->[$vec->[1]],$vec->[0],1)=0;
	}


	sub randEntity{
		my ($self)=@_;
		my $pos=Vec::Rand($self->{bounds}->{max},$self->{bounds}->{min});
		my $vel=Vec::Rand([(5) x $self->{dim}]);
		$self->insert(Boid->new ({pos=>$pos,vel=>$vel}));
	}


	sub pass1{
		my $self=shift;

		foreach my $ind1(0..$#{$self->{entities}}){
			foreach my $ind2($ind1+1..$#{$self->{entities}}){
				my $proximity=(($self->{entities}->[$ind1])->closeBy ($self->{entities}->[$ind2]));
				#print $ind1,"  ",Vec::toString($self->{entities}->[$ind1]->{accumPos}),"  ",Vec::toString($self->{entities}->[$ind1]->{accumVel}),"\n";
				next unless $proximity;
				#print $ind1,"  ",$ind2,"  ",$proximity," Coords  ";
				#print join(",",@{$self->{entities}->[$ind1]->{pos}}),"  ",join(",",@{$self->{entities}->[$ind2]->{pos}}),"\n";
				# print $ind1, " accumPos ",Vec::toString($self->{entities}->[$ind1]->{accumPos});
				if ($proximity<$self->{entities}->[$ind1]->{protectedRange}){
					$self->{entities}->[$ind1]->vecAccum($self->{entities}->[$ind2],"pos","close");
					$self->{entities}->[$ind2]->vecAccum($self->{entities}->[$ind1],"pos","close");
				}
				else{
					$self->{entities}->[$ind1]->vecAccum($self->{entities}->[$ind2],"pos","accumPos");
					$self->{entities}->[$ind1]->vecAccum($self->{entities}->[$ind2],"vel","accumVel");
					$self->{entities}->[$ind2]->vecAccum($self->{entities}->[$ind1],"pos","accumPos");
					$self->{entities}->[$ind2]->vecAccum($self->{entities}->[$ind1],"vel","accumVel");
				}
				$self->{entities}->[$ind1]->{neighbours}++;
				$self->{entities}->[$ind2]->{neighbours}++;
				
				#print "  ",Vec::toString($self->{entities}->[$ind1]->{accumPos}),"  ",Vec::toString($self->{entities}->[$ind1]->{accumVel}),"  ",$self->{entities}->[$ind1]->{neighbours},"\n" ;
			}
		}
	}


	sub pass2{
		my $self=shift;
		foreach my $ind(0..$#{$self->{entities}}){
			$self->{entities}->[$ind]->update($self);;
		}
		$self->draw(0,0,100,140)
	}
	


package Boid;

sub new{
   my ($class,$params)=@_;
   my $self={};
   $self->{pos}=$params->{position}//$params->{pos}//[$params->{x}//0,$params->{y}//0,$params->{z}//0,];
   $self->{vel}=$params->{velocity}//$params->{vel}//[$params->{dx}//0,$params->{dy}//0,$params->{dz}//0,];
   $self->{mass}=$params->{mass}//100;
   $self->{visualRange}=$params->{visualRange}//20;
   $self->{protectedRange}=$params->{protectedRange}//5;
   $self->{turnFactor}=$params->{turnFactor}//2;
   $self->{centeringFactor}=0.1;
   $self->{matchingFactor}=0.1;
   $self->{avoidFactor}=0;
   bless $self,$class;
   $self->resetCounts();
   return $self;
}

sub resetCounts{
   my $self=shift;
   $self->{accumPos}=[(0) x @{$self->{pos}}];
   $self->{accumVel}=[(0) x @{$self->{pos}}];
   $self->{close}=[(0) x @{$self->{pos}}];
   $self->{neighbours}=0;
	
}

sub vecAccum{
	my ($self,$other,$key,$accumKey)=@_;
	$self->{$accumKey}->[$_]+=$other->{$key}->[$_] foreach (0..$#{$self->{$key}});
}

sub inVecBounds{
	my ($self,$key,$universe,$maxKey,$minKey)=@_;
	my $result=[];
	$result->[$_]=bounds($self->{$key}->[$_],$universe->{$maxKey}->[$_],$universe->{$minKey}->[$_])  foreach (0..$#{$self->{$key}})
}

sub bounds{
	my ($value,$upperBound,$lowerBound)=@_;
	return $value>$upperBound?1:($value<$lowerBound?-1:0);
}

sub update{
   my ($self,$world)=@_;
	## Add the centering/matching contributions to velocity
	
	$world->unplot($self->{pos});
   if ($self->{neighbours}){
	   
	   $self->{vel}=Vec::Sum($self->{vel},
	                Vec::Mul( Vec::Sub(Vec::Div( $self->{accumPos},$self->{neighbours}),$self->{pos}) , $self->{centeringFactor}),
	                Vec::Mul( Vec::Sub(Vec::Div( $self->{accumVel},$self->{neighbours}),$self->{vel}) , $self->{matchingFactor}),	                
	                Vec::Mul( $self->{close}, $self->{avoidFactor})
	                )
	}
	$self->{vel}=Vec::Add( $self->{vel},  [map{  $self->{pos}->[$_]>($world->{bounds}->{max}->[$_]-$world->{margin})?-$self->{turnFactor}:
					    ($self->{pos}->[$_]<($world->{bounds}->{min}->[$_]+$world->{margin})?$self->{turnFactor}:0) }(0..$#{$self->{pos}})]
					    );
	$self->{pos}=Vec::Add($self->{pos},$self->{vel});
	$self->resetCounts();
	$world->plot($self->{pos});

}

sub closeBy{
	my ($self,$boid2,$range)=@_;
	my $toofar=0;
	foreach (0..$#{$self->{pos}}){
		return 0 if abs ($self->{pos}->[$_]-$boid2->{pos}->[$_])>$self->{visualRange};
	}
	my $distance=Vec::Scalar(Vec::Sub($self->{pos},$boid2->{pos}));
	return $distance<$self->{visualRange}?int $distance:0;
}


__END__
## For every boid . . .
#for each boid (boid):
   my $tmp={};
    ## Zero all accumulator variables (can't do this in one line in C)
    $tmp->{neighboring_boids}=[];
	$tmp->{$_}=0 foreach(qw/xpos_avg ypos_avg xvel_avg yvel_avg close_dx close_dy/);
    $tmp->{dx}=$boidA->{x}-$boidB->{x};
    $tmp->{dy}=$boidA->{y}-$boidB->{y};
    if (abs($tmp->{dx})<$visual_range and abs($tmp->{dx})<$visual_range){## Are both those differences less than the visual range?
		$tmp->{squaredDistance}=$tmp->{dx}*$tmp->{dx}+$tmp->{dy}*$tmp->{dy};            ## If so, calculate the squared distance
		if ($tmp->{squaredDistance} < $protected_range_squared){  # Is squared distance less than the protected range?
                $tmp->{close_dx} += $tmp->{dx};    #     If so, calculate difference in x/y-coordinates to nearfield boid
                $tmp->{close_dy} += $tmp->{dy};
		}
		elsif($tmp->{squaredDistance} < $visual_range*$visual_range){            ## If not in protected range, is the boid in the visual range?
			$tmp->{xpos_avg}+=$boidB->{x};
			$tmp->{ypos_avg}+=$boidB->{y};
			$tmp->{xvel_avg}+=$boidB->{vx};
			$tmp->{yvel_avg}+=$boidB->{vy};
			push @{$tmp->{neighboring_boids}},$boidB;
		}
	}
	          
    if (@{$tmp->{neighboring_boids}} > 0){   ## If there were any boids in the visual range . .
		my $cnt=@{$tmp->{neighboring_boids}};
		$tmp->{xpos_avg}/=$cnt; ## Divide accumulator variables by number of boids in visual range
		$tmp->{ypos_avg}/=$cnt;
		$tmp->{xvel_avg}/=$cnt;
		$tmp->{yvel_avg}/=$cnt;
	}
	
	## Add the centering/matching contributions to velocity
	$boidA->{vx}+=($tmp->{xpos_avg}-$boidA->{x})*$centering_factor +
	               $tmp->{xvel_avg}-$boidA->{vx}*$matching_factor
	               $close_dx*$avoidFactor +
	               ($boidA->{x}<$leftMargin?$turnFactor:($boidA->{y}>$rightMargin?-$turnFactor:0));
	$boidA->{vy}+=($tmp->{ypos_avg}-$boidA->{y})*$centering_factor +
	               $tmp->{yvel_avg}-$boidA->{vx}*$matching_factor  +
	               $close_dy*$avoidFactor
	               ($boidA->{y}<$topMargin?$turnFactor:($boidA->{y}>$bottomMargin?-$turnFactor:0));
	               
    ## Calculate the boid's speed	               
	$boid->{speed}=sqrt($boidA->{vx}*$boidA->{vx}+$boidA->{vy}*$boidA->{vy});

	if ($boidA->{speed}<$minSpeed){
        $boidA->{vx} = $boidA->{vx}*$minSpeed/$boidA->{speed};
        $boidA->{vy} = $boidA->{vy}*$minSpeed/$boidA->{speed};
	}
	elsif ($boidA->{speed}>$maxSpeed){
        $boidA->{vx} = $boidA->{vx}*$maxSpeed/$boidA->{speed};
        $boidA->{vy} = $boidA->{vy}*$maxSpeed/$boidA->{speed};
	}

    $boidA->{x} += $boid->{vx};
    $boidA->{y} += $boid->{vy};

    ###############################################################
    #### ECE 5730 students only - dynamically update bias value ###
    ###############################################################
    ## biased to right of screen
    #if (boid in scout group 1): 
        #if (boid.vx > 0):
            #boid.biasval = min(maxbias, boid.biasval + bias_increment)
        #else:
            #boid.biasval = max(bias_increment, boid.biasval - bias_increment)
    ## biased to left of screen
    #else if (boid in scout group 2): # biased to left of screen
        #if (boid.vx < 0):
            #boid.biasval = min(maxbias, boid.biasval + bias_increment)
        #else:
            #boid.biasval = max(bias_increment, boid.biasval - bias_increment)
    ###############################################################

    ## If the boid has a bias, bias it!
    ## biased to right of screen
    #if (boid in scout group 1):
        #boid.vx = (1 - boid.biasval)*boid.vx + (boid.biasval * 1)
    ## biased to left of screen
    #else if (boid in scout group 2):
        #boid.vx = (1 - boid.biasval)*boid.vx + (boid.biasval * (-1))

    ## Calculate the boid's speed
    ## Slow step! Lookup the "alpha max plus beta min" algorithm
    #speed = sqrt(boid.vx*boid.vx + boid.vy*boid.vy)

    ## Update boid's position
    #boid.x = boid.x + boid.vx
    #boid.y = boid.y + boid.vyV
