{**************************************************************************}
{*  DPS 6.0 step-scan data processing unit.                               *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}
unit DPSPRO;

interface
uses GVmenus;
var
     psmenu, corrmenu                   : ppulldownmenu;
     radius                             : real;{ diffractometer radius in millimeters }
     npoints                            : longint;
     EqDE,startangle,stepangle,maxcount : real;
     lowangle,highangle                 : real;
     newpeaks,a2strip,bgon              : boolean;

procedure InitPro;
procedure Findpeaks(lowangle,highangle:real);
function  dlat(ttheta:real):real;

Implementation
uses crt,dpsfiler,dpsinter,gVdrive,gVviews,gVdial,gvmath;
const
   a2a1ratio = 0.48;
type
     ppsm  =^tpsm;
     tpsm  = object (tmenuitem)
                  procedure draw; virtual;
                  procedure run; virtual;
             end;

     pcorr =^tcorr;
     tcorr = object (tmenuitem)
                    actpeak,stpeak : pstring;
                    constructor init(actual,standard:pstring);
                    procedure run; virtual;
             end;
        
var
   mess    : tmessagebox;
   actpeak,stpeak:string[10];

   lowindex,highindex,code,i,j                        : integer;
   y0,y1,y2,y3,y4,y5,y6,y7,y8,y9,y10,y11,y12,y13      : real;
   txt_smoothings,txt_crange,txt_la,txt_ha            : string[10];



{*} function dlat(ttheta:real):real;
    begin
         if ttheta=0 then exit;
         dlat:= target.alpha1/2/sin(InRadians(ttheta/2));
    end;


{*} function arcsin(x :real):real;
   begin
    if abs(x) >=1 then begin arcsin:=0;exit;end;
    arcsin:=arctan(x/sqrt(1-x*x));
   end;

{*} Procedure Linearreg(range:word);
var
    sum,cc   : real;
    halfcr,i : integer;
{* makes previous smoothing for bkg stripping *}
begin
     halfcr:=trunc(range/2);
     range:=2*halfcr+1;
     sum:=0;
     for i:=lowindex to lowindex+range-1 do sum:=sum+counts^[i];
     cc:=sum/range;
     for i:=lowindex to lowindex+halfcr do  deriv0^[i]:=cc;
     for i:=lowindex+halfcr+1 to highindex-halfcr-1 do
                  begin
                       sum:=sum - counts^[i-halfcr-1] + counts^[i+halfcr];
                       deriv0^[i]:=sum/range;
                  end;
    cc:=round(sum/range);
    for i:=highindex downto highindex-halfcr-1 do  deriv0^[i]:=cc;
end;

  {*} Procedure StripAlpha2;
  var
     theta1,theta2,ste,lrat,dx,cc    :real;
     prex,x                          :word;
     i1,i2,cx                        :real;
  begin
    deriv0^:=counts^;
    lrat:=target.alpha1/target.alpha2;
    theta1:=pi*lowangle/360;
    ste   :=pi*stepangle/360;
    theta2:=arcsin(sin(theta1)/lrat);
    dx    :=(theta2-theta1)/ste;
    x     :=lowindex+round(dx+2);
    theta2:=theta2+2*ste;
    repeat
      dx    :=theta2-arcsin(lrat*sin(theta2));
      dx    :=dx/ste;
      prex  :=x - trunc(dx);
      dx    :=frac(dx);
      i1    :=deriv0^[prex-1];
      i1    :=i1-bkg^[prex-1];
      i2    :=deriv0^[prex];
      i2    :=i2-bkg^[prex];
      if prex < x then
         cc :=(dx*i1 + (1 - dx)*i2)*a2a1ratio
       else
         cc :=((1-dx)*i2*(1+a2a1ratio) + dx*i1)*a2a1ratio/
                              (1+a2a1ratio*(1+a2a1ratio)*(1-dx));
      cx:=deriv0^[x];
      cx:=cx-round(cc);
      if cx < 0 then cx:=0;
      deriv0^[x]:=cx;
      theta2    := theta2 + ste;
      inc(x);
    until x > highindex;
  end;

