use strict;
use warnings;
binmode( STDOUT, ":encoding(UTF-8)" );

#https://vanhunteradams.com/Pico/Animal_Movement/Boids-algorithm.html

#  Create a world
my $world =  new BoidWorld( { maxX => 200, maxY => 140, minX => 0, minY => 0, } );
my $starling={ visualRange    => 20,        protectedRange => 8,
	           centeringFactor=> 0.0005,    matchingFactor =>  0.05,     avoidFactor    =>  0.1,
               maxSpeed       => 5,         minSpeed       => 2,
               species        => "starling",mass=> 100,
               tailLength     => 4,
			};
my $time=time();my $cycles=1000; my $number=200;

# populate with random entities;
$world->randEntity($starling) foreach ( 0 .. $number ) ; 
# watch them fly;
for ( 1 .. $cycles ) {
   $world->process();
   $world->draw( 10, 10, 130, 200 );
}
print "\n\nfps for $cycles cycles with $number boids  ", $cycles/(time()-$time);



# Package that defines the world in which the 

package BoidWorld;

sub new {
    my ( $class, $params ) = @_;
    my $self = {};
    # multiple ways of passing world geometry until we settle on the best way
    # this is compatible with 2 or 3 (or more) dimensions.
	$self->{bounds}=$params->{bounds}//{
		   max=>$params->{max}?$params->{max}:[$params->{maxX},$params->{maxY},$params->{maxZ}?$params->{maxZ}:()],
		   min=>$params->{min}?$params->{min}:[$params->{minX},$params->{minY},$params->{minZ}?$params->{maxZ}:()],
		};
    $self->{height} = $self->{bounds}->{max}->[1] - $self->{bounds}->{min}->[1];
    $self->{width}  = $self->{bounds}->{max}->[0] - $self->{bounds}->{min}->[0];
    $self->{dim}    = scalar @{ $self->{bounds}->{max} };  # number of dimensions of this world
    $self->{margin} = 20;
    # print "Max bounds:-", join( ",", @{ $self->{bounds}->{max} } ), "\n";
    # print "Min bounds:-", join( ",", @{ $self->{bounds}->{min} } ), "\n";
    # all interacting entitities, boids, future obstacles, e.g.
    # predators/preys are stored in {entities};
    
    $self->{entities} = [];
    bless $self, $class;
    $self->clear();
    return $self;
}

sub clear{
	my $self=shift;
	my $temp;vec( $temp, $self->{width}+4, 1 ) = 0;
    $self->{grid} = [($temp) x ($self->{height}+4) ];
}

sub insert {
    my ( $self, $entity ) = @_;
    push @{ $self->{entities} }, $entity;
}

sub draw {
    my ( $self, $windowX, $windowY, $height, $width ) = @_;
    my @block = ();  # the grid of braille characters
    for ( my $row = $windowY ; $row < $height - 4 ; $row += 4 ) {
        my $r = "";
        for ( my $column = $windowX ; $column < $width ; $column += 2 ) {
            $r .= $self->blockToBraille( $column, $row );
        }
        push @block, $r;
    }

    system($^O eq 'MSWin32'?'cls':'clear');
    #print "\e[2J\ec";
   # print "\e[?25l"; 
    print join( "\n", @block );
   # print "\e[0H\e[0J\e[?25h";
    
}

# the magic that converts a bit vector array into braille characters
sub blockToBraille { 
    my ( $self, $x, $y ) = @_;
    return chr(0x2800 | oct(
              "0b". vec( $self->{grid}->[ $y + 3 ], $x + 1, 1 )
                  . vec( $self->{grid}->[ $y + 3 ], $x,     1 )
                  . vec( $self->{grid}->[ $y + 2 ], $x + 1, 1 )
                  . vec( $self->{grid}->[ $y + 1 ], $x + 1, 1 )
                  . vec( $self->{grid}->[$y],       $x + 1, 1 )
                  . vec( $self->{grid}->[ $y + 2 ], $x,     1 )
                  . vec( $self->{grid}->[ $y + 1 ], $x,     1 )
                  . vec( $self->{grid}->[$y],       $x,     1 ) 
        )
    );
}

sub plot {
    my ( $self, $vec ) = @_;
    return if outOfBounds($vec);
    vec( $self->{grid}->[ $vec->[1] ], $vec->[0], 1 ) = 1;
}

sub point {
    my ( $self, $vec ) = @_;
  #  return if outOfBounds($vec);
    return vec( $self->{grid}->[ $vec->[1] ], $vec->[0], 1 );
}

sub unplot {
    my ( $self, $vec ) = @_;
  #  return if outOfBounds($vec);
    vec( $self->{grid}->[ $vec->[1] ], $vec->[0], 1 ) = 0;
}

