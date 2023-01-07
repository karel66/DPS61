unit dpsfit;
interface
uses GVMenus,GVDial,DPSPD3,DPSInter;
type
    pParameter=^tParameter;
    tParameter= object (trealdial)
                     value : real;
                     change: real;
                     deriv : real;
                     lowlimit , highlimit :real;
                     sigma : real;
                     free  : boolean;
                     constructor init(avalue,low,high:real);
                     procedure correction (delta : real);
               end;

    ppararray=^tpararray;
    tpararray= array [1..500] of pParameter;


    pparamset =^tparamset;
    tparamset = object (tpulldownmenu)
                     currentvalue  : real;
                     nParameters   : word;
                     p             : ppararray;
                     constructor init (AName :string);
                     procedure calcderivs (tt1 , tt2:real); virtual;
                     procedure FreeParameter (AParameterId: word; set_free :boolean); virtual;
                     procedure FreeAll (set_free :boolean); virtual;
                     procedure writeparams; virtual;
               end;

   ppoly   = ^tpoly;
   tpoly   = object (tparamset)
                    constructor init(aname :string; a0 : real; power : word);
                    procedure calcderivs (tt1,tt2 : real); virtual;
                    procedure FreeParameter (aparameterid : word; set_free :boolean); virtual;
                    procedure FreeAll (set_free :boolean) ; virtual;
                    destructor done ; virtual;
              end;

   ppvoigt =^tpvoigt;
   tpvoigt = object (tparamset)
                    origin                  : ppeak;
                    peak1close,peak2close   : boolean;
                    constructor init(aname:string; apeak : ppeak);
                    procedure calcderivs (tt1,tt2 : real); virtual;
                    procedure writeparams; virtual;
                    destructor  done; virtual;
             end;

   pweightmenu =^tweightmenu;
   tweightmenu = object (tpulldownmenu)
                        constructor init;
                 end;

   pfitmenu =^tfitmenu;
   tfitmenu = object (tscrollmenu)
                     rawpattern          : ppd3pattern;
                     weights             : word;
                     backprof            : pparamset;
                     
                     procedure FreeParameters (Aparameterid : word;
                                                     set_free :boolean);
                     procedure handleevent; virtual;
                     procedure dofit;
              end;

   pprofitmenu =^tprofitmenu;
   tprofitmenu = object (tfitmenu)
                   constructor init ( AName : string; APattern: ppd3pattern);
                   procedure run;         virtual;
                   procedure hide;        virtual;
                 end;


implementation

uses Graph,GVDrive,GVMath,GVStatic;
const
    maxpara       = 140;
    tthrad        = 360/pi;
    cmweights1    = $FF15;
    cmweights2    = $FF16;
    cmweights3    = $FF17;
    cmweights4    = $FF18;
    cmfit         = $FF19;
   
type
    psymmatrix= ^symmatrix;
    symmatrix = array [1..maxpara*(maxpara+1) div 2] of real;

var
   mess                            : tmessagebox;
   sw,old_sw                       : array[1..10] of boolean;

procedure invertmatrix (var fail:boolean; Matrix : psymmatrix; rank:word);
var
   i, j, k, l, m, imax, kli, kmi, kdm, ii  : word;
   sum, term, denom                        : real;
begin
  k := 1;
  fail:=false;
  if rank < 1 then
    begin
         fail:=true;
         exit;
    end;

  if rank = 1 then
    begin
         matrix^[1] := 1.0/matrix^[1];
         exit;
    end;

  for m := 1 to rank do
   begin
    imax := m-1;
    for l := m to rank do
     begin
      sum := 0;
      kli := l;
      kmi := m;
      if imax > 0 then
       for i := 1 to imax do
         begin
            sum := sum+matrix^[kli]*matrix^[kmi];
            j := rank-i;
            kli := kli+j;
            kmi := kmi+j;
         end;
      term := matrix^[k]-sum;
      if (l > m)  then
        matrix^[k] := term/denom
      else
        begin
        if (term  <  0)  then
          begin
             fail   := true;
             exit;
          end;
        denom := sqrt (term);
        matrix^[k] := denom;
        end;
      inc(k);
     end;
   end;

   matrix^[1] := 1.0/matrix^[1];
   kdm        := 1;
   for l := 2 to rank do
   begin
      kdm := kdm+rank-l+2;
      term  :=  1.0/matrix^[kdm];
      matrix^[kdm] := term;
      kmi := 0;
      kli := l;
      imax := l-1;
     for m := 1 to imax do
     begin
      k := kli;
      sum := 0.0;
      for i := m to imax do
      begin
           ii := kmi+i;
           sum := sum-matrix^[kli]*matrix^[ii];
           inc(kli,rank-i);
      end;
      matrix^[k] := sum*term;
      j := rank-m;
      kli := k+j;
      inc(kmi,j);
     end;
   end;
   k := 1;
   for m := 1 to rank do
   begin
    kli := k;
    for l := m to rank do
    begin
      kmi := k;
      imax := rank-l+1;
      sum := 0.0;
      for i := 1 to imax do
      begin
           sum := sum + matrix^[kli]*matrix^[kmi];
           inc(kli);
           inc(kmi);
      end;
      matrix^[k] := sum;
      inc(k);
    end;
   end;
