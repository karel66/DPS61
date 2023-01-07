{**************************************************************************}
{*  GVision plotter unit                                                  *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and x-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}
unit gvmath;
interface
uses dos, crt, graph, gvdrive, gvviews, gvstatics,gvdial,gvmenus,gvfiler;
const
     colors : array [1..15] of string[7]=
     ('Black  ','Blue   ','Green  ','Cyan   ','Red    ','Magenta',
      'Brown  ','L-gray ','D-gray ','L-blue ','L-green','L-cyan ',
      'L-red  ','L-mag  ','Yellow ');
var maxy : real;
type

  ppscandata= ^pscandata;
  pscandata = ^tscandata;
  tscandata = array [1..10000] of real;

  pstepscan = ^tstepscan;
  tstepscan = object (tdiskfile)
                    data              : pscandata;
                    maxindex          : longint;
                    start, stop, step : real;
                    constructor init (xstart, xstop, xstep :real);
                    procedure linsmooth;
                    procedure background;
                    procedure firstderiv (convrange : word); virtual;
              end;

  PAxis = ^TAxis;
  TAxis = object
            x0, y0, x1, y1,
            markline, linlength         : integer;
            start, finish, reallength   : real;
            sinphi, cosphi, scale       : real;
            style, oldstyle             : textsettingstype;
            color, oldcolor             : word;
            marksnum, height, width     : word;
            
            constructor init (xs, ys, xf, yf, marks: integer;
            font, size, AColor: word);
            procedure Reset (var newstart, newfinish: real);
            destructor done; virtual;
          end;

  
  trange = object
             start, finish, reallength : real;
             newset                    : boolean;
             procedure Reset (st, fin  : real);
           end;

  ppstick= ^pstick;
  pstick = ^tstick;
  tstick = object
             x,              {x-coordinate}
             y0,             {beginning y}
             y1      : real; {ending y (upper)}
             xpx     : word; {x pixel coordinate}
             name    : string [32];
             next    : pstick;
             constructor init (x0, y00, y10: real; AName: string);
             procedure chain (newstick : pstick);
             procedure draw (xpx0, xpx1, yzero, ymax : integer;
                                   xz, xscale ,yscale :real) ; virtual;
             destructor done;
           end;
  
  pchannel = ^tchannel;
  tchannel = object
               x0, y0, x1, y1      : word;
               maxindex            : word;
               startp,endp,stepp,yoff: preal;
               xstart, xend, xstep : real;
               yoffset             : real;
               xrange, yrange      : trange;
               datap               : ppscandata;
               data                : pscandata;
               stickp              : ppstick;
               sticks              : pstick;
               connected           : boolean;
               dataon              : boolean;
               dots                : boolean;
               stickson            : boolean;
               constructor init (X01, y01, X02, y02: word);
               procedure connect (start, finish, step, newoffset: preal;
                         newdata: ppscandata; newsticks:ppstick);
               procedure disconnect;
               procedure draw (lowx, hix, lowy, hiy: real);
               procedure redraw;
               procedure erase;
               procedure setbias (newbias : real);
               destructor done;
             end;
  
  
  
  PPlotter = ^TPlotter;
  TPlotter = object (tview)
               tracehandle    : ppulldownmenu;
               xaxis, yaxis   : paxis;
               input          : array [1..15] of pchannel;
               buttons        : array [1..3,1..15] of pbutton;
               nchan , yaxzero: word;
               xstart, xend   : real;
               ystart, yend   : real;
               Tracex, Tracey : real;
               txdisp, tydisp : prealdial;
               oldX, oldY     : word;
               buttonline     : word;
               TracerOn       : boolean;
               oldtrace       : boolean;
               constructor init (X01, y01, X02, y02, yzero, numofchannels: word;
                                header : string);
               procedure draw; virtual;
               procedure redraw;
               procedure run; virtual;
               procedure connect (channel: word;
                      maxy, start, finish, step, newoffset: preal;
                      newdata: ppscandata; newsticks:ppstick);
               procedure handlemouse; virtual;
               procedure settracehandle (newhandle:ppulldownmenu);
               procedure hidetrace;
               destructor done; virtual;
             end;

function arcsin(x:real):real;
function min(x1,x2:real): real;
function max(x1,x2:real): real;

implementation