{*} Procedure GetBg;
   var
      miny1                            :real;
      x,x1,x2,minx                      :integer;
      sumy                              :longint;
      slope,minslope                    :real;
      sum1,sum2,sumy1,xr                :real;
      theta,twotheta                    :real;
   begin
        Linearreg(7);
        miny1:=10e28;
        { find minimal intensity }
        for x:=lowindex to highindex do
            if deriv0^[x] <= miny1 then
               begin
                    miny1:=deriv0^[x];
                    minx:=x
               end;
        x1:=minx;
      repeat
        minslope:=-65535; x2:=lowindex;
        (* get second min *)
        y1:=deriv0^[x1];
        for x:=x1-1 downto lowindex do
              begin
                slope:=(deriv0^[x]-y1)/(x-x1);
                if slope >= minslope then
                            begin
                                 minslope:=slope;
                                 x2:=x
                            end;
              end;
        y2:=deriv0^[x2];
        for x:=x1 downto x2 do bkg^[x]:=round(y1 + minslope*(x-x1));
        x1:=x2;
      until x2=lowindex;
      x1:=minx;
      repeat
        minslope:=65535; x2:=highindex;
        (* get second min *)
        y1:=deriv0^[x1];
        for x:=x1+1 to highindex do
              begin
                slope:=(deriv0^[x]-y1)/(x-x1);
                if slope <= minslope then
                            begin  minslope:=slope; x2:=x end;
              end;
        y2:=deriv0^[x2];
        for x:=x1 to x2 do bkg^[x]:=round(y1 + minslope*(x-x1));
        x1:=x2;
      until x2 = highindex;
      bgon:=true;
   end;


{*} procedure Smooth;
var x,w      :longint;
    siglevel :real;
   begin
    x:=lowindex;
    y1:=deriv0^[x];y2:=deriv0^[x+1];y3:=deriv0^[x+2];
    y4:=deriv0^[x+3];y5:=deriv0^[x+4];
    for x:=lowindex+3 to highindex - 3 do
      begin
         if not BgOn then bkg^[x]:=0;
         siglevel:=0;
         siglevel:=siglevel + y3 - bkg^[x];
         if siglevel < 1 then siglevel:=1;
         w := round(siglevel/sqrt(1+y3));
         deriv0^[x]:=round ((y1 + y2 + w*y3 + y4 + y5)/(4 + w));
         y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=deriv0^[x+3];
      end;
   end;

{*} Procedure GetDerivatives;
{ Calculates 1-st derivative of quadratic polynome by Savitzki-Golay }
var  x,cr  : word;
    begin
           if deriv1=nil then new(deriv1);
           x:=lowindex-1;
           y1:=deriv0^[x+1];y2:=deriv0^[x+2];y3:=deriv0^[x+3];y4:=deriv0^[x+4];
           y5:=deriv0^[x+5];y6:=deriv0^[x+6];y7:=deriv0^[x+7];y8:=deriv0^[x+8];
           y9:=deriv0^[x+9];y10:=deriv0^[x+10];y11:=deriv0^[x+11];
           y12:=deriv0^[x+12]; y13:=deriv0^[x+13];
    val(txt_crange,cr,code);
      case cr of
     12..15: for x:=lowindex to highindex-7 do
             begin
             deriv1^[x]:=
             (6*(y13-y1)+5*(y12-y2)+4*(y11-y3)+3*(y10-y4)+2*(y9-y5)+y8-y6)/182;
             y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=y8;y8:=y9;
             y9:=y10;y10:=y11;y11:=y12;y12:=y13;y13:=deriv0^[x+7];
             end;
    10..11: for x:=lowindex to highindex-6 do
            begin
                deriv1^[x]:=
                (5*(y11-y1)+4*(y10-y2)+3*(y9-y3)+2*(y8-y4)+y7-y5)/110;
                y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=y8;y8:=y9;
                y9:=y10;y10:=y11;y11:=deriv0^[x+6];
            end;
    8..9 : for x:=lowindex to highindex-5 do
            begin
                deriv1^[x]:=(4*(y9-y1)+3*(y8-y2)+y6-y4)/60;
                y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=y8;y8:=y9;
                y9:=deriv0^[x+5];
            end;
    6..7: for x:=lowindex to highindex-4 do
            begin
             deriv1^[x]:=(3*(y7-y1) + 2*(y6-y2) + y5-y3)/28;
             y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=deriv0^[x+4];
            end;
    1..5: for x:=lowindex to highindex-3 do
            begin
                deriv1^[x]:=(-2*y1-y2+y4+2*y5)/7;
                y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=deriv0^[x+3];
            end;
       end;
   y1:=deriv1^[x];
   for x:=x to highindex do deriv1^[x]:=y1;
  end;

{*} Procedure StripAndSmooth;
var smoothings : integer;
    siglevel   : real;
begin
     for i:=lowindex to highindex do deriv0^[i]:=counts^[i];
     if a2strip then StripAlpha2;
     val(txt_smoothings,smoothings,code);
     for i:=1 to smoothings do smooth;
     if BgOn then
        for i:=lowindex to highindex do
        begin
          siglevel   :=deriv0^[i];
          siglevel   :=siglevel-bkg^[i];
          (* deriv0 is processed pattern *)
          if siglevel < 0 then siglevel:=0;
          deriv0^[i] :=siglevel;
       end;
    end;


procedure Findpeaks;
var
   cx,lhy                     : integer;
   maxd1,peakheight,dy1,dy2,tt: real;
   apeak                      : ppeak;
   alabel                     : string[6];
