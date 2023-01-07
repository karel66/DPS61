{**************************************************************************}
{*  DPS 6.1 PD3pattern unit                                               *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}

unit dpspd3;

interface
uses Dos,GVMenus,GVMath;
type
  ppeak =^tpeak;
  tpeak = object (tstick)
                 fwhm, height, area, asym, shape, x2: real;
                 sigx, sigf, sigh                   : real;
                 constructor init(ttheta,ttheta2,w,h : real; atext:string);
                 procedure readin;
                 procedure writeout;
                 procedure draw (xpx0,xpx1,yzero,ymax : integer;
                                       xz, xscale ,yscale :real) ; virtual;
             end;

  p2pd3pattern= ^ppd3pattern;
  ppd3pattern = ^pd3pattern;
  pd3pattern  = object (tstepscan)
                sample           : string[40];
                date,source      : string[20];
                crossref,grant,
                DivSlit,RecSlit,GenKV,GenMA,
                ctime,Xstep,firstX,lastX,
                maxY,npoints,xunits,yunits,yfactor,
                detector,diffract,monochr, generator,
                icdddx,pdfno    : string[8];
                anode           : string[2];
                scansize        : longint;
                peaks           : ppeak;
                newset          : boolean;
                maxint,yshift   : real;
                alpha1,alpha2   : real;
                EqDE            : real;
                cor_std,cor_real: real;
                ps_smooth,
                ps_convrange,
                ps_minpeak      : longint;
                oldscan         : pscandata;

                constructor init ;
                procedure load (newfile:pathstr); virtual;
                procedure shifty (newoffset:real);
                procedure readpeaks;
                procedure readtarget;
                procedure savepeaks;
                procedure stripa2 (intratio:real);
                procedure smartsmooth (ntimes:word);
                procedure findpeaks ;
                procedure correction;
                procedure closedown;
                function dlat(ttheta:real):real;
                destructor done; virtual;
               end;

var
      pd3pat : array [1..16] of ppd3pattern;



implementation
uses Crt,Graph,GVDial,GVDrive,DPSInter;
type
    pstring=^string;
    labellink = object
                      la:string[16];
                      de:pstring;
                      procedure make(labstr:string; deststr:pstring);
                end;

constructor tpeak.init;
begin
     x      :=ttheta;
     x2     :=ttheta2;
     fwhm   :=w;
     height :=h;
     area   :=0;
     asym   :=0;
     shape  :=0.5;
     sigx   :=0;
     sigh   :=0;
     sigf   :=0;
     next   :=nil;
     tstick.init(x,x,height+height,atext);
end;

procedure tpeak.draw;
var
   current_color       :word;

   procedure draw_prof(xpeak:word; vertscale:real);
   var
      i,n0,n1          :integer; {profile width in pixels}
      dx                  :real;    {sqr of distance from peak in units of hwhm}
      dy                  :integer;
      y_max               :real;    {scaled peak height}
      hwhm                :real;    {hwhm with asymmetry}
   begin
    n0:=trunc(3*fwhm*xscale);
    n1:=n0;
    if n0 > xpeak - xpx0 then n0:=xpeak-xpx0;
    if n1 > xpx1 - xpeak then n1:=xpx1-xpeak;
    y_max :=vertscale*height;
    hwhm := (0.5+asym)*fwhm;
    for i:=-n0 to n1 do
     begin
        if i=0 then hwhm := (0.5-asym)*fwhm; {swaps asymmetry}
        dx:=sqr(i/xscale/hwhm);
        dy:=round(yzero -y_max*(shape/(1+dx)+(1-shape)/exp(0.694*dx)));
        if dy > ymax then putpixel(xpeak+i,dy,current_color);
     end;
  end;

begin
   tstick.draw(xpx0,xpx1,yzero,ymax,xz,xscale,yscale); {calculates also xpx}
   if area > 0 then
   begin
    current_color:=getcolor;
    draw_prof(xpx,yscale);
    if ka2ka1 > 0 then draw_prof(round(xpx0+(x2-xz)*xscale),ka2ka1*yscale);
  end
end;


procedure tpeak.readin;
begin
     readln(x,sigx,fwhm,sigf,height,sigh,area,asym,shape,name);
     sigx:=sigx/1000;
     sigf:=sigf/1000;
     y1:=2*height;
end;

