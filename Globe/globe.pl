use strict;use warnings;
binmode( STDOUT, ":encoding(UTF-8)" );
use strict; use warnings;
use Time::HiRes qw/sleep/;
use Image::Magick;
my $pi=4*atan2(1,1);

# the console dimensions
my ($consoleHeight,$consoleWidth)=(100,183);

# load image
my $picture=imageToBVArray("mercator bw2.png",[$consoleWidth*2,$consoleHeight]);

# transform image into a globe
# wrap-around-scroll the image
# and repeat
for(0..2000){
	draw(globe($picture));
	sleep 0.05;
	for( my $row=0;$row<$consoleHeight;$row++){
		$picture->[$row]=scrollBv($picture->[$row],5);
	}
}

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
	foreach my $y (0..$dimensions->[1]){
		foreach  my $x (0..$dimensions->[0]){
			plot($bv,[$x,$y]) if $image->Get('pixel['.  int ($x*$imgWidth/$dimensions->[0]) .','.  int ($y*$imgHeight/$dimensions->[1]) .']') eq "0,0,0,0";
		}
	}
	return $bv;
}

# linear shrinkage of a bit vector to a new size.
sub shrinkBv{  
   my ($inBv,$startLength,$finishLength)=@_;
   my $outBv;
   vec($outBv,$startLength-1,1)=0;
   return $outBv unless $finishLength;
   my $offset=int(($startLength-$finishLength)/2);
    foreach my $oPx (0..$finishLength){
	   my $segment=substr(unpack("b*",$inBv),  $oPx * $startLength/$finishLength,$startLength/$finishLength );
	   # map multiple pixels to one pixel, being set to the mean of the original pixels
	   vec($outBv,$offset+$oPx,1)=1 if $segment && int((unpack("%32b*", pack("b*",$segment))/length $segment)+0.7);
	}
	return $outBv;
}

# scrolling a bitvector by certain displacement
sub scrollBv{
	my ($inBv,$displacement)=@_;
	my $start= unpack("b*",$inBv);
	return pack ("b*",substr($start,-$displacement,$displacement).substr($start,0,(length $start)-$displacement))
}

# given a image, extract the first half (represent a hemisphere
# and the wrap it into a globe by shrinking each row depending on 
# row of the image
sub globe{
	my $image=shift;
	my @hemisphere;
	my $radius=int (scalar @$image/2);
	for( my $row=0;$row<@$image;$row++){
		my $full= unpack("b*",$image->[$row]);
		push @hemisphere, pack("b*",substr($full,0,(length $full)/2));
		my $width=sqrt($radius*$radius-($radius-$row)*($radius-$row));
		$hemisphere[-1]=shrinkBv($hemisphere[-1],180,int($width*2));
	}
	return [@hemisphere];
}