{*} function arcsin(x :real):real;
   begin
    if abs(x) >=1 then arcsin:=0 else
    arcsin:=arctan(x/sqrt(1-x*x));
   end;

{*} function min;
begin
   if x1 < x2 then min:=x1 else min:=x2;
end;
{*} function max;
begin
   if x1 < x2 then max:=x2 else max:=x1;
end;
  
constructor tstepscan.init;
begin
     start :=xstart;
     stop  :=xstep;
     step  :=xstep;
     maxindex :=1 + trunc((stop-start)/step);
end;

procedure tstepscan.linsmooth;
var
   i             : longint;
   sum,y1,y2,y3  : real;
begin
     {linear smoothing over 5 data points}
     sum:=0;
     for i:=1 to 5 do  sum:=sum+data^[i];
     y1:=data^[1];
     y2:=data^[2];
     for i:=3 to maxindex - 3 do
      begin
       y3:=data^[i];
       data^[i]:=sum / 5;
       sum:=sum - y1 + data^[i+3];
       y1:=y2;
       y2:=y3;
      end;
end;

procedure tstepscan.background;
var
   bg                                : pscandata;
   datasize                          : longint;
   x,x1,x2,minx                      : integer;
   y1,y2,miny1,slope,minslope        : real;
begin
   datasize:=sizeof(real)*maxindex;
   if memavail < datasize then exit;
   getmem(bg,datasize);
   miny1:=1e28;
     { find minimal intensity }
   for x:=1 to maxindex do
    if data^[x] <= miny1 then
       begin
         miny1:=data^[x];
         minx:=x
       end;
   x1:=minx;
   repeat
       minslope:=-65535;
       x2:=1;
       {* get second min *}
       y1:=data^[x1];
       for x:=x1-1 downto 1 do
         begin
           slope:=(data^[x]-y1)/(x-x1);
           if slope >= minslope then
                       begin
                         minslope:=slope;
                         x2:=x;
                       end;
         end;
       y2:=data^[x2];
       for x:=x1 downto x2 do bg^[x]:=y1 + minslope*(x-x1);
       x1:=x2;
   until x2=1;
   x1:=minx;
   repeat
       minslope:=65535;
       x2:=maxindex;
      {* get second min *}
       y1:=data^[x1];
       for x:=x1+1 to maxindex do
          begin
            slope:=(data^[x]-y1)/(x-x1);
            if slope <= minslope then
               begin
                  minslope:=slope;
                  x2:=x
               end;
          end;
        y2:=data^[x2];
        for x:=x1 to x2 do bg^[x]:=y1 + minslope*(x-x1);
        x1:=x2;
   until x2 = maxindex;
   for x := 1 to maxindex do data^[x]:=bg^[x];
   freemem(bg,datasize);
end;

procedure tstepscan.firstderiv;
var
   y1,y2,y3,y4,y5,y6,y7,y8,y9,y10,y11,y12,y13 : real;
   x                                          : longint;

{ Calculates 1-st derivative of quadratic polynome by Savitzki-Golay }
begin
   y1:=data^[1];   y2:=data^[2];   y3:=data^[3];   y4:=data^[4];
   y5:=data^[5];   y6:=data^[6];   y7:=data^[7];   y8:=data^[8];
   y9:=data^[9];   y10:=data^[10]; y11:=data^[11]; y12:=data^[12];
   y13:=data^[13];
   case convrange of
     12..15: for x:=1 to maxindex-7 do
             begin
             data^[x]:=
             (6*(y13-y1)+5*(y12-y2)+4*(y11-y3)+3*(y10-y4)+2*(y9-y5)+y8-y6)/182;
             y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=y8;y8:=y9;
             y9:=y10;y10:=y11;y11:=y12;y12:=y13;y13:=data^[x+7];
             end;
    10..11: for x:=1 to maxindex-6 do
            begin
                data^[x]:=
                (5*(y11-y1)+4*(y10-y2)+3*(y9-y3)+2*(y8-y4)+y7-y5)/110;
                y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=y8;y8:=y9;
                y9:=y10;y10:=y11;y11:=data^[x+6];
            end;
    8..9 : for x:=1 to maxindex-5 do
            begin
                data^[x]:=(4*(y9-y1)+3*(y8-y2)+y6-y4)/60;
                y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=y8;y8:=y9;
                y9:=data^[x+5];
            end;
    6..7: for x:=1 to maxindex-4 do
            begin
             data^[x]:=(3*(y7-y1) + 2*(y6-y2) + y5-y3)/28;
             y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=y6;y6:=y7;y7:=data^[x+4];
            end;
    1..5: for x:=1 to maxindex-3 do
            begin
                data^[x]:=(-2*y1-y2+y4+2*y5)/7;
                y1:=y2;y2:=y3;y3:=y4;y4:=y5;y5:=data^[x+3];
            end;
       end;
   y1:=data^[x];
   for x:=x to maxindex do data^[x]:=y1;