procedure tpeak.writeout;
begin
     writeln (x:8:3,' ',sigx*1000:3:0,'   ',fwhm:5:3,' ',sigf*1000:3:0,'  ',
             height:7:1,' ',sigh:5:1,'  ',area:7:3,'  ',asym:5:2,' ',
             shape:5:2,' ',name);
end;

procedure labellink.make;
begin
     la:=labstr;
     de:=deststr;
end;

constructor pd3pattern.init;
begin
     newset       :=false;
     dir          :='';
     name         :='';
     exte         :='';
     fullpath     :='';
     sample       :='';
     xstep        :='';
     firstx       :='';
     lastx        :='';
     yshift       :=0;
     step         :=0;
     scansize     :=0;
     eqde         :=0;
     peaks        :=nil;
     data         :=nil;
     oldscan      :=nil;
     ps_smooth    :=3;
     ps_convrange :=5;
     ps_minpeak   :=1;
     cor_std      :=0;
     cor_real     :=0;
end;

procedure pd3pattern.shifty;
begin
     yshift:=newoffset;
     maxint  :=maxint + yshift;
end;


procedure pd3pattern.load;
const
     noflabels=23;
var
     PD3                    : array [1..noflabels+1] of labellink;
     pd3file                : text;
     aline                  : string[50];
     alabel                 : string[16];
     endlab                 : string [9];
     n,separator,index      : integer;
     ymax,x                 : real;
begin
  if newfile='' then exit;
  assign(pd3file,newfile);
{$i-}
  reset(pd3file);
{Si+}
  if ioresult=0 then
  begin
     PD3[1].make('&SAMPLE IDENT=',@sample);
     PD3[2].make('&FILE IDENT=',@fullpath);
     PD3[3].make('&DATE=',@date);
     PD3[4].make('&ANODE=',@anode);
     PD3[5].make('&GEN KV=',@GenKV);
     PD3[6].make('&GEN MA=',@GenMA);
     PD3[7].make('&DIV SLIT=',@DivSlit);
     PD3[8].make('&REC SLIT=',@RecSlit);
     PD3[9].make('&COUNT TIME=',@ctime);
     PD3[10].make('&STEP SIZE=',@Xstep);
     PD3[11].make('&FIRSTX=',@firstX);
     PD3[12].make('&LASTX=',@lastX);
     PD3[13].make('&MAXY=',@maxY);
     PD3[14].make('&NPOINTS=',@npoints);
     PD3[15].make('&XUNITS=',@xunits);
     PD3[16].make('&YUNITS=',@yunits);
     PD3[17].make('&YFACTOR=',@yfactor);
     PD3[18].make('&DETECTOR=',@detector);
     PD3[19].make('&DIFFRACTOMETER=',@diffract);
     PD3[20].make('&MONOCHROMATOR=',@monochr);
     PD3[21].make('&GENERATOR TYPE=',@generator);
     PD3[22].make('&PDFNO=',@pdfno);
     PD3[23].make('&ICDD-DX=',@icdddx);

     repeat
           readln(pd3file,aline);
           n:=1;
           separator :=pos('=',ALine);
           ALabel    :=copy(ALine,1,separator);
           while (PD3[n].la<>ALabel) and (n <= noflabels) do inc(n);
           if n <= noflabels then
              begin
                delete(ALine,1,separator);
                PD3[n].de^:=ALine;
              end;
     until (ALabel='&XYDATA=') or seekeof(pd3file);
     anode    := copy(anode,1,2);
     start    := convstr(firstx);
     step     := convstr(xstep);

     maxindex := trunc(convstr(npoints));
     if maxindex < 5 then showmessage('Only '+npoints+' data points!');
     if maxindex > maxnpoints then maxindex:=maxnpoints;

     if scansize > 0 then freemem(data,scansize);
     scansize :=sizeof(real)*maxindex;
     getmem(data,scansize);
     index:=0;
     ymax :=0;
     read(pd3file,x);
     repeat
       while (not seekeoln(pd3file)) and (index < maxindex) do
              begin
                  inc(index);
                  read(pd3file,x);
                  if x > ymax then ymax:=x;
                  data^[index]:=x;
              end;
       readln(pd3file);
       read(pd3file,endlab);
     until seekeoln(pd3file) or seekeof(pd3file);
     close (pd3file);
     maxint   := ymax;
     stop     := start + (index-1)*step;
     str (stop:6:2,lastx);
     fsplit(NewFile,dir,name,exte);
     fullpath:=dir+name+exte;
     
     readtarget; {readtarget must be allways before readpeaks}
     readpeaks;
     newset:=true;
   end
     else
         begin
              beep;
              beep;
              showmessage('File '+newfile+' not found ');
         end;