end;

{******************** parameter methods *****************}

constructor tparameter.init;
begin
     value     :=avalue;
     lowlimit  :=low;
     highlimit :=high;
     change    :=0;
     deriv     :=0;
     sigma     :=0;
     free      :=false;
     trealdial.init(' ',8,@value);
end;

procedure tparameter.correction;
begin
     change :=delta;
     if (sigma > 0) and (abs(change) > sigma) then
        if change > 0 then change:=sigma else change:= - sigma;
     if value + change > highlimit then change:=highlimit-value;
     if value + change < lowlimit  then change:=lowlimit-value;
     value  :=value + change;
end;

{******************* profile methods *****************************}
constructor tparamset.init;
begin
     tpulldownmenu.init('');
     nparameters :=0;
end;

procedure tparamset.calcderivs;
begin
end;

procedure tparamset.FreeAll;
var i : integer;
begin
     for i:=1 to nparameters do
             p^[i]^.free:=set_free;
end;

procedure tparamset. FreeParameter;
begin
     if aparameterid <= nparameters then
                                    p^[aparameterid]^.free:=set_free;
end;

procedure tparamset.writeparams;
begin
end;

{************************ Polynomial profile **************************}
constructor tpoly.init;
var
   cb : pcheckbox;
   i  : word;
   txt: string[1];
begin
     tpulldownmenu.init(aname);
     nparameters := power+1;
     if nparameters > 10 then nparameters:=10;
     getmem(p,nparameters*sizeof(pparameter));

     for i:= 1 to nparameters do
      begin
          p^[i]:=new(pparameter,init( 0 ,-1e10,1e10));
          str(i-1:1,txt);
          cb   :=new(pcheckbox,init('a'+txt+' ',@p^[i]^.free));
          cb^.setlabels('FREE ','KEEP ');
          put(cb);
      end;
     p^[1]^.value:=a0;
     p^[1]^.deriv:=1.0;
     for i:= 1 to nparameters do put(@p^[i]^);
     setcolumns(2);
end;

procedure tpoly.calcderivs;
var
     i      : word;
     ttpower: real;
begin
     currentvalue:=p^[1]^.value;
     ttpower:=tt1;
     for i:=2 to nparameters do
       begin
            p^[i]^.deriv:=ttpower;
            currentvalue:=currentvalue + p^[i]^.value*ttpower;
            ttpower:=ttpower*tt1;
       end;
     if currentvalue < 0 then currentvalue:=0;
end;

procedure tpoly.FreeParameter;
begin
end;

procedure tpoly.FreeAll;
begin
     p^[1]^.free:=set_free;
end;

destructor tpoly.done;
begin
     freemem(p,nparameters*sizeof(pparameter));
     tparamset.done;
end;

{************************ Pseudo-Voigtian profile ******************}