end;

{-----------------------------------------------------------------}
{                       TAxis methods                             }
{-----------------------------------------------------------------}
constructor taxis. init;
begin
  x0 := xs;
  y0 := ys;
  x1 := xf;
  y1 := yf;
  markline := marks;
  style. font := font;
  style. charsize := size;
  style. direction := horizdir;
  color := AColor;
  start := 0;
  finish   := 1;
  marksnum := 1;
  height   := 1;
  linlength:= Round (Sqrt (Sqr (1.0 * x1 - x0) + Sqr (1.0 * y1 - y0) ) );
  sinphi   := (y1 - y0) / linlength;
  cosphi   := (x1 - x0) / linlength;
  reallength := 1;
  GetTextSettings (oldstyle);
  SetTextStyle (style. font, style. direction, style. charsize);
  width   := TextWidth ('EEEEEEEE');
  height  := Abs (4 * markline) + TextHeight ('E');
  marksnum := Round (5 * linlength / (Abs (cosphi * width) + 2 * Abs (sinphi * height) ) );
  SetTextStyle (oldstyle. font, oldstyle. direction, oldstyle. charsize);
end;

procedure taxis. Reset;
var
  stepcount, divstep, decplaces, labwidth    : word;
  ymark, xmark                               : integer;
  marker, redxunit, firstshift               : real;
  xunit, currentx                            : real;
  valuelabel                                 : string [10];
begin
  if newfinish = newstart then newfinish := newstart + 1;
  if newfinish < newstart then
  begin
    currentx  := newfinish;
    newfinish := newstart;
    newstart  := currentx;
  end;
  start     := newstart;
  finish    := newfinish;
  reallength := finish - start;
  if reallength =0 then exit;
  scale     := linlength / reallength;
  xunit     := reallength / marksnum;
  redxunit  := xunit;
  while redxunit > 10 do redxunit := redxunit / 10;
  while redxunit <  1 do redxunit := redxunit * 10;
  xunit     := xunit / redxunit;
  divstep   := 10;
  case Round (redxunit) of
    1..3: xunit := 2 * xunit;
    4..7: xunit := 5 * xunit;
    8..10: xunit := 10 * xunit;
  end; 
  { set first marker}
  if start >= 0 then firstshift := xunit * (1 - Frac (start / xunit) )
  else firstshift := - xunit * Frac (start / xunit);
  if firstshift < xunit then currentx := start + firstshift
  else currentx := start;
  if currentx >= 0 then stepcount := Round (10 * Frac (currentx / (10 * xunit) ) )
  else stepcount := 10 + Round (10 * Frac (currentx / (10 * xunit) ) );
  GetTextSettings (oldstyle);
  oldcolor := GetColor;
  SetTextStyle (style. font, horizdir, style. charsize);
  SetColor (color);
  if Abs (sinphi) < 0.5 then
  begin
    SetTextJustify (centertext, toptext);
    ymark := markline;
    xmark := 0;
  end
  else
    if x1 > x0 then
    begin
      SetTextJustify (lefttext, centertext);
      ymark := 0;
      xmark := markline;
    end
  else
  begin
    SetTextJustify (righttext, centertext);
    ymark := 0;
    xmark := - markline;
  end;
  Line (x0, y0, x1, y1);
  repeat
    decplaces := 5;
    labwidth := 2;
    if reallength > 0.00999 then decplaces := 4;
    if reallength > 0.0999 then decplaces := 3;
    if reallength > 0.999 then decplaces := 2;
    if reallength > 9.99 then decplaces := 1;
    if reallength > 99.9 then decplaces := 0;
    marker := scale * (currentx - start);
    MoveTo (Round (x0 + cosphi * marker), Round (y0 + sinphi * marker) );
    Line (GetX, GetY, GetX + xmark, GetY + ymark);
    if stepcount mod (divstep div 2) = 0 then
    begin
      LineRel (xmark + xmark, ymark + ymark);
      if stepcount mod divstep = 0 then
      begin
        if (decplaces < 4) and (reallength < 9999999)  then
          Str (currentx: labwidth: decplaces, valuelabel)
        else Str (currentx: 1, valuelabel);
        OutTextXY (GetX + 2 * xmark, GetY + 2 * ymark, valuelabel);
      end;
      MoveRel ( - 2 * xmark, - 2 * ymark);
    end;
    currentx := currentx + xunit;
    Inc (stepcount);
  until currentx > finish;
  SetTextStyle (oldstyle. font, oldstyle. direction, oldstyle. charsize);
  SetColor (oldcolor);