end;

procedure pd3pattern.readpeaks;  {target wavelengths should be known}
var
    num                    : real;
    newpeak                : ppeak;
    version                : string[4];
begin
     if peaks<>nil then dispose(peaks,done);
     peaks:=nil;
{$I-}
     assign (input, dir + name + '.PEA');
     reset (input);
{$I+}
    if ioresult = 0 then
    begin
     readln (version); readln; readln;
     if version='DPS6' then
     begin
        peaks:=new(ppeak,init(0,0,0,0,''));
        while not seekeof (input) do
            begin
             newpeak := new(ppeak,init(0,0,0,0,''));
             if seekeoln(input) then readln;
             read (num);
             newpeak^.readin;
             newpeak^.y0:=5 + data^[1+round((newpeak^.x-start)/step)];
             newpeak^.y1:=10 + 1.04*newpeak^.y0;
             newpeak^.x2:=360/pi*arcsin(sin(newpeak^.x*pi/360)*alpha2/alpha1);
             peaks^. chain(newpeak);
           end;
        newpeak :=peaks;
        peaks   :=@peaks^.next^;
        newpeak^.next:=nil;
        dispose(newpeak,done);
      end;
        close (input);
    end;
    assigncrt(input);
    reset(input);
end;

procedure pd3pattern.readtarget;
var
   found    : boolean;
   symb     : string[2];
begin
    alpha1:=1.54056;
    alpha2:=1.54439;
    found :=false;
    assign(input,dpsdir+'\target.dat');
{$i-}
    reset(input);
{$i+}
    if IOResult=0 then
     begin
      while not seekeof(input) do
         begin
              read(symb);
              if symb=anode then
                 begin
                   readln(alpha1,alpha2);
                   found:=true;
                 end
              else readln;
         end;
     close(input);
     assigncrt (input);
     reset (input);
     if not found then
      showmessage('WARNING! Wavelengths for' + anode +' target not found');
    end
    else  showmessage('ERROR! File TARGET.DAT not found. Using Cu wavelengths.');
end;

procedure pd3pattern.savepeaks;
var
    cp     : ppeak;
    cs     : pstick;
    i      : integer;
begin
   assign(output,dir+name+'.PEA');
   rewrite(output);
   writeln('DPS6 XRD pattern peaks ');
   writeln(sample);
   writeln(anode,
 '    2theta 1000s FWHM  1000s height    s     area    asym  shape   d ');
   cp:=peaks;
   cs:=@cp^;
   i :=1;
   while cs<>nil do
    begin
     write(i:3,'.');
     str(dlat(cp^.x):6:3,cp^.name);
     cp^.writeout;
     cs:=cp^.next;
     cp:=@cs^;
     inc(i);
    end;
   close(output);
   assigncrt(output);
   rewrite(output);
end;

procedure pd3pattern.stripa2;
var
     theta1,theta2,ste,lrat,dx,cc    :real;
     prex,x                          :word;
     i1,i2,cx                        :real;
begin
    lrat   := alpha1/alpha2;
    theta1 := pi*start/360;
    ste    := pi*step/360;
    theta2 := arcsin(sin(theta1)/lrat);
    dx     := (theta2 - theta1)/ste;
    x      := 1 + trunc ( dx + 2 );
    theta2 := theta2 + 2*ste;
    repeat
      dx   := theta2 - arcsin(lrat*sin(theta2));
      dx   := dx/ste;
      prex := x - trunc(dx);
      dx   := frac(dx);
      i1   := data^[prex-1];
      i2   := data^[prex];
      if prex < x then
         cc :=(dx*i1 + (1 - dx)*i2)*intratio
       else
         cc :=((1-dx)*i2*(1+intratio) + dx*i1)*intratio/
                              (1+intratio*(1+intratio)*(1-dx));
      cx:=data^[x];
      cx:=cx-round(cc);
      if cx < 0 then cx:=0;
      data^[x]:=cx;
      theta2 := theta2 + ste;
      inc(x);
    until x >= maxindex;
end;

procedure pd3pattern.smartsmooth;
var
   n,x            : longint;
   y1,y2,y3,y4,y5 : real;
   weight         : real;