constructor tpvoigt.init;
var cb:pcheckbox;
begin
     tpulldownmenu.init(aname);
     origin     :=apeak;
     peak1close   :=true;
     nparameters:=6;
     getmem(p,nparameters*sizeof(pparameter));
     with origin^ do
     begin
     p^[1]:=new(pparameter,init(x,x-2*fwhm,x+2*fwhm));
     p^[1]^.sigma:=origin^.sigx;
     p^[2]:=new(pparameter,init(height,1,65536));
     p^[2]^.sigma:=origin^.sigh;
     p^[3]:=new(pparameter,init(fwhm,0.02,2));
     p^[3]^.sigma:=origin^.sigf;
     p^[4]:=new(pparameter,init(origin^.asym,-0.45,0.45));
     p^[5]:=new(pparameter,init(origin^.shape,0.0,1.0));
     p^[6]:=new(pparameter,init(ka2ka1,0.0,10.0));
     end;
     cb:=new(pcheckbox,init('2-theta ',@p^[1]^.free));
     cb^.setlabels('FREE ','KEEP ');
     put(cb);
     cb:=new(pcheckbox,init('height  ',@p^[2]^.free));
     cb^.setlabels('FREE ','KEEP ');
     put(cb);
     cb:=new(pcheckbox,init('FWHM    ',@p^[3]^.free));
     cb^.setlabels('FREE ','KEEP ');
     put(cb);
     cb:=new(pcheckbox,init('asym    ',@p^[4]^.free));
     cb^.setlabels('FREE ','KEEP ');
     put(cb);
     cb:=new(pcheckbox,init('shape   ',@p^[5]^.free));
     cb^.setlabels('FREE ','KEEP ');
     put(cb);
     cb:=new(pcheckbox,init('Kalpha2 ',@p^[6]^.free));
     cb^.setlabels('FREE ','KEEP ');
     put(cb);
     put(@p^[1]^);
     put(@p^[2]^);
     put(@p^[3]^);
     put(@p^[4]^);
     put(@p^[5]^);
     put(@p^[6]^);
     setcolumns(2);
end;

procedure tpvoigt.calcderivs;
var
   ylor,ygau,yc,hwhm,fwhm,delta,delta2 : real;
   dLdD,dGdD,dLdH,dGdH,yvoi,peakwidth  : real;
   dHdA,lterm,gterm,lgs,lgs1           : real;
   i                                   : integer;
begin
   delta     := p^[1]^.value-tt1;
   delta2    := delta - tt1 + tt2;
   yc        := p^[2]^.value;
   fwhm      := p^[3]^.value;
   peakwidth := 10*fwhm;
   if abs(delta) < peakwidth then
    begin
      peak1close:=true;
      lgs  :=p^[5]^.value;
      lgs1 :=1-lgs;
      if delta > 0 then
              hwhm := (0.5+p^[4]^.value)*fwhm
      else
              hwhm := (0.5-p^[4]^.value)*fwhm;
      lterm :=sqr(delta/hwhm);
      gterm :=0.6931471*lterm;

      ylor  :=1.0/(1+lterm);
      if gterm < 88 then ygau:=exp(-gterm) else ygau:=0;
      yvoi  :=lgs*ylor+lgs1*ygau;
      currentvalue:=yc*yvoi;

      dLdD:= - 2*delta*sqr(ylor/hwhm);
      dLdH:=   2*lterm/hwhm*sqr(ylor);
      dGdD:= - 2*gterm/delta*ygau;
      dGdH:=   2*gterm/hwhm*ygau;

      if p^[1]^.free then p^[1]^.deriv:=yc*(dLdD*lgs + dGdD*lgs1);
      if p^[2]^.free then p^[2]^.deriv:= yvoi;
      if p^[3]^.free then p^[3]^.deriv:=yc*(dLdH*lgs + dGdH*lgs1);
      if p^[4]^.free then
      begin
           if delta > 0 then
              p^[4]^.deriv:= (yc*fwhm*(dLdH*lgs + dGdH*lgs1))
           else
              p^[4]^.deriv:= (-yc*fwhm*(dLdH*lgs + dGdH*lgs1));
      end;
      if p^[5]^.free then p^[5]^.deriv:=yc*(ylor-ygau);
    end
  else
   begin
     if peak1close then
       begin
          for i:=1 to nparameters do p^[i]^.deriv:=0;
          currentvalue   := 0;
          peak1close     := false;
       end;
    end;

  if (p^[6]^.value > 0) and (abs(delta2) < peakwidth) then
    begin
      delta:=delta2;
      yc   := yc*p^[6]^.value;
      if delta > 0 then
              hwhm := (0.5+p^[4]^.value)*fwhm
      else
              hwhm := (0.5-p^[4]^.value)*fwhm;
      lterm :=sqr(delta/hwhm);
      gterm :=0.6931471*lterm;
      ylor  :=1.0/(1+lterm);
      if gterm < 88 then ygau:=exp(-gterm) else ygau:=0;
      yvoi  :=lgs*ylor+lgs1*ygau;
      currentvalue:=currentvalue + yc*yvoi;
      if currentvalue < 0 then currentvalue:=0;
      dLdD:= - 2*delta*sqr(ylor/hwhm);
      dLdH:=   2*lterm/hwhm*sqr(ylor);
      dGdD:= - 2*gterm/delta*ygau;
      dGdH:=   2*gterm/hwhm*ygau;
      if p^[1]^.free then p^[1]^.deriv:= p^[1]^.deriv + yc*(dLdD*lgs + dGdD*lgs1);
      if p^[2]^.free then p^[2]^.deriv:= p^[2]^.deriv + yvoi;
      if p^[3]^.free then p^[3]^.deriv:= p^[3]^.deriv + yc*(dLdH*lgs + dGdH*lgs1);
      if p^[4]^.free then
      begin
           if delta > 0 then
              p^[4]^.deriv:= p^[4]^.deriv + yc*fwhm*(dLdH*lgs + dGdH*lgs1)
           else
              p^[4]^.deriv:= p^[4]^.deriv - yc*fwhm*(dLdH*lgs + dGdH*lgs1);
      end;
      if p^[5]^.free then p^[5]^.deriv := p^[5]^.deriv + yc*(ylor-ygau);
      if p^[6]^.free then p^[6]^.deriv := p^[2]^.value*yvoi;
    end
      else p^[6]^.deriv:=0;

