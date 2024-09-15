use strict;use warnings;
binmode( STDOUT, ":encoding(UTF-8)" );
use strict; use warnings;
use Time::HiRes qw/sleep/;
use Image::Magick;
my $pi=4*atan2(1,1);

my $start="10110011110000110001";
my $testBulge=pack("b*",$start);
my $out=bulgeBv($testBulge,[1,2,3]);
#die  unpack("b*",$out);


# the console dimensions (to decide the height of image) is 4*character height;
# $consolewidth is 2*column width of the terminal window
my ($consoleHeight,$speed)=@ARGV;
$consoleHeight||=80;
my $consoleWidth=$consoleHeight<100?124:$consoleHeight+50;
$speed//=10;
print "\e[?25l";
# load image into a bit vector array of predefined dimensions
my $picture=imageToBVArray("mercator bw2.png",[$consoleWidth*3,$consoleHeight]);

# transform image into a globe
# wrap-around-scroll the image
# and repeat
for(0..180){
	draw(globe($picture));
	sleep 0.05;
	for( my $row=0;$row<$consoleHeight;$row++){
		$picture->[$row]=scrollBv($picture->[$row],$speed);
	}
}
print "\n\n\e[?25h";

# create a bitvector arrray
sub grid{
   my ($width,$height)=@_;
   my $temp;vec( $temp, $width, 1 ) = 0;
   return [map{$temp}(0..$height)];
}

# this function converts a bit vector array in a array of braille characters
# and draws the array to the console
sub draw {
    my ($grid, $startX, $startY, $width, $height ) = @_;
    $startX//=0;
    $startY//=0;
    $width//=((length $grid->[0])-1)*8;
    $height//=$#$grid;
    $height-=$#$grid%4;
    my @block = ();  # the grid of braille characters
    for ( my $y = $startY ; $y < $height  ; $y += 4 ) {
        my $r = "";
        for ( my $x = $startX ; $x < $width ; $x += 2 ) {
            $r .= chr(0x2800 | oct(
              "0b". vec( $grid->[ $y + 3 ], $x + 1, 1 )
                  . vec( $grid->[ $y + 3 ], $x,     1 )
                  . vec( $grid->[ $y + 2 ], $x + 1, 1 )
                  . vec( $grid->[ $y + 1 ], $x + 1, 1 )
                  . vec( $grid->[$y],       $x + 1, 1 )
                  . vec( $grid->[ $y + 2 ], $x,     1 )
                  . vec( $grid->[ $y + 1 ], $x,     1 )
                  . vec( $grid->[$y],       $x,     1 ) 
				)
			);
        }
        push @block, $r;
    }
    system($^O eq 'MSWin32'?'cls':'clear');
    print join( "\n", @block );
}

# plot pixel in a bitvector array
sub plot {
    my ( $grid, $vec ) = @_;
    die if outOfBounds($grid,$vec);
    vec( $grid->[ $vec->[1] ], $vec->[0], 1 ) = 1;
}

# get pixel value in a bitvector array
sub point {
    my ( $grid, $vec ) = @_;
    return undef if outOfBounds($grid,$vec);
    return vec( $grid->[ $vec->[1] ], $vec->[0], 1 );
}

# unplot pixel in a bitvector array
sub unplot {
    my ( $grid, $vec ) = @_;
    return if outOfBounds($grid,$vec);
    vec( $grid->[ $vec->[1] ], $vec->[0], 1 ) = 0;
}
# ensure the bit vector does not go out of the bitvector array
sub outOfBounds {
    my ( $grid, $vec ) = @_;
    return 1 if $vec->[0] > 8*(length $grid->[0]);
    return 2 if $vec->[1] > @$grid;
    return 3 if $vec->[0] < 0;
    return 4 if $vec->[1] < 0;
    return 0;
}

 # takes either a file or an Image::Magick object and 
 # dimensions of target bit vector array
 # returns bit vector array array containing the image in those dimensions
 sub imageToBVArray{
	my ($imageFile,$dimensions)=@_;
	my $image;
	if (ref $imageFile eq "Image::Magick"){
		$image=$imageFile;
	}
	elsif(-f $imageFile){
		$image = Image::Magick->new;
		$image->Read($imageFile);
	}
	my ($imgHeight,$imgWidth)=($image->Get('rows') ,$image->Get('columns'));
	my $bv=grid(@$dimensions);
	# this is a very crude recsaling of the image and inserting into bit vectors (black pixels are plotted;
	foreach my $y (0..$dimensions->[1]){
		foreach  my $x (0..$dimensions->[0]){
			plot($bv,[$x,$y]) if $image->Get('pixel['.  int ($x*$imgWidth/$dimensions->[0]) .','.  int ($y*$imgHeight/$dimensions->[1]) .']') eq "0,0,0,0";
		}
	}
	return $bv;
}

sub bulgeBv{
   my ($inBv,$bulgeFactors)=@_;
   return $inBv unless $bulgeFactors;
   my $outBv;
   push @$bulgeFactors,reverse @$bulgeFactors;
   my $segmentLength=(length  unpack("b*",$inBv))/scalar @$bulgeFactors;
   my $indexIn=0;my $indexOut=0;
  for my $b (0..$#$bulgeFactors){
	  for (0..$segmentLength-1){
		  vec($outBv,$indexOut++,1)=vec($inBv,$indexIn,1) foreach(1..$bulgeFactors->[$b]);
		  $indexIn++;
	  }
  }
	return $outBv;
}

# linear shrinkage of the contents of a bit vector to a new size, so that contents
# fit in a smaller section.  The output bit vector is the same size as the input
sub shrinkBv{  
   my ($inBv,$startLength,$finishLength)=@_;
   my $outBv;
   vec($outBv,$startLength-1,1)=0;
   return $outBv unless $finishLength;
   my $offset=int(($startLength-$finishLength)/2);
    # decide for each pixel whether it is set or not set based on the 
    # the segment of the original it represent (the average of the pixel values rounded);
    # For linear shrinkage, each segment is the same width...making the animation lack "depth"
    foreach my $oPx (0..$finishLength){ 
	   my $segment=substr(unpack("b*",$inBv),  $oPx * $startLength/$finishLength,$startLength/$finishLength );
	   # map multiple pixels to one pixel, being set to the mean of the original pixels
	   vec($outBv,$offset+$oPx,1)=1 if $segment && int((unpack("%32b*", pack("b*",$segment))/length $segment)+.5);
	}
	return $outBv;
}

# scrolling a bitvector by certain displacement with wrap-around
sub scrollBv{
	my ($inBv,$displacement)=@_;
	return $inBv unless $displacement;
	my $start= unpack("b*",$inBv);
	if ($displacement<0){
		return pack ("b*",substr($start,$displacement,length ($start)-$displacement).substr($start,0,$displacement));
	}
	return pack ("b*",substr($start,-$displacement,$displacement).substr($start,0,(length $start)-$displacement))
}

# given a image, extract the first half (representing a hemisphere)
# and the wrap it into a globe by shrinking the contents of each row
# depending on row of the image
sub globe{
	my $image=shift;
	my @hemisphere;
	my $radius=int (scalar @$image/2);
	for( my $row=0;$row<@$image;$row++){
		my $full= unpack("b*",$image->[$row]);
		$hemisphere[$row]= pack("b*",substr($full,0,(length $full)/2));
		my $width=sqrt($radius*$radius-($radius-$row)*($radius-$row));
		$hemisphere[$row]=shrinkBv($hemisphere[$row],(length $full)/2,int($width*2));
	}
	return [@hemisphere];
}