begin
  { oldscan^ is assumed to be unprocessed pattern ,
                           data^ bacground stripped pattern}
  for n:= 1 to ntimes do
   begin
    y1:=data^[1];
    y2:=data^[2];
    y3:=data^[3];
    y4:=data^[4];
    y5:=data^[5];
    for x:=3 to maxindex - 3 do
      begin
         if oldscan^[x] > 0 then
            weight  :=data^[x]/sqrt(oldscan^[x])
         else weight:=1;
         data^[x]:=round ((y1 + y2 + weight*y3 + y4 + y5)/(4 + weight));
         y1:=y2; y2:=y3; y3:=y4; y4:=y5; y5:=data^[x+3];
      end;
   end;
end;

procedure pd3pattern.findpeaks;
var
   datasize,i                     : longint;
   d1data,procdata                : pscandata;
   dy1,dy2,lhy,peakheight,maxd1,tt,tt2 : real;
   dlabel                         : string[6];
   newpeak                        : ppeak;
begin
   datasize := sizeof(real)*maxindex;
   getmem (oldscan,datasize);
   for i:=1 to maxindex do oldscan^[i] :=data^[i];
   linsmooth;
   background;
   for i:=1 to maxindex do data^[i]:=oldscan^[i]-data^[i];
   stripa2 ( ka2ka1 );
   smartsmooth (ps_smooth);
   procdata := data;
   getmem (d1data,datasize);
   for i:=1 to maxindex do d1data^[i]:=data^[i];
   data     := d1data;
   firstderiv (ps_convrange);
   data     := procdata;

   if peaks<>nil then dispose(peaks,done);
   peaks :=nil;
   i :=1;
   repeat
     while (d1data^[i]<=0) and (i < maxindex) do inc(i);
     peakheight:=0;
     maxd1     :=0;
     inc(i);
     if i < maxindex then
     repeat
           dy1:=d1data^[i];
           if dy1 > maxd1 then
             begin
              maxd1:=dy1;
              lhy  :=i;
             end;
           inc(i);
     until  ((dy1 > 0) and (d1data^[i]<=0)) or (i >= maxindex);
     dy2:=d1data^[i];
     peakheight:=(data^[i-1]+data^[i])/2;
     if (maxd1 >= 0.05*peakheight) and
        (maxd1 > 2) and
        (peakheight > ps_minpeak*sqrt(1+oldscan^[i])) and
        (dy1<>dy2) then
      begin
        tt:=start + step*(i-2 + dy1/(dy1-dy2));
        tt2:=360/pi*arcsin(sin(tt*pi/360)*alpha2/alpha1);
        str(dlat(tt):6:3,dlabel);
        newpeak:=(new(ppeak,init(tt,tt2,(i-lhy)*1.5*step,peakheight,dlabel)));
        newpeak^.y0:=oldscan^[i] + 5 ;
        if peaks=nil then peaks:=newpeak
                          else peaks^.chain(newpeak);
      end;
  until i >= maxindex;
  freemem (d1data,datasize);
  for i:=1 to maxindex do data^[i]:=oldscan^[i];
  freemem (oldscan,datasize);
end;

procedure pd3pattern.correction;
var
   d,th0,th1              :real;
   txt                    :string[6];
   cp                     :ppeak;
   cs                     :pstick;
begin
   EqDE:=0;
   if cor_std<=0 then exit;
   th0:=arcsin(alpha1/(2*cor_std));
   if cor_real<=0 then exit;
   th1 :=arcsin(alpha1/(2*cor_real));
   EqDE:=(th0-th1)/cos(th1);
   cp:=peaks;
   cs:=@cp^;
   while cs<>nil do
        begin
           cp^.x:=cp^.x + 360/pi*EqDE*cos(pi*cp^.x/360);
           str(dlat(cp^.x):6:3,cp^.name);
           cs:=cp^.next;
           cp:=@cs^;
        end;
  str(-radius*EqDE:4:3,txt);
  showmessage(' Equivalent Displacement Error '+txt+' mm ');
end;

function pd3pattern.dlat (ttheta:real) :real;
begin
   if ttheta=0 then dlat:=0 else
      dlat:= alpha1/2/sin(pi*ttheta/360);
end;

procedure pd3pattern.closedown;
begin
     if scansize > 0 then freemem(data,scansize);
     scansize:=0;
     data:=nil;
     if peaks<>nil then dispose(peaks,done);
     peaks:=nil;
end;

destructor pd3pattern.done;
begin
     closedown;
end;
end.