end;

procedure tpvoigt.writeparams;
begin
    if origin<>nil then
       with origin^ do
        begin
           x     :=p^[1]^.value; sigx:=p^[1]^.sigma;
           height:=p^[2]^.value; sigh:=p^[2]^.sigma;
           fwhm  :=p^[3]^.value; sigf:=p^[3]^.sigma;
           asym  :=p^[4]^.value;
           shape :=p^[5]^.value;
           area  :=0.8862269*height*fwhm*(shape*0.7724531+1);
        end;
end;
 
destructor tpvoigt.done;
begin
     writeparams;
     freemem(p,nparameters*sizeof(pparameter));
     tparamset.done;
end;



{******************* WeightMenu   **************************}
constructor tweightmenu.init;
begin
     tpulldownmenu.init('Weighting scheme');
     put(new(pmenuitem,init('w(i)= 1.0',cmweights1)));
     put(new(pmenuitem,init('w(i)= 1/y(i) ',cmweights2)));
     put(new(pmenuitem,init('w(i)= 1/sqr(y(i))',cmweights3)));
end;

{******************* FitMenu   **************************}

procedure tfitmenu.FreeParameters;
var
    prof : pparamset;
    i    : integer;
begin
    prof:=backprof;
    while prof<>nil do
     begin
       prof^.FreeParameter(aparameterid,set_free);
       prof:=@prof^.next^;
     end;
end;


procedure tfitmenu.dofit;
var
   bad                             : boolean;
   bigmatrix                       : psymmatrix;
   resvector                       : array [1..maxpara] of real;
   paralist                        : array [1..maxpara] of pparameter;
   datapoint, fitpoint             : pscandata;
   nfree,nrow,ncol,nlin,npara      : word;
   i,n,cycle                       : word;
   prof                            : pparamset;
   ttheta1,ttheta2                 : real;
   lowangle,highangle,dy,s,dp,sdysq: real;
   cderiv,cbg,ycalc,sumy,sumdy,w   : real;
   rp,rpold,rsig,gof               : real;
   celem                           : ^real;
   i1,i2,block                     : longint;
   txt,txt1                        : string[6];