end;

destructor taxis. done;
begin end;

procedure trange. Reset;
begin
  if (start = st) and (finish = fin) then newset := false
  else
  begin
    newset := true;
    start := st;
    finish := fin;
    reallength := fin - start;
  end;
end;

{-----------------------------------------------------------------}
{                       TChannel methods                          }
{-----------------------------------------------------------------}
constructor tchannel. init;
begin
  x0     := X01;
  y0     := y01;
  x1     := X02;
  y1     := y02;
  xstart := 0;
  xend   := 0;
  xstep  := 0;
  yoffset:= 0;
  yoff   :=nil;
  datap  := nil;
  data   := nil;
  stickp := nil;
  sticks := nil;
  connected := false;
  dataon   := false;
  dots     := false;
  stickson := false;
end;

procedure tchannel. connect;
begin
  yoff  := newoffset;
  yoffset:=yoff^;
  startp:= start;
  xstart:= start^;
  endp  := finish;
  xend  := finish^;
  stepp := step;
  xstep := step^;
  datap := newdata;
  data  := datap^;
  stickp:= newsticks;
  sticks:= stickp^;
  maxindex := 1 + Trunc ( (xend - xstart) / xstep);
  connected := true;
  dataon  := true;
  if sticks<>nil then stickson:=true;
end;

procedure tchannel. disconnect;
begin
  connected := false;
  data  :=nil;
  sticks:=nil;
  stickp:=nil;
end;

procedure tchannel. draw;
var
  lowindex, hiindex, i, cx1, cx2, cy1, cy2, cx0,cy0 : longint;
  halfwidth,color                                   : word;
  cy, cx, cstep, cscale, chanshift                  : real;
  cstick                                            : pstick;
