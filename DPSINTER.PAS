{**************************************************************************}
{*  DPS 6.2 interface unit                                                *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}

unit dpsinter;
interface
uses Dos,GVMenus,GVMath;

const
   maxnpoints  = 10000;
   cmAddPeak   = $FF00;
   cmDelPeak   = $FF01;
   cmGetBg     = $FF02;
   cmChDrive   = $FF03;
   cmChDir     = $FF04;
   cmLoadPD3   = $FF05;
   cmSaveSetup = $FF06;
   cmFindPeaks = $FF07;
   cmSavePeaks = $FF08;
   cmCorrection= $FF09;
   cmclosepd3  = $FF0A;
   cmsetoffset = $FF0B;
   cmchangecolor = $FEF0;
   cmfitting   = $FF0C;

type
   ppeakeditor = ^tpeakeditor;
   tpeakeditor = object (tpulldownmenu)
        currentbg         : real;
        actcolor          : word;
        txt_tracex,txt_tracey : string[10];
        constructor init;
        procedure show; virtual;
        procedure activate; virtual;
        procedure handlekeyboard; virtual;
        procedure hide; virtual;
  end;

var

   npatterns                         : word;
   plot                              : tplotter;
   maindir,dpsdir                    : pathstr;
   radius                            : real;{ diffractometer radius in millimeters }
   ka2ka1                            : real;{ Ka2/Ka1 ratio}
   comport                           : longint;

   function datetime :string;
   function inradians(angle:real):real;
   procedure beep;

implementation
uses Crt,Graph,GVDial,GVDrive,DPSPD3;

constructor tpeakeditor. init;
var
   colmenu : ppulldownmenu;
   i       : integer;
begin
    colmenu:=new(ppulldownmenu,init('Active color'));
    for i:=1 to npatterns do
        colmenu^.put(new(pmenuitem,init(colors[i],cmchangecolor+i)));
    tpulldownmenu. init ('');
    txt_tracex:='          ';
    txt_tracey:='          ';
    put (colmenu);
    put (new (pmenuitem, init ('Set background', cmGetBg) ) );
    put (new (pmenuitem, init ('Add peak', cmAddPeak) ) );
    put (new (pmenuitem, init ('Delete peak', cmDelPeak) ) );
    currentbg:= 0;
    actcolor := 1;
end;

procedure tpeakeditor. show;
begin
    X1 := Mouse. X;
    y1 := Mouse. y;
    str(plot.tracex:8:4,txt_tracex);
    str(plot.tracey:8:1,txt_tracey);
    tpulldownmenu.show;
    active:=true;
    hidden:=false;
end;

procedure tpeakeditor. handlekeyboard;
var
    cp, dp : ppeak;
    tt, tt2: real;
    alabel : string[6];
begin
    if event=evkeyboard then
    case keycode of
       (cmchangecolor+1)..(cmchangecolor+15)
                 : begin
                        actcolor:=keycode-cmchangecolor;
                        child^.setcolors(actcolor-1,white);
                        child^.hide;
                        event   :=evnothing;
                   end;
       cmAddPeak : if (pd3pat[actcolor]<>nil) and
                      (pd3pat[actcolor]^.peaks<>nil) then
                   begin
                        tt:=plot.tracex;
                        tt2:=360/pi*arcsin(sin(tt*pi/360)*
                               pd3pat[actcolor]^.alpha2/pd3pat[actcolor]^.alpha1);
                        str(pd3pat[actcolor]^.dlat(tt):6:3,alabel);
                        if tt > pd3pat[actcolor]^.peaks^.x then
                        begin
                             cp:=(new (ppeak,init
                             (tt, tt2, 0.2, plot. tracey - currentbg, alabel) ) );
                             cp^.y0:=cp^.height;
                             pd3pat[actcolor]^.peaks^. chain(cp);
                        end
                        else
                        begin
                             dp:=pd3pat[actcolor]^.peaks;
                             cp:=(new (ppeak,init
                             (tt, tt2, 0.2, plot. tracey - currentbg, alabel) ) );
                             cp^.y0:=cp^.height ;
                             pd3pat[actcolor]^.peaks:=cp;
                             pd3pat[actcolor]^.peaks^.chain(dp);
                        end;
                        hide;
                        setcolor(actcolor-1);
                        plot.input[actcolor]^.redraw;
                    end;
      cmDelPeak :  if (pd3pat[actcolor]<>nil) and
                      (pd3pat[actcolor]^.peaks<>nil) then
                  begin
                       plot.input[actcolor]^.erase;
                       cp := pd3pat[actcolor]^.peaks;
                       dp := pd3pat[actcolor]^.peaks;
                       while cp <> nil do
                       begin
                            if abs (cp^. x - plot. tracex) < 0.05 then
                                begin
                                     if cp=pd3pat[actcolor]^.peaks then
                                        begin
                                         pd3pat[actcolor]^.peaks:=@cp^.next^;
                                         dispose(cp);
                                        end
                                        else
                                        begin
                                             dp^.next := cp^. next;
                                             dispose (cp);
                                             cp:=dp;
                                        end
                                 end;
                            dp := cp;
                            cp := @cp^. next^;
                       end;
                       hide;
                       setcolor(actcolor-1);
                       plot.input[actcolor]^.redraw;
                  end;
      cmGetBg   : begin
                       currentbg := plot. tracey;
                       hide;
                       event := evnothing;
                  end;
        end;
      tpulldownmenu. handlekeyboard;
end;

procedure tpeakeditor.activate;
begin
     active:=true;
end;

procedure tpeakeditor.hide;
begin
     tpulldownmenu.hide;
     active:=false;
     hidden:=true;
end;

{*}  function Datetime:string;
const
   mon :array[1..12] of string=('January','February','March','April','May',
      'June','July','August','September','October','November','December');
var
      ys,ms,ds,dws,hs,mins,ss,cs      :word;
      d,y,m,dw,h,min,s,c,data         :string[30];
   begin
      GetDate(ys,ms,ds,dws);
      GetTime(hs,mins,ss,cs);
      str(ds,d);str(ys,y);str(ms,m);str(dws,dw);
      str(hs,h);str(mins,min);str(ss,s);str(cs,c);
      data:=' '+d+'-'+mon[ms]+'-'+y+'    ';
      if hs<10 then data:=data+'0';
      data:=data+h+':';
      if mins<10 then data:=data+'0';
      data:=data+min+':';
      if ss<10 then data:=data+'0';
      data:=data+s+'  ';
      datetime:=data;
   end;

{*}  Function InRadians ( angle : real ) : real;
     begin
          InRadians:=Pi*angle/180;
     end;

procedure beep;
begin
     sound(5000);
     delay(10);
     nosound;
end;
end.