begin
    if memavail < rawpattern^.scansize then
       begin
            showmessage('Not enough memory. Close some patterns and try again.');
            exit;
       end;
    datapoint := rawpattern^.data;
    getmem(fitpoint,rawpattern^.scansize);
    for i:=1 to rawpattern^.maxindex do fitpoint^[i]:= datapoint^[i];

    lowangle   :=plot.xaxis^.start;
    highangle  :=rawpattern^.start;
    s          :=rawpattern^.step;
    i1         :=1 + trunc((lowangle-highangle)/s);
    if i1 < 1 then i1:=1;
    i2 :=1 + trunc((plot.xaxis^.finish-highangle)/s);
    if i2 > rawpattern^.maxindex then i2:=rawpattern^.maxindex;

  { counts free parameters}
    nfree :=0;
    npara :=0;
    prof  :=backprof;
    while prof<>nil do
     begin
       with prof^ do
          for i:=1 to nparameters do
           if (p^[i]^.free ) and (nfree < maxpara) then
             begin
                  inc(nfree);
                  paralist[nfree]:=@p^[i]^;
             end;
       inc(npara,prof^.nparameters);
       prof:=@prof^.next^;
     end;

    block := sizeof(real)*nfree*(nfree+1) div 2;
    if block >= memavail then
       begin
            showmessage(' Not enough memory ! ');
            beep;
            exit;
       end;
    if (i2-i1) <= nfree then
       begin
            beep;
            showmessage(' Not enough data points ! ');
            exit;
       end;
    getmem (bigmatrix,block);
    rp:=100.0;
    cycle:=0;

  { main cycle }
  repeat
   for i:=1 to (block div sizeof(real)) do bigmatrix^[i]:=0;
   for i:=1 to nfree do resvector[i] :=0;
   inc(cycle);
   sumy :=0;
   sumdy:=0;
   sdysq:=0;

   ttheta1:=rawpattern^.start+(i1-1)*s;
   if cycle > 1 then
      begin
       {    showmessage('This is a unregistered copy of DPS 6.2');
           exit; }
         str (rp*100:6:2,txt);
         str (cycle:2,txt1);
         mess.init(' Cycle '+txt1+'.  Rp''='+txt+'%. Calculating ...');
      end
      else
      begin
         str (nfree:3,txt);
         mess.init(' Fitting '+txt+' parameters ...');
      end;
   for i:=i1 to i2 do
    begin
     ttheta2:=tthrad*arcsin(sin(ttheta1/tthrad)*
                               rawpattern^.alpha2/rawpattern^.alpha1);
     case weights of
          1 : w:=1.0;
          2 : w:=1.0/(1+datapoint^[i]);
          3 : w:=1.0/(1+sqr(datapoint^[i]));
     end;

     { calculates derivatives }
     fitpoint^[i] :=0;
     prof         :=backprof;
     while prof<>nil do
       begin
         prof^.calcderivs(ttheta1,ttheta2);
         fitpoint^[i] :=fitpoint^[i] + prof^.currentvalue ;
         prof         :=@prof^.next^;
       end;

     dy    := datapoint^[i]-fitpoint^[i];
     sumy  := sumy  + abs(fitpoint^[i] - backprof^.currentvalue);
     sumdy := sumdy + abs(dy);
     sdysq := sdysq + w*sqr(dy);

     { updates vectors and matrix }
     for nrow:=1 to nfree do
      begin
         cderiv :=w*paralist[nrow]^.deriv;
         if cderiv <> 0 then
          begin
          resvector[nrow]:=resvector[nrow] + dy*cderiv;
          nlin  :=nfree*(nrow-1) - (nrow*(nrow-1) div 2) + nrow;
          celem :=@bigmatrix^[nlin];
          for ncol:=nrow to nfree do
            begin
             celem^:=celem^ + cderiv*paralist[ncol]^.deriv;
             inc(celem)
            end;
          end;
      end;
     ttheta1:=ttheta1+s;
    end;
    mess.close;

    { calculates reliability indices }
    rsig := sdysq/(i2-i1-nfree);
    rpold:= rp;
    rp   := sumdy/(1+sumy);

  if (nfree > 0) and (rp < rpold) then
  begin
    { test for zero diagonal element}
       nlin:=1;
       ncol:=nfree;
       for i:=1 to nfree do
        begin
         if bigmatrix^[nlin]=0 then
          begin
               str(i:2,txt);
               showmessage(' Zero diagonal element according to parameter '+txt);
               beep;
               freemem(bigmatrix,block);
               exit;
          end;
        inc(nlin,ncol);
        dec(ncol);
       end;

     mess.init(' Inverting matrix ');
     invertmatrix(bad,bigmatrix,nfree);
     mess.close;

     if not bad then
       begin
        for ncol:=1 to nfree do
          begin
            dp   := 0.0;
            nlin := ncol;
            for nrow:=1 to ncol-1 do
            begin
                 dp := dp + resvector[nrow]*bigmatrix^[nlin];
                 inc(nlin,nfree);
                 dec(nlin,nrow);
            end;
            for  nrow:=ncol to nfree do
            begin
                 dp    := dp + resvector[nrow]*bigmatrix^[nlin];
                 inc(nlin);
            end;
           paralist[ncol]^.correction(dp);
           paralist[ncol]^.sigma:=
            sqrt(rsig*bigmatrix^[nfree*(ncol-1)-(ncol*(ncol-1) div 2)+ncol]);
         end;
      end
         else showmessage('Singular least-squares matrix');
  end;

    if (rp > rpold) and (rpold < 0.01) then
    for i:=1 to nfree do with paralist[i]^ do value:=value-change;
 {   prof :=@backprof^.next^;
     while prof<>nil do
       begin
         prof^.writeparams;
         prof:=@prof^.next^;
       end;    }
  until (rp > rpold - 0.01) ;
   
   freemem(bigmatrix,block);
   beep;
   str(100*rp:6:2,txt);
   showmessage(' Final R''='+txt+'%');
{!!!}
   keycode :=0;
