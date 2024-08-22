use strict; use warnings;
binmode(STDOUT, ":encoding(UTF-8)");

my $gol=GOLVec->new(300,200);

my $rle='
#N Gosper glider gun
#O Bill Gosper
#C A true period 30 glider gun.
#C The first known gun and the first known finite pattern with unbounded growth.
#C www.conwaylife.com/wiki/index.php?title=Gosper_glider_gun
x = 36, y = 9, rule = B3/S23
24bo11b$22bobo11b$12b2o6b2o12b2o$11bo3bo4b2o12b2o$2o8bo5bo3b2o14b$2o8b
o3bob2o4bobo11b$10bo5bo7bo11b$11bo3bo20b$12b2o!
';

my $lf=$gol->loadLife($rle,"rle");

$gol->insert($lf,[30,30]);
$gol->insert($lf,[80,31],"h");
$gol->insert($lf,[31,80],"v");
$gol->insert($lf,[80,80],"hv");


for (0..2000){
$gol->drawBraille(2,2,{width=>120,height=>120});
$gol->epoch();
}

package GOLVec;

sub new{
	  my ($class, $width, $height) = @_;
	  my $self={}; 
	  $self->{width}=$width//100;
	  $self->{height}=$height//$self->{width};
	  $self->{board}=[];
	  foreach (0..$self->{height}+1){
		  vec($self->{board}[$_],$self->{width}+2,1)=0;
	  };
	  bless($self,$class);
	  return $self;
}

  sub epoch{
	  my $self=shift;
	  my @buffer=(); my $x;
      my $empty=undef;
      vec($empty,$self->{width}+2,1)=0;
      my $temp=$empty;
      for my $y(1..$self->{height}){
		if  (unpack("%32b*", $self->{board}->[$y-1]) | unpack("%32b*", $self->{board}->[$y]) |  unpack("%32b*", $self->{board}->[$y+1])){
			$x=1;
			my $neighbours="000".vec($self->{board}->[$y-1],$x,1).vec($self->{board}->[$y],$x,1).vec($self->{board}->[$y+1],$x,1);
			while($x++<=$self->{width}){
				$neighbours=substr($neighbours,-6).vec($self->{board}->[$y-1],$x,1).vec($self->{board}->[$y],$x,1).vec($self->{board}->[$y+1],$x,1);
				my $n=$neighbours=~tr/1//;
				if (substr($neighbours,4,1) eq "1"){vec($temp,$x-1,1)= (($n==3)||($n==4))?1:0; }
				else{ vec($temp,$x-1,1)=$n==3?1:0;}   
			}
	    }
	    else{
           $temp=$empty;
		}
		push @buffer,$temp;
		$self->{board}->[$y-2]=shift @buffer if (@buffer>2);
	  }
	  $self->{board}->[-3]=shift @buffer;
	  $self->{board}->[-2]=shift @buffer;
	}

   sub drawBraille{
		my ($self,$windowX,$windowY,$canvas)=@_;
		my @block=();
		for (my $row=$windowY;$row<$canvas->{height}-4;$row+=4){
			my $r="";
			for (my $column=$windowX;$column<$canvas->{width};$column+=2){
				$r.=$self->blockToBraille($column,$row);
			}
			push @block,$r;
		}
		
		system($^O eq 'MSWin32'?'cls':'clear');
		print join ("\n",@block);
   }
   
	sub blockToBraille{
		my ($self,$x,$y)=@_;
		return chr(0x2800|oct("0b".join("",vec($self->{board}->[$y+3],$x+1,1).vec($self->{board}->[$y+3],$x,1).
		                                   vec($self->{board}->[$y+2],$x+1,1).vec($self->{board}->[$y+1],$x+1,1).
		                                   vec($self->{board}->[$y],$x+1,1).vec($self->{board}->[$y+2],$x,1).
		                                   vec($self->{board}->[$y+1],$x,1).vec($self->{board}->[$y],$x,1) )));
	}
	
	sub plot{
		my($self,$x,$y) =@_;
		vec($self->{board}->[$y],$x,1)=1;
	}

	sub point{
		my($self,$x,$y) =@_;
		return vec($self->{board}->[$y],$x,1);
	}

	sub unplot{
		my($self,$x,$y) =@_;
		vec($self->{board}->[$y],$x,1)=0;
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
			my $x=$posX;
			last if $y>$self->{height};
			foreach my $bit(split(//,$lifeform->[$row])){	
				vec	($self->{board}->[$y],$x++,1)=$bit;		
			}
			print "\n";
		}
	}
	
	sub randPlot{
		my($self,$number) =@_;
		$self->plot(1+rand()*$self->{width},1+rand()*$self->{height}) for (0..$number)
	}
	
	
	sub flip{
		my ($self,$data,$direction)=@_;
		my @rows=@$data;
			if ($direction =~/h/i){
				my $maxlength=1;
				foreach (0..$#rows){
					$rows[$_]=reverse $rows[$_] ;
					$maxlength=length $rows[$_] if $maxlength < length $rows[$_];
				}
				foreach (0..$#rows){
					$rows[$_]="0" x ($maxlength - length $rows[$_])  . $rows[$_];
				}
			}
			if ($direction =~/v/i){
				@rows=reverse @rows;
			}
			return \@rows;
	}

	sub loadLife{
		my ($self,$data,$type)=@_;
		my $lifeForm={};
		my $dataStr="";
		if ($type =~/rle/){
			foreach my $line (split ("\n",$data)){
				if ($line=~/^#([A-Z])(.*)$/){
					$lifeForm->{$1}//="";
					$lifeForm->{$1}.=$2;
				}
				elsif($line=~/x\s*=\s*(\d+),\s*y\s*=\s*(\d+),\s*(rule\s*=\s~*.+)?$/){
					# extract rules here [assumes b23/s3]
				}
				else{
					$line=~ s/(\d+)(.)/$2 x $1/gse; # rle deode
					$line=~ s/[o\*]/1/igs;          # o or * becomes 1
					$line=~ s/[^1\$]/0/igs;       # everything else apart from $ becomes 0
					$line=~s/\$/\n/igs;             # $ becomes next row
					$dataStr.=$line;
				}
			}
		}
		$lifeForm->{data}=[split(/\n/,$dataStr)];
		return $lifeForm;
	}