begin
  if not connected then Exit;
  if (hix < xstart) or (lowx > xend)  then Exit;
  if not (dataon or stickson) then exit;

  yoffset := yoff^;
  data    := datap^;
  sticks  := stickp^;
  xstart  := startp^;
  xend    := endp^;
  xstep   := stepp^;
  color   := getcolor;

  setfillstyle(solidfill,color);
  xrange. Reset (lowx, hix);
  yrange. Reset (lowy, hiy);
  cstep  := xstep * (x1 - x0) / xrange. reallength;
  cscale := (y0 - y1) / yrange. reallength;
  if xrange. start > xstart then
     begin
          cx := (xrange. start - xstart) / xstep;
          lowindex := 2 + Trunc (cx);
          cx := x0 + cstep * (1-Frac (cx));
     end
  else
     begin
          lowindex := 1;
          cx := x0 + cstep * (xstart - xrange. start) / xstep;
     end;

  if (data <> nil) and dataon then
  begin
    chanshift := yoffset - yrange.start;
    cy1 := trunc(y0 - cscale*chanshift);
    for i:=1 to trunc((x1-x0)/4) do putpixel(x0+4*i,cy1,color);
    cy  := y0 - cscale * (data^ [lowindex] + chanshift) ;
    cx2 := Trunc (cx);
    cy1 :=y0-2;
 
    { data drawing }
    while (cx2 < x1 - 1) and (lowindex < maxindex) do
    if dots then
    begin
         cy2 := round(cy);
         if (cy2 > y1) and (cy2 < cy1) then bar(cx2,cy2,cx2+1,cy2+1);
         cx  := cx + cstep;
         cx2 := Trunc (cx);
         Inc (lowindex);
         cy  := y0 - cscale * (data^ [lowindex] + chanshift);
    end
    else
    begin
         cy1 := round(cy);
         Inc (lowindex);
         cy  := y0 - cscale * (data^ [lowindex] + chanshift);
         cy2 := round(cy);
         cx1 := Trunc (cx);
         cx  := cx + cstep;
         cx2 := Trunc (cx);
         cx0 :=cx1;
         cy0 :=cy1;
         if cx2 > x1 - 1 then
         begin
              cy2  := cy2 + round((cy1-cy2) * (cx2-x1-1)/cstep);
              cx2  := x1 - 1;
         end;
         if not ( ( (cy1 <= y1) and (cy2 <= y1) ) or
                         ( (cy1 >= y0) and (cy2 >= y0) ) ) then
         begin
         if cy1 < y1 then
            begin
                 cx1 := cx1 + Round (cstep * (y1 - cy1) / (cy2 - cy1) );
                 cy1 := y1;
            end;
         if cy1 > y0 then
            begin
                 cx1 := cx1 + Round (cstep * (cy1 - y0) / (cy1 - cy2) );
                 cy1 := y0;
            end;
        if cy2 < y1 then
           begin
                cx2 := cx2 - Round (cstep * (y1 - cy2) / (cy1 - cy2) );
                cy2 := y1;
           end;
        if cy2 > y0 then
           begin
                cx2 := cx2 - Round (cstep * (cy2 - y0) / (cy2 - cy1) );
                cy2 := y0;
           end;

        if not ( (cy0 = y1) and (cy2 = y1) ) and (cx0 < x1) then
           Line (cx1, cy1, cx2, cy2);
      end {else} ;
    end {while} ;
  end;
  if not stickson then Exit;
  SetTextStyle (0, 0, 1);
  SetTextJustify (centertext, bottomtext);
  setcolor(color);
  cstick := sticks;
  cstep := (x1 - x0) / xrange. reallength;
  while cstick <> nil do
  begin
    if (cstick^. x >= xrange. start) and (cstick^. x <= xrange. finish) then
    begin
      cx1 := round (x0 + (cstick^. x - xrange. start) * cstep);
      cy1 := round (y0 - cscale*(yoffset - yrange.start));
      halfwidth:=textwidth(cstick^.name) div 2;
      if (cx1 > x0 + halfwidth) and (cx1 < x1 - halfwidth) then
             cstick^.draw (x0, x1, cy1, y1, xrange.start, cstep, cscale);
    end;
    cstick := cstick^. next;
  end;
  settextstyle(0,0,1);
  settextjustify(centertext,centertext);
end;

procedure tchannel.redraw;
begin
     draw(xrange.start,xrange.finish,yrange.start,yrange.finish);
end;

procedure tchannel.erase;
var oldcolor:word;
begin
     oldcolor:=getcolor;
     setcolor(white);
     redraw;
     setcolor(oldcolor);
end;

procedure tchannel. setbias;
begin
  yoffset := newbias;
end;

destructor tchannel. done;
begin
end;

{-----------------------------------------------------------------}
{                       TStick methods                            }
{-----------------------------------------------------------------}
constructor tstick. init;
begin
  x   := x0;
  y0  := y00;
  y1  := y10;
  xpx := 0;
  name := AName;
  next := nil;
end;

procedure tstick. chain;
begin
  if next <> nil then
  begin
    if next^. x < newstick^. x then next^. chain (newstick)
    else
    begin
      newstick^. next := next;
      next := newstick;
    end;
  end
  else next := newstick;
end;

procedure tstick.draw;
var
     ymark : integer;
begin
     xpx   := xpx0 + trunc((x-xz)*xscale);
     ymark := yzero - round(yscale*y0);
     if ymark < ymax+16 then ymark:=ymax+16;
     line(xpx,ymark,xpx,ymark-5);
     outtextxy(xpx,ymark - 8,name);
end;

destructor tstick. done;
begin
  if next <> nil then Dispose (next, done);
end;

