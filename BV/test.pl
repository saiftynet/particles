use strict;use warnings;
my $start="00000000000001111110000000000000";
my $packed=pack ("b*",$start);
#print unpack("b*",$packed),"\n";
#print length $bv;
print $start,"\n";
print unpack("b*",$packed),"\n";
print unpack("b*",shrinkLine($packed,length($start), 5));


sub shrinkLine{
   my ($inBv,$startLength,$finishLength)=@_;
   my $outBv;
   print "in=  ",unpack("b*",$inBv),"\n";
   print length  unpack ("b*",$inBv),"\n";
   vec($outBv,length unpack ("b*",$inBv)-1,1)=0;
   print length  unpack ("b*",$outBv),"\n";
   print "out= ",unpack("b*",$outBv),"\n";
   my $offset=($startLength-$finishLength)/2;
    foreach my $oPx (0..$finishLength){
	   print substr(unpack("b*",$inBv),  $oPx * $startLength/$finishLength, 1),"\n";
	 #  vec($outBv,$offset+$oPx,1)=1 if substr(unpack("b*",$inBv),  $oPx * $startLength/$finishLength, 1)
	}
	return $outBv;
}

