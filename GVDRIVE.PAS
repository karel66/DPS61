{**************************************************************************}
{*  GVision Mouse driver & event handling unit                            *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}
unit gvdrive;
interface
type
    preal      = ^real;
    ppreal     = ^preal;
    plongint   = ^longint;
    pplongint  = ^plongint;
    pstring    = ^string;
    ppstring   = ^pstring;
    pchar      = ^char;
    pboolean   = ^boolean;
    p2boolean  = ^pboolean;
    Str32      = string[32];

const
         Ln10    = 2.302585;
         cmEnter = 7181;
         cmesc  = 283;
         cmbs   = 3592;
         cmdown = 20480;
         cmup   = 18432;
         cmleft = 19200;
         cmright = 19712;
         cmpgup = 18688;
         cmpgdn = 20736;
         cmhome = 18176;
         cmend  = 20224;
         cmins  = 20992;
         cmdel  = 21248;
         cmtab  = 3849;
         cmf1   = 15104;
         cmf2   = 15360;
         cmf3   = 15616;
         cmf4   = 15872;
         cmf5   = 16128;
         cmf6   = 16384;
         cmf7   = 16640;
         cmf8   = 16896;
         cmf9   = 17152;
         cmf10  = 17408;
         cmAltX = 11520;
         
         evnothing     = 0;
         evMouse       = 1;
         evkeyboard    = 2;
         
         showMouse    = 1;
         hideMouse    = 2;
         checkMouse   = 3;
         setcursor    = 4;
         setxrange    = 7;
         setyrange    = 8;
         setstyle     = 9;
         resetMouse   = 0;
var
         grMode, grDrive, gMaxX, gMaxY : integer;
         Event  : word;
         keycode: word;
         Mouse  : record
                           buttondown,lbutton, rbutton : integer;
                           x,y,oldx,oldy,xDrag,yDrag   : integer;
                           dblclick,drag               : boolean;
                  end;
         
procedure GetEvent;
procedure CallMouse (task: word);

implementation
uses crt, dos, graph;
const
         arrowData : array [0..31] of word =
         ($3FFF, $1FFF, $0FFF, $07FF, $03FF, $01FF, $00FF, $007F, $003F, $001F, $01FF,
         $11FF, $30FF, $78FF, $F87F, $FCFF,
         $0000, $4000, $6000, $7000, $7800, $7C00, $7E00, $7F00, $7F80, $7C00,
         $6C00, $4400, $0600, $0200, $0300, $0000);
         
var
         regs      : registers;
         longx, longy : longint;
         
procedure GetMouseEvent;
begin
     with Mouse do
         begin
                  {check position and buttons}
                  regs. ax := 3;
                  intr ($33, regs);
                  buttondown := regs. bx and 3;
                  x := regs. cx;
                  y := regs. dx;
                  
                  {check left button clicks}
                  regs. ax := 5;
                  regs. bx := 0;
                  intr ($33, regs);
                  lbutton := regs. bx;
                  
                  {check right button clicks}
                  regs. ax := 5;
                  regs. bx := 1;
                  intr ($33, regs);
                  rbutton  := regs. bx;

                  if (lbutton > 1) or (rbutton > 1) then dblclick := true
                                                       else dblclick := false;

                  {check mouse drag}
                  case buttondown of
                           0   : begin
                                    drag  := false;
                               
                                    xdrag := 0;
                                    ydrag := 0;
                                  end;
                          1..3 : if (lbutton + rbutton = 0) then
                                  begin
                                    if not drag then drag:=true;
                                    xdrag:=x-oldx;
                                    ydrag:=y-oldy;
                                  end;
                  end;
             oldx  := x;
             oldy  := y;
         end;
end;

procedure CallMouse (task: word);
begin
         regs. ax := task;
         intr ($33, regs);
end;

function getscancode: word;
begin
         regs. ah := 0;
         intr ($16, regs);
         getscancode := regs. ax;
end;

procedure GetEvent;
begin
         getmouseevent;
         if Mouse. buttondown + Mouse. lbutton + Mouse. rbutton > 0
            then Event := evMouse;
         if keypressed then
         begin
            Event   := evkeyboard;
            keycode := getscancode;
         end;
end;

begin
         detectgraph (grMode, grDrive);
         initgraph (grMode, grDrive, '');
         gmaxx := getmaxx;
         if gmaxx > 1024 then writeln('Graphics error: maxx');
         gmaxy := getmaxy;
         if gmaxy > 1024 then writeln('Graphics error: maxy');
         setrgbpalette (cyan, $00, $EE, $F1);
         setrgbpalette (lightgray, $EE, $EE, $EE);
         regs. bx := 0;
         regs. cx := 0;
         regs. dx := ofs (ArrowData);
         regs. es := seg (ArrowData);
         CallMouse (setstyle);
         {set x-y range}
         regs. cx := 1;
         regs. dx := gmaxx - 1;
         CallMouse (setxrange);
         regs. cx := 1;
         regs. dx := gmaxy - 1;
         CallMouse (setyrange);
         CallMouse (showmouse);
         CallMouse (checkmouse);
         Mouse. oldx :=regs.cx;
         Mouse. oldy :=regs.dx;
         GetMouseEvent;
         Mouse. drag    := false;
         Mouse. lbutton := 0;
         Mouse. rbutton := 0;
end.