end;

procedure tfitmenu.handleevent;
var i: word;
begin
  tscrollmenu.handleevent;
  if not window^.hidden then
  begin
       case keycode of
          cmFit             : dofit;
          cmweights1..cmweights4 : weights:=1 + keycode - cmweights1;
       end;
       for i:=1 to 6 do
       begin
        if sw[i]<>old_sw[i] then
          FreeParameters(i,sw[i]);    {pvoigt parameter numbers used}
        old_sw[i]:=sw[i];
       end;
       keycode:=0;
  end;
  
end;


{******************* profitmenu **************************}

constructor tprofitmenu.init;
begin
     tscrollmenu.init(AName,10);
     rawpattern    :=APattern;
     weights       :=1;
end;

procedure tprofitmenu.run;
var
   angle1,angle2 : real;
   apeak         : ppeak;
   n,i           : word;
begin
   if rawpattern=nil then exit;
   if window^.hidden then
    begin
     getsettings;
     settextstyle(smallfont,horizdir,5);
     put(new(pmenuitem,init('Run ...      ',cmFit)));
     put(new(pweightmenu,init));
     put(new(pcheckbox,init('Peak angles free   ',@sw[1])));
     put(new(pcheckbox,init('Peak heights free  ',@sw[2])));
     put(new(pcheckbox,init('Peak widths free   ',@sw[3])));
     put(new(pcheckbox,init('Peak asymmetrys free ',@sw[4])));
     put(new(pcheckbox,init('Peak shapes free    ',@sw[5])));
     put(new(pcheckbox,init('Ka1/Ka2 ratio free    ',@sw[6])));
     angle1    :=plot.xstart;
     angle2    :=plot.xend;
     if angle1 < rawpattern^.start then angle1:=rawpattern^.start;
     if angle2 > rawpattern^.stop then angle2:=rawpattern^.stop;


     apeak     :=rawpattern^.peaks;
     backprof  :=nil;
     while (apeak<>nil) and (apeak^.x <= angle1) do
                                         apeak:=@apeak^.next^;

     backprof:=new(ppoly,init('Background',
       rawpattern^.data^
       [1+round((angle1-rawpattern^.start)/rawpattern^.step)],7));
     put(backprof);

     n:=0;
     while (apeak<>nil) and
           (apeak^.x < angle2) and (apeak^.x > angle1) do
      begin
       inc(n);
       str(n:3,apeak^.name);
       put(new(ppvoigt,init('Profile '+apeak^.name,apeak)));
       apeak:=@apeak^.next^;
      end;
      restoresettings;
    end;
    for i:=1 to 6 do
        begin
             sw[i]:=false;
             old_sw[i]:=false;
        end; 
    tscrollmenu.run;
end;


procedure tprofitmenu.hide;
begin
     tscrollmenu.hide;
     if child<>nil then dispose(child,done);
     child:=nil;
end;


end.