sub outOfBounds {
    my ( $self, $vec ) = @_;
    foreach ( 0 .. $#$vec ) {
        return 1 if $vec->[$_] < $self->{bounds}->{min}->[$_];
        return 2 if $vec->[$_] > $self->{bounds}->{max}->[$_];
    }
    return 0;
}

sub randEntity { # create random boids
    my ($self,$params) = @_;
    $params->{pos} = Vec::Rand( $self->{bounds}->{max}, $self->{bounds}->{min} );
    $params->{vel} = Vec::Rand( [ (3) x $self->{dim} ], [ (-3) x $self->{dim} ] );
    $self->insert( Boid->new( $params ) );
}

sub process {
    my $self = shift;
    # two loops means that the pairs are not repeated 
    foreach my $ind1 ( 0 .. $#{ $self->{entities} } ) {
        foreach my $ind2 ( $ind1 + 1 .. $#{ $self->{entities} } ) {
			my ($boidA,$boidB)=($self->{entities}->[$ind1],$self->{entities}->[$ind2]);
			# are boids near enough to affect each other?
            my $proximity = ( ( $boidA )->closeBy( $boidB ) );
            next unless $proximity;  # not close enough..get next pair;
            if ( $proximity < $boidA->{protectedRange} ) {
				# too close...add their **deltas** to {close};
                $boidA->vecAccum( $boidB, "pos", "close", 1 );
                $boidB->vecAccum( $boidA, "pos", "close", 1 );
            }
            else {
				# within visual range but not in protected area, accumulate position and velocity vectors
                $boidA->vecAccum( $boidB, "pos", "accumPos" );
                $boidA->vecAccum( $boidB, "vel", "accumVel" );
                $boidB->vecAccum( $boidA, "pos", "accumPos" );
                $boidB->vecAccum( $boidA, "vel", "accumVel" );
                # neighbours incremented;
                $boidA->{neighbours}++;
                $boidB->{neighbours}++;
            }

        }
    }
    # now update all the boids
    foreach my $boid (@{ $self->{entities} } ) {
		 # the world is passsed so that the boid object
		 # is aware of geometry of the world it is in
       $boid->update($self);
    }
}

package Boid;

sub new {
    my ( $class, $params ) = @_;
    my $self = {};
    $self->{pos} = $params->{position} // $params->{pos}// [ $params->{x} //0, $params->{y} //0, $params->{z}  // (), ];
    $self->{vel} = $params->{velocity} // $params->{vel}// [ $params->{dx}//0, $params->{dy}//0, $params->{dz} // (), ];
   # die Vec::Print($self->{pos});
    my $default={ mass           => 100,
                  visualRange    => 20,
                  protectedRange => 10,
                  centeringFactor=> 0.0005,
                  matchingFactor =>  0.05,
                  avoidFactor    =>  0.05,
                  turnFactor     => .5,
                  maxSpeed       => 6,
                  minSpeed       => 2,
                  species        => "starling",
			  };
	$self->{$_}=$params->{$_}//$default->{$_} foreach (keys %$default);
	$self->{tail}            = [([ (0) x @{ $self->{pos} } ]) x ($params->{tailLength}||4)];
    bless $self, $class;
    $self->resetCounts();
    return $self;
}

# reset accummulators using them;
sub resetCounts {
    my $self = shift;
    $self->{accumPos} = [ (0) x @{ $self->{pos} } ];
    $self->{accumVel} = [ (0) x @{ $self->{pos} } ];
    $self->{close}    = [ (0) x @{ $self->{pos} } ];
    $self->{neighbours} = 0;
}

# accumulate positions and velocities in respective stores
# if $delta is true, the accumulate differences
sub vecAccum {
    my ( $self, $other, $key, $accumKey, $delta ) = @_;
    $self->{$accumKey}->[$_] += $other->{$key}->[$_] foreach ( 0 .. $#{ $self->{$key} } );
    if ($delta) {
       $self->{$accumKey}->[$_] -= $self->{$key}->[$_] foreach ( 0 .. $#{ $self->{$key} } );
    }
}

sub update{
   my ($self,$world)=@_;
   my $old=shift @{$self->{tail}};
   $world->unplot($old) unless $old->[0]<0;
   if ($self->{neighbours}){  # neighbours are counted and acummulators populated in pass1();
	   $self->{vel}=Vec::Sum($self->{vel},
	        # average accumulated position of neighbours are multiplied by **Centering Factor**
			Vec::Mul( Vec::Sub(Vec::Div( $self->{accumPos},$self->{neighbours}),$self->{pos}) , $self->{centeringFactor}),
	        # average accumulated Velocities of neighbours are multiplied by **Matching Factor**
			Vec::Mul( Vec::Sub(Vec::Div( $self->{accumVel},$self->{neighbours}),$self->{vel}) , $self->{matchingFactor}),	
		)
	}
	if ($self->{close}->[0]){
		# Boids within protected range have their accumulated position /deltas/  multiplied witb avodance factor 
		$self->{vel}=Vec::Add($self->{vel}, Vec::Mul( $self->{close}, $self->{avoidFactor}));
	}
	
	# once in the boundary zome between margin annd edge of universe, a turning factor
	# makes the boid stay in it universe;  this turn factor line allows 2 or 3 dimensions 
	# (or more) to be handled
	$self->{vel}=Vec::Add( $self->{vel},  [map{  $self->{pos}->[$_]>($world->{bounds}->{max}->[$_]-$world->{margin})?-$self->{turnFactor}:
					    ($self->{pos}->[$_]<($world->{bounds}->{min}->[$_]+$world->{margin})?$self->{turnFactor}+2:0) }(0..$#{$self->{pos}})]
					    );
	
	# ensure speed is not too excessive or two little				    
	my $speed=Vec::Scalar($self->{vel});
	if (abs $speed<0.01){
		 $self->{vel}=[(.5) x @{$self->{vel}}]
	}
	elsif ($speed<$self->{minSpeed}){
		Vec::Mul( $self->{vel},$self->{minSpeed}/$speed)
	}
	elsif($speed>$self->{maxSpeed}){
		Vec::Mul( $self->{vel},$self->{maxSpeed}/$speed)
	}
	
	#  not update the positions
	$self->{pos}=Vec::Add($self->{pos},$self->{vel});
	$self->resetCounts();
	push @{$self->{tail}},$self->{pos};
	$world->plot($self->{pos}) unless $self->{pos}->[0]<0;

}

sub closeBy {
    my ( $self, $boid2, $range ) = @_;
    my $toofar = 0;
    foreach ( 0 .. $#{ $self->{pos} } ) {
        return 0if abs( $self->{pos}->[$_] - $boid2->{pos}->[$_] ) >  $self->{visualRange};
    }
    my $distance = Vec::Scalar( Vec::Sub( $self->{pos}, $boid2->{pos} ) );
    return $distance < $self->{visualRange} ? int $distance : 0;
}


package Vec;
# Simple vector maths package that allows 2 or 3 (or more)
# dimension vectors to be handled. 

sub Add { # add two vectors
    my ( $vecA, $vecB ) = @_;
    return [ map { $vecA->[$_] + $vecB->[$_] } ( 0 .. $#$vecA ) ];
}

sub Sub { # subtract two vectors
    my ( $vecA, $vecB ) = @_;
    return [ map { $vecA->[$_] - $vecB->[$_] } ( 0 .. $#$vecA ) ];
}

sub Sum {  # sum multiple vectors
    my $sum = [];
    foreach my $vec (@_) {
        foreach ( 0 .. $#$vec ) {
            $sum->[$_] //= 0;
            $sum->[$_] += $vec->[$_];
        }
    }
    return $sum;
}

sub Mul {  # multiple vector by scalar
    my ( $vec, $scale ) = @_;
    return [ map { $vec->[$_] * $scale } ( 0 .. $#$vec ) ];
}

sub Div {  # divide vector by a scalar
    my ( $vec, $scale ) = @_;
    return [ map { $vec->[$_] / $scale } ( 0 .. $#$vec ) ];
}

sub Rand { # give maximaun and minimum bounds, gnerate a random vector within those bounds
    my ( $max, $min ) = @_;
    $min //= [ (0) x @$max ];
    return [ map { int( rand() * ( $max->[$_] - $min->[$_] ) + $min->[$_] ) }
          ( 0 .. $#$max ) ];
}

sub Scalar { # get scalar magnitude of vector 
    my ($vector) = @_;
    my $sumSquare = 0;
    $sumSquare += $vector->[$_] * $vector->[$_] foreach ( 0 .. $#$vector );
    return sqrt $sumSquare;
}

sub Print {  # debug thing to print a vector
    my ($vector) = @_;
    die "not a Vec at ".caller unless ref $vector eq "ARRAY";
    print Vec::toString($vector), "\n";
}

sub toString {  # debug thing to covert Vec into a string that evaluates to Array Ref.
    my ($vector) = @_;
    die caller unless ref $vector eq "ARRAY";
    return "[" . join( ",", map { sprintf( "%.2f", $_ ) } @$vector ) . "]";
}