{-----------------------------------------------------------------}
{                       TPlotter methods                          }
{-----------------------------------------------------------------}
constructor tplotter. init;
var i : integer;
begin
  tview. init;
  x1 := X01;
  X2 := X02;
  y1 := y01;
  y2 := y02;
  nchan:=numofchannels;
  if nchan > 15 then nchan:=15;
  name := header;
  height := y2 - y1;
  width := X2 - x1;
  TracerOn := false;
  oldtrace := true;
  getsettings;
  SetTextStyle (defaultfont, horizdir, 1);
  xaxis := New (paxis, init (x1 + TextWidth ('EEEEEEE'), y2 - 30,
                            X2 - 130, y2 - 30, 2, defaultfont, 1, black) );
  yaxis := New (paxis, init (xaxis^. x0, xaxis^. y0, xaxis^. x0,
                            y1 + 20, 2, defaultfont, 1, black) );
  buttonline:=xaxis^.x1+10;
  yaxzero   := yzero;
  if yaxzero > yaxis^.linlength then yaxzero:=yaxis^.linlength;
  xstart := 0;
  xend   := 100;
  ystart :=-100.0*yaxzero/yaxis^.linlength;
  yend   := 100 + ystart;
  for i:=1 to nchan do
  begin
       input[i]:=new(pchannel,
          init (xaxis^. x0 + 1, yaxis^. y0 - 1, xaxis^. x1, yaxis^. y1));
       buttons[1,i]:=New (pbutton, init (colors[i],@input[i]^.dataon ) );
       buttons[2,i]:=New (pbutton, init ('. ',@input[i]^.dots) );
       buttons[3,i]:=New (pbutton, init ('I ',@input[i]^.stickson) );
       put(buttons[1,i]);
       put(buttons[2,i]);
       put(buttons[3,i]);
  end;
  put (New (pbutton, init (' Trace   ', @TracerOn) ) );
  txdisp:=new (prealdial, init(' x ',6,@tracex));
  tydisp:=new (prealdial, init(' y ',6,@tracey));
  put(txdisp);
  put(tydisp);
  tracehandle:=nil;
  Tracex := 0;
  Tracey := 0;
  oldX  := 0;
  oldY  := 0;
end;


procedure tplotter. draw;
var
   i,butstep   :integer;
begin
  MoveTo (x1, y1);
  tview. draw;
  getsettings;
  callmouse (hidemouse);
  SetFillStyle (solidfill, white);
  SetColor (black);
  Bar (x1, y1, X2, y2);
  Rectangle (x1, y1, X2, y2);
  Rectangle (xaxis^. x0, xaxis^. y0, xaxis^. x1 + 1, yaxis^. y1 - 1);
  SetTextJustify (centertext, toptext);
  SetTextStyle (0, 0, 1);
  OutTextXY (Round ( (x1 + X2) / 2), y1 + 4, name);
  xaxis^. Reset (xstart, xend);
  yaxis^. Reset (ystart, yend);
  SetTextJustify (lefttext, toptext);
  butstep:=trunc(yaxis^.linlength/(nchan+1));
  if butstep > buttons[1,1]^.height+4 then
                                      butstep:=buttons[1,1]^.height+4;
  MoveTo (buttonline, yaxis^. y1);
  for i:=1 to nchan do
  begin
    focus:=buttons[1,i];
    focus^. draw;
    moveto(focus^.x2+2,focus^.y1);
    focus:=buttons[2,i];
    focus^. draw;
    moveto(focus^.x2+2,focus^.y1);
    focus:=buttons[3,i];
    focus^.draw;
    moveto(buttonline,focus^.y1+butstep);
  end;
  focus:=focus^.next;
  focus^.draw;
  moveto(buttonline,focus^.y1+butstep);
  focus:=txdisp;
  focus^.setcolors(black,lightgray);
  focus^.width:=buttons[1,1]^.width+buttons[2,1]^.width+buttons[3,1]^.width+4;
  focus^.draw;
  moveto(buttonline,focus^.y1+butstep);
  focus:=tydisp;
  focus^.setcolors(black,lightgray);
  tydisp^.width:=txdisp^.width;
  focus^.draw;

  restoresettings;
  callmouse (showmouse);
end;

procedure tplotter. run;
var i: integer;
begin
  getsettings;
  callmouse (hidemouse);
  SetFillStyle (solidfill, white);
  if (xstart <> xaxis^. start) or (xend <> xaxis^. finish) then
  begin
    Bar (x1 + 1, xaxis^. y0 + 1, X2 - 1, xaxis^.y0 + 20);
    xaxis^. Reset (xstart, xend);
  end;
  if (ystart <> yaxis^. start) or (yend <> yaxis^. finish) then
  begin
    Bar (x1 + 1, yaxis^. y1 - 4, yaxis^. x0 - 1, yaxis^. y0 + 4);
    yaxis^. Reset (ystart, yend);
  end;
  Bar (xaxis^. x0 + 1, yaxis^. y1, xaxis^. x1, yaxis^. y0 - 1);
  i:=1;
  repeat
      setcolor(i-1);
      if input [i]^.connected then
           input [i]^.draw (xstart, xend, ystart, yend);
      inc(i);
  until (i > nchan);
  restoresettings;
  callmouse (showmouse);