begin
     eqde:=0;
     GetDerivatives;
     newpeaks:=true;
     if mainpattern.peaks<>nil then dispose(mainpattern.peaks,done);
     mainpattern.peaks:=nil;
     cx:=lowindex;
    repeat
     while (deriv1^[cx]<=0) and (cx < highindex) do inc(cx);
     peakheight:=0;
     maxd1     :=0;
     inc(cx);
     if cx >= highindex then exit;
     repeat
           dy1:=deriv1^[cx];
           if dy1 > maxd1 then
             begin
              maxd1:=dy1;
              lhy  :=cx;
             end;
           inc(cx);
       until  ((dy1 > 0) and (deriv1^[cx]<=0)) or (cx = maxnpoints);
     dy2:=deriv1^[cx];
     peakheight:=(deriv0^[cx-1]+deriv0^[cx])/2;
     if (maxd1 >= 0.1*peakheight) and (maxd1 > 2) and (dy1<>dy2) then
      begin
        tt:=startangle + stepangle*(cx-2 + dy1/(dy1-dy2));
        str(dlat(tt):6:3,alabel);
        apeak:=(new(ppeak,init
          (tt,(cx-lhy)*2*stepangle,peakheight, alabel)));
        if mainpattern.peaks=nil then  mainpattern.peaks:=new(ppeak,
          init(apeak^.x,apeak^.fwhm,apeak^.height,alabel))
         else mainpattern.peaks^.chain(apeak);
      end;
   until cx >= highindex;
end;

procedure tpsm.draw;
begin
     str(startangle:6:2,txt_la);
     txt_ha:=mainpattern.lastx;
     tmenuitem.draw;
end;

procedure tpsm.run;
begin
     if MainPattern.filename='' then exit;
     mess.init(' Processing... ');
     val(txt_la,lowangle,code);
     val(txt_ha,highangle,code);
     highindex:=round((highangle-startangle)/stepangle);
     if highindex>npoints then highindex:=npoints;
     lowindex:=round((lowangle-startangle)/stepangle);
     if lowindex < 1 then lowindex:=1;
     for i:=1 to npoints do
      if (i<lowindex) or (i>highindex) then
         begin
              deriv0^[i]:=0;
              deriv1^[i]:=0;
              bkg^[i]:=0;
         end;
     GetBg;
     StripAndSmooth;
     Findpeaks(lowangle,highangle);
     mess.close;
end;

constructor tcorr.init;
begin
     tmenuitem.init('Run...',cmesc);
     actpeak:=actual;
     stpeak :=standard;
end;

{*}   Procedure TCorr.run;
      var
       code                   :integer;
       d,th0,th1              :real;
       txt                    :string[10];
       cp                     :ppeak;
       cs                     :pstick;
      begin
       EqDE:=0;
       val(stpeak^,d,code);
       if d<=0 then exit;
       th0:=arcsin(target.alpha1/(2*d));
       val(actpeak^,d,code);
       if d<=0 then exit;
       th1 :=arcsin(target.alpha1/(2*d));
       EqDE:=(th0-th1)/cos(th1);
       str(-radius*EqDE:4:3,txt);
       mess.init(' Equivalent Displacement Error '+txt+' mm ');
       cp:=mainpattern.peaks;
       cs:=@cp^;
       while cs<>nil do
        begin
           cp^.x:=cp^.x + 360/pi*EqDE*cos(inradians(cp^.x/2));
           str(dlat(cp^.x):6:3,cp^.name);
           cs:=cp^.next;
           cp:=@cs^;
        end;
       repeat getevent until event<>evnothing;
       mess.close;
      end;

procedure initpro;
begin
  psmenu:=new(ppulldownmenu,init('Peak search'));
  psmenu^.put(new(ppsm,init('Run...                       ',cmesc)));
  psmenu^.put(New(Pdial,Init('start at  ',@txt_la)));
  psmenu^.put(New(pdial,init('finish at ',@txt_ha)));
  psmenu^.put(New(Pdial,Init('number of smoothings   ',@txt_smoothings)));
  psmenu^.put(New(pdial,init('convolution range (1..13)',@txt_crange)));
  psmenu^.put(New(pcheckbox,init('Alpha-2 stripping',@a2strip)));

  corrmenu:=new(ppulldownmenu,init('Correction'));
  corrmenu^.put(new(pdial,init('Actual d value :',@actpeak)));
  corrmenu^.put(new(pdial,init('Standard d value:',@stpeak)));
  corrmenu^.put(new(pcorr,init(@actpeak,@stpeak)));
end;

begin
     newpeaks:=false;
     a2strip:=true;
     eqde:=0;
     actpeak:='0.0000';
     stpeak:='0.0000';
     txt_smoothings :='3';
     txt_crange     :='5';
     txt_la:='      ';
     txt_ha:='      ';
end.
