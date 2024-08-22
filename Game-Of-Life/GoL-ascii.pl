use strict; use warnings;
use Time::HiRes qw/sleep/;

my $gol=GOL->new({width=>150,height=>200});
my $lf=$gol->loadLife(<<END,"rle");
#N ciscthulhu.rle
#C https://conwaylife.com/wiki/Cthulhu
#C https://www.conwaylife.com/patterns/ciscthulhu.rle
x = 11, y = 13, rule = B3/S23
bo3bo3bo\$obobobobobo\$obobobobobo\$b2obobob2o\$4bobo\$4bobo\$3b2ob2o\$2bo4bo
\$2b2ob2o\$3bobo\$3bo2bo\$4bobo\$3b2ob2o!
END

$gol->randPlot(10000);

# 500 cycles
for (1..500){
	$gol->drawWorld(15,20,100,25);
	$gol->epoch();
}

package GOL;
  my $version=0.03;
  BEGIN{
	  our $lifeForms={
		  glider=>"***\n  *\n * ",
	  };
   }
  
  sub new{
	  my ($class, $params) = @_;
	  my $self={}; 
	  if (ref $params){
		  $self->{$_}=$params->{$_}|| undef foreach qw/width height windowX windowY screenWidth screenHeight/;
	  }
	  else{
		  $self->{width}=$self->{height}=$params;
	  }
	  $self->{board}=[("#"x($self->{width}+2))."\n",(map {"#".(" " x $self->{width})."#\n"}(1..$self->{height})),("#"x($self->{width}+2))."\n"];
	  bless($self,$class);
	  return $self;
  }
  
  sub epoch{
	  my $self=shift;
	  my @buffer=();
      for my $y(1..$self->{height}){
        my $temp="";
        my $x=1;
        my $neighbours="###".substr($self->{board}->[$y-1],$x,1).substr($self->{board}->[$y],$x,1).substr($self->{board}->[$y+1],$x,1);
			while($x++<=$self->{width}){
				$neighbours=substr($neighbours,-6).substr($self->{board}->[$y-1],$x,1).substr($self->{board}->[$y],$x,1).substr($self->{board}->[$y+1],$x,1);
				if ($neighbours eq "         "){$temp.=" ";next;}# reduce unnecessary calcs
				my $n=$neighbours=~tr/\*//;
				if (substr($neighbours,4,1) eq "*"){$temp.= (($n==3)||($n==4))?"*":" "; }
				else{$temp.=$n==3?"*":" ";}   
			}
			push @buffer,"#".$temp."#\n";
			$self->{board}->[$y-2]=shift @buffer if (@buffer>2);
		}
		$self->{board}->[-3]=shift @buffer;
		$self->{board}->[-2]=shift @buffer;
}

	sub drawWorld{
		my ($self,$windowX,$windowY,$screenWidth,$screenHeight)=@_;
		$screenWidth//=40;
		$screenHeight//=20;
		$windowX//=$self->{width}<$screenWidth?0:($self->{width}-$screenWidth)/2;
		$windowY//=$self->{height}<$screenHeight?0:($self->{height}-$screenHeight)/2;
		system($^O eq 'MSWin32'?'cls':'clear');
		print $self->{board}->[$_]?(substr($self->{board}->[$_],$windowX,$screenWidth).($windowX+$screenWidth>$self->{width}+2?"":"\n")):"" foreach($windowY..$windowY+$screenHeight );
	}

	sub plot{
		my($self,$x,$y) =@_;
		substr($self->{board}->[$y],$x,1,"*");
	}

	sub point{
		my($self,$x,$y) =@_;
		substr($self->{board}->[$y],$x,1);
	}

	sub unplot{
		my($self,$x,$y) =@_;
		substr($self->{board}->[$y],$x,1," ");
	}

	sub randPlot{
		my($self,$number) =@_;
		$self->plot(1+rand()*$self->{width},1+rand()*$self->{height}) for (0..$number)
	}

	sub insert{
		my($self,$lifeform,$location,$transformation) =@_;
		if (ref $lifeform eq "HASH") {$lifeform=$lifeform->{data}}
		elsif ($GOL::lifeForms->{$lifeform}) {$lifeform=[split("\n",$GOL::lifeForms->{$lifeform})]}
		else  {$lifeform=[split("\n",$lifeform)]};
		
		if ($transformation){
			$lifeform=$self->flip($lifeform,$transformation);
		}
			
		my ($posX,$posY)=ref $location?(ref $location eq "HASH"?($location->{x},$location->{y}):@$location):split("x",$location);
		
		return if $posX>$self->{width};
		foreach my $row(0..$#$lifeform){
			my $y=$row+$posY;
			last if $y>$self->{height};
			substr ($self->{board}->[$y],$posX,length $lifeform->[$row],$lifeform->[$row]);
		}
	} 

	sub loadLife{
		my ($self,$data,$type)=@_;
		my $lifeForm={};
		my $dataStr=>"";
		if ($type =~/rle/){
			foreach my $line (split ("\n",$data)){
				if ($line=~/^#([A-Z])(.*)$/){
					$lifeForm->{$1}//="";
					$lifeForm->{$1}.=$2;
				}
				elsif($line=~/x\s*=\s*(\d+),\s*y\s*=\s*(\d+),\s*(rule\s*=\s~*.+)?$/){
					
				}
				else{
					$line=~ s/(\d+)(.)/$2 x $1/gse;
					$line=~ s/o/*/igs;
					$line=~ s/[^o\*\$]/ /igs;
					$line=~s/\$/\n/igs;
					$dataStr.=$line;
				}
			}
		}
		$lifeForm->{data}=[split(/\n/,$dataStr)];
		return $lifeForm;
	}
	
	sub flip{
		my ($self,$data,$direction)=@_;
		my @rows=@$data;
			if ($direction =~/h/i){
				$rows[$_]=reverse $rows[$_] foreach (0..$#rows);
			}
			if ($direction =~/v/i){
				@rows=reverse @rows;
			}
			return \@rows;
	}
	


;

__END__
│┤┐└┴┬├─┼┘┌╔═╦═╗║╠═╬═╣╚═╩═╝■