end;

procedure tplotter. redraw;
var i : integer;
begin
  for i := 1 to nchan do if input [i]^.connected then
  begin
    input [i]^.erase;
    setcolor(i-1);
    input [i]^.redraw;
  end;
end;

procedure tplotter. connect;
var i: word;
    first: boolean;
begin
  first:=true;
  for i:=1 to nchan do
     if input[i]^.connected and (i<>channel) then first:=false;
  {if new pattern is first and only, then views entire pattern}
  if first then
  begin
    xstart:=start^;
    xend  :=finish^;
    if maxy^ > yend then yend     := maxy^;
  end;
  input [channel]^.connect (start,finish,step,newoffset,newdata,newsticks);
end;

procedure tplotter.hidetrace;
begin
      callmouse(hidemouse);
      SetWriteMode (xorput);
      oldcolor:=getcolor;
      SetColor (white);
      Line (oldX, yaxis^. y0, oldX, yaxis^. y1);
      Line (xaxis^. x0, oldY, xaxis^. x1, oldY);
      SetWriteMode (normalput);
      setcolor(oldcolor);
      callmouse(showmouse);
end;

procedure tplotter. handlemouse;
var
  xshift, sshift, yshift, w : real;
begin
  if not ((mouse. x < xaxis^. x1) and (mouse. x > xaxis^. x0) and
         (mouse. y < yaxis^. y0) and (mouse. y > yaxis^. y1)) then exit;

  if not TracerOn then
  begin
    if tracehandle<>nil then  tracehandle^.active:=false;
    oldtrace :=false;
    if mouse. drag then
     begin
      yshift := 0;
      xshift := 0;
      sshift := 0;
      case mouse. buttondown of
        1: begin
                xshift := -mouse. xdrag / xaxis^. scale;
                sshift := -2.0 * mouse. ydrag / xaxis^. scale;
           end;
        2: yshift := mouse. ydrag / yaxis^. scale;
       end {case};
      w := 0.5 + (mouse. x - (xaxis^. x0 + xaxis^. x1) / 2) / xaxis^. linlength;
      xstart := xstart + xshift + w * sshift;
      xend  := xend   + xshift - (1 - w) * sshift;
      if xstart > xend then xend := xstart;
      if yend + yshift > 0 then  yend := yend + yshift;
      ystart := - yend*yaxzero/yaxis^.linlength;
      if ((xshift<>0) or (sshift<>0) or (yshift<>0)) then run;
     end;
  end;

  if TracerOn then
  case mouse.buttondown of
   1: begin
       if ( (oldX <> mouse. x) or (oldY <> mouse. y) )  then
         begin
           if OldTrace then hidetrace;
           getsettings;
           callmouse (hidemouse);
           SetWriteMode (xorput);
           SetColor (white);
           { draws new tracer }
           Tracex := xaxis^. start + (mouse. x - xaxis^. x0) / xaxis^. scale;
           Tracey := yaxis^. start + (yaxis^. y0 - mouse. y) / yaxis^. scale;
           Line (mouse. x, yaxis^. y0, mouse. x, yaxis^. y1);
           Line (xaxis^. x0, mouse. y, xaxis^. x1, mouse. y);
           oldX := mouse. x;
           oldY := mouse. y;
           oldtrace:=true;
           SetWriteMode (normalput);
           callmouse (showmouse);
           restoresettings;
           txdisp^.setdigits;    txdisp^.run;
           tydisp^.setdigits;    tydisp^.run;
         end;
      end;
   2: if tracehandle<>nil then
      begin
        event    := evnothing;
        keycode  := 0;
        tracehandle^.run;
      end;
   end {case};
   event   :=evnothing;
   keycode :=0;
end;

procedure tplotter.settracehandle;
begin
     tracehandle:=newhandle;
     chain(tracehandle);
end;

destructor tplotter.done;
var i : integer;
begin
     for i:=1 to nchan do dispose(input[i]);
     dispose(xaxis,done);
     dispose(yaxis,done);
     tview.done;
end;

end.
