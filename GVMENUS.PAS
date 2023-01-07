{**************************************************************************}
{*  GVision menus unit.                                                   *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}

unit gvmenus;
interface
uses Graph,GVDrive,GVViews;
type
         PWindow = ^TWindow;
         TWindow = object
                  X1,y1,X2,y2  :integer;
                  oldcolor     :word;
                  oldfill      :fillsettingstype;
                  back         :pointer;
                  area         :word;
                  hidden       :boolean;
                  procedure open (X,y,AWidth,AHeight,AColor :word);
                  procedure close;
         end;
         
         Pmessagebox=^Tmessagebox;
         tmessagebox= object (twindow)
                  procedure init (Amessage: string);
         end;

         PMenuItem=^TMenuItem;
         TMenuItem= object (tView)
                  Ycenter         : integer;
                  style           : textsettingstype;
                  constructor init (AName : string; AMessage : word);
                  procedure handlekeyboard ; virtual;
                  procedure handlemouse    ; virtual;
                  procedure draw; virtual;
                  procedure activate; virtual;
                  procedure normalize; virtual;
                  procedure hide; virtual;
                  procedure setstyle (AFont,ADirection,ASize:word);
         end;
         
         PMenu=^TMenu;
         TMenu= object (TMenuItem)
                  xstep,ystep,
                  xWin,yWin,
                  WinHeight,WinWidth      : integer;
                  columns                 : word;
                  constructor Init (AName : string);
                  procedure setwindow;     virtual;
                  procedure setcolumns (nofcolumns : word);
                  procedure normalize; virtual;
                  procedure run;  virtual;
                  procedure show; virtual;
                  procedure hide; virtual;
         end;
         
         PPullDownMenu=^Tpulldownmenu;
         TPulldownMenu= object (tmenu)
                  window : pwindow;
                  constructor Init(AName:string);
                  procedure run; virtual;
                  procedure show; virtual;
                  procedure hide; virtual;
                  destructor done;virtual;
         end;
         
         PMenuBar=^TMenuBar;
         TMenuBar= object (TView)
                  xstep : word;
                  constructor Init(y :word);
                  procedure draw; virtual;
                  procedure show; virtual;
                  procedure hide; virtual;
         end;
         
         pscrollmenu=^tscrollmenu;
         tscrollmenu= object (tpulldownmenu)
                  upmark,downmark : pview;
                  lines           : word;
                  top,bottom      : integer;
                  constructor init(aname:string; ALinesNumber: word);
                  procedure handleevent; virtual;
                  procedure handlekeyboard; virtual;
                  procedure setwindow;      virtual;
                  procedure show;           virtual;
                  procedure hide;           virtual;
                  destructor done; virtual;
         end;
         
function convstr(stringval:string):real;
procedure showmessage(amessage:string);

implementation
uses dos,Crt;
var
         c     :word;
         regs  :registers;
         
         (* TWindow methods *)
procedure TWindow.open;
var block : longint;
begin
         CallMouse(hidemouse);
         X1:=X;
         y1:=y;
         if awidth > gmaxx then awidth:=gmaxx-2;
         if aheight > gmaxy then aheight:=gmaxy-2;
         X2:=X1+awidth;
         y2:=y1+aheight;
         if X2 > gmaxx then X1:=gmaxx-awidth-2;
         if y2 > gmaxy then y1:=gmaxy-aheight-2;
         X2:=X1+awidth;
         y2:=y1+aheight;
         oldcolor:=getcolor;
         getfillsettings(oldfill);
         area:=imagesize(X1,y1,X2,y2);
         if area > memavail then
            begin
                 y2:=y2 div (1+(area div memavail));
                 area:=imagesize(X1,y1,X2,y2);
            end;
         getmem(back,area);
         getimage(X1,y1,X2,y2,back^);
         setfillstyle(solidfill,AColor);
         Bar(X1,y1,X2,y2);
         setcolor(white);
         line(X1+1,y1+1,X2-2,y1+1);
         line(X1+1,y1+1,X1+1,y2-2);
         setcolor(lightgray);
         rectangle(X1,y1,X2,y2);
         setcolor(black);
         line(X1+1,y2,X2,y2);
         line(X1+2,y2-1,X2,y2-1);
         setcolor(darkgray);
         line(X2,y1+1,X2,y2);
         line(X2-1,y1+2,X2-1,y2);
         setcolor(oldcolor);
         setfillstyle(oldfill.pattern,oldfill.color);
         CallMouse(showmouse);
         hidden:=false;
end;

procedure TWindow.close;
begin
     if not hidden then
      begin
         CallMouse(hidemouse);
         putimage(X1,y1,back^,normalput);
         if back<>nil then freemem(back,area);
         CallMouse(showmouse);
         hidden:=true;
      end;
end;

{* messagebox *}
procedure tmessagebox.init;
var   w,h  : word;
begin
         w:=textwidth(amessage)+10;
         h:=round(1.1*textheight(amessage))+10;
         open((gmaxx-w)div(2),(gmaxy-h)div(2),w,h,lightcyan);
         setcolor(black);
         settextjustify(lefttext,centertext);
         outtextxy(X1+5,y1+(h shr 1),amessage);
end;

{ tmenuitem methods }
constructor tmenuitem.init;
begin
         tview.init;
         name  :=aname;
         message:=amessage;
         gettextsettings(style); (* current style *)
         width :=textwidth(' '+name+' ');
         height:=trunc(1.5*textheight(name));
         fgcolor:=black;
         bgcolor:=cyan;
end;

procedure tmenuitem.handlekeyboard;
begin
         if active and not hidden then
                  case keycode of
                           cmenter : 
                           begin
                                    run;
                                    keycode:=message;
                           end;
                           cmesc : 
                           begin
                                    if (child<>nil) and not child^.hidden then hide;
                                    if parent<>nil then  parent^.hide;
                                    event :=evnothing;
                                    keycode:=0;
                           end;
                           cmdown,cmright  :
                           begin
                                    if parent=@self then exit;
                                    if (next<>nil) and not next^.hidden then
                                    begin
                                             next^.activate;
                                             event:=evnothing;
                                             keycode:=0;
                                    end;
                                    if (next=nil) and (not parent^.child^.hidden) then
                                    begin
                                             parent^.child^.activate;
                                             event:=evnothing;
                                             keycode:=0;
                                    end;
                           end;
                           cmup,cmleft    :
                           begin
                                    if parent=@self then exit;
                                    focus:=parent^.child;
                                    if focus <> @self then
                                             while (focus^.next<>@self) and (focus<>nil)
                                             do focus:=focus^.next
                                    else
                                             while focus^.next<>nil do focus:=focus^.next;
                                    if not focus^.hidden then
                                    begin
                                             focus^.activate;
                                             event:=evnothing;
                                             keycode:=0;
                                    end;
                           end;
                  end;
end;

procedure tmenuitem.handlemouse;
begin
         if (mouse.lbutton > 0) or (mouse.buttondown=1) then
         begin
                  if mousein then
                           if active and (mouse.lbutton > 0) then
                           begin
                                    run;
                                    Event:=evkeyboard;
                                    keycode:=message;
                           end
                  else
                  begin
                           activate;
                           Event:=evnothing;
                           keycode:=0;
                  end
                  else hide;
         end;
         if mouse.rbutton > 0 then hide;
end;

procedure tmenuitem.setstyle;
begin
         style.font      :=afont;
         style.direction :=adirection;
         style.charsize  :=asize;
         width :=textwidth(' '+name+' ');
         height:=trunc(1.5*textheight(name));
end;

procedure tmenuitem.draw;
begin
         tview.draw;
         CallMouse(hidemouse);
         X2:=X1+width;
         if X2 > gmaxx then X2:=gmaxx;
         y2:=y1+height;
         Ycenter:=y1+1+round(0.4*height);
         if y2 > gmaxy then y2:=gmaxy;
         getsettings;
         setfillstyle(solidfill,bgcolor);
         Bar(X1,y1,X2,y2);
         settextstyle(style.font,style.direction,style.charsize);
         settextjustify(lefttext,centertext);
         if active then
         begin
                  if bgcolor<>white then setcolor(white)
                  else setcolor(lightgray);
                  line(X1,y1,X2,y1);
                  line(X1,y1,X1,y2);
                  setcolor(black);
                  line(X1+1,y2,X2,y2);
                  line(X2,y1+1,X2,y2);
         end;
         setcolor(fgcolor);
         moveto(X1,Ycenter);
         outtext(' '+name+' ');
         CallMouse(showmouse);
         restoresettings;
end;

procedure tmenuitem.activate;
begin
         if parent<>nil then focus:=parent^.child
                                                 else focus:=nil;
         while focus<>nil do
         begin
              if (focus^.active) and (focus<>@self) then focus^.normalize;
              focus:=focus^.next;
         end;
         tview.activate;
         CallMouse(hidemouse);
         getsettings;
         X2:=X1+width;
         y2:=y1+height;
         if bgcolor<>white then setcolor(white)
         else setcolor(lightgray);
         line(X1,y1,X2,y1);
         line(X1,y1,X1,y2);
         setcolor(black);
         line(X1+1,y2,X2,y2);
         line(X2,y1+1,X2,y2);
         restoresettings;
         CallMouse(showmouse);
end;

procedure tmenuitem.normalize;
begin
         if active and not hidden then
         begin
                  CallMouse(hidemouse);
                  getsettings;
                  setcolor(bgcolor);
                  rectangle(X1,y1,X2,y2);
                  restoresettings;
                  CallMouse(showmouse);
         end;
         tview.normalize;
end;

procedure tmenuitem.hide;
begin
         { menuitem hide attribute must be set by parent hide method
         because of tscrollmenu mouse handling }
end;

(* tmenu *)
constructor Tmenu.init;
begin
         tmenuitem.init(AName,0);
         columns  :=1;
         xstep    :=0;
         ystep    :=0;
         xWin     :=0;
         yWin     :=0;
         winwidth :=0;
         winheight:=0;
end;

procedure tmenu.setcolumns;
begin
     if nofcolumns > 0 then columns:=nofcolumns;
end;

procedure tmenu.run;
begin
         if (child<>nil) and child^.hidden then show;
end;

procedure tmenu.setwindow;
begin
         focus:=child;
         while focus<>nil do
         begin
                  with focus^ do
                  begin
                           if width > xstep then xstep:=width;
                           if height > ystep then ystep:=height;
                  end;
                  focus:=focus^.next;
         end;
         xWin:=X1+textwidth(' ');
         winwidth:= 8 + columns*xstep;
         if xwin+winwidth > gmaxx then xWin:=gmaxx-winwidth;
         if xwin < 0 then xwin:=0;
         yWin:=y1+height;
         winheight:= 8 + ystep*child^.count div columns;
         if ywin+winheight > gmaxy then yWin:=gmaxy-winheight;
         if yWin < 0 then yWin:=0;
end;

procedure tmenu.show;
var
   yrow,xcol,n,rows   : word;
begin
         setwindow;
         yrow :=yWin+4;
         xcol :=xwin+4;
         focus:=child;
         rows:=focus^.count div columns;
         n:=0;
         while focus <> nil do
         begin
               inc(n);
               if n = rows+1 then
                 begin
                      yrow:=ywin+4;
                      xcol:=xwin+xstep+2;
                 end;
                  moveto(xcol,yrow);
                  yrow:=yrow+ystep;
                  with focus^ do
                  begin
                           width :=xstep;
                           height:=ystep;
                           parent:=@self;
                           draw;
                  end;
                  focus:=focus^.next;
         end;
         focus:=child;
         while (focus<>nil) and not focus^.active do focus:=focus^.next;
         if focus<>nil then focus^.activate else child^.activate;
end;

procedure tmenu.hide;
begin
         focus:=child;
         while focus<>nil do
         begin
                  focus^.hide;
                  focus^.hidden:=true;
                  focus:=focus^.next;
         end;
end;

procedure tmenu.normalize;
begin
         hide;
         tmenuitem.normalize;
end;

{ PullDownMenu }
constructor tpulldownmenu.init;
begin
         tmenu.init (AName);
         new(window);
         window^.hidden:=true;
end;

procedure tpulldownmenu.run;
begin
         if window^.hidden then show;
end;

procedure tpulldownmenu.show;
begin
         setwindow;
         window^.open(xWin,yWin,winwidth,winheight,bgcolor);
         tmenu.show;
end;

procedure tpulldownmenu.hide;
begin
         if not window^.hidden then
         begin
                  tmenu.hide;
                  window^.close;
         end;
end;

destructor tpulldownmenu.done;
begin
         hide;
         dispose(window);
         tview.done;
end;

{ MenuBar }
constructor tMenuBar.init;
begin
         tview.init;
         X1:=1;
         y1:=y;
end;

procedure tmenubar.draw;
begin
         hidden:=false;
         show;
end;

procedure tmenubar.hide;
begin
         focus:=child;
         while focus <> nil do
         begin
                  if focus^.active then focus^.normalize;
                  focus:=focus^.next;
         end;
end;

procedure tmenubar.show;
var
         selected  : word;
begin
         active:=true;
         hidden:=false;
         callmouse(hidemouse);
         getsettings;
         xstep:=trunc(gmaxx/child^.count);
         focus  :=child;
         selected :=X1+2;
         while focus <> nil do
         begin
                  moveto(selected,y1+1);
                  selected:=selected+xstep;
                  focus^.width:=xstep;
                  if focus^.height > height then height:=focus^.height;
                  focus^.draw;
                  focus:=focus^.next;
         end;
         setcolor(black);
         y2:=y1+height+2;
         X2:=gmaxx-1;
         rectangle(X1,y1,X2,y2);
         restoresettings;
         callmouse(showmouse);
         if child<>nil then child^.activate;
end;

{ scrollmenu }
constructor tscrollmenu.init;
begin
         tpulldownmenu.init(aname);
         upmark:=new(pmenuitem,init(' Page up ',cmPgUp));
         downmark:=new(pmenuitem,init(' Page down',cmPgDn));
         lines:=ALinesNumber;
         top:=1;
         bottom:=top+lines-1;
         xstep:=downmark^.width;
         upmark^.width:=xstep;
end;
procedure tscrollmenu.setwindow;
begin
     tmenu.setwindow;
     yWin:=y1+height;
     winheight:= 8 + ystep*(lines+2);
     if ywin+winheight > gmaxy then yWin:=gmaxy-winheight;
     if yWin < 0 then yWin:=0;
end;

procedure tscrollmenu.show;
var
         last,activated,scroll : pview;
         selected              : word;
begin
         activated:=nil;
         setwindow;
         if window^.hidden then
         begin
                  window^.open(xWin,yWin,winwidth,winheight,bgcolor);
                  moveto(xwin+4,ywin+4);
                  upmark^.width:=xstep;
                  upmark^.draw;
                  upmark^.activate;
                  moveto(xwin+4,window^.y2-ystep-2);
                  downmark^.width:=xstep;
                  downmark^.draw;
                  downmark^.activate;
                  focus :=child;
                  while focus<>nil do
                  begin
                           with focus^ do
                           begin
                                    width:=xstep;
                                    height:=ystep;
                           end;
                           focus :=focus^.next;
                  end;
         end;
         focus :=child;
         while focus<>nil do
         begin
                  focus^.hidden:=true;
                  focus :=focus^.next;
         end;
         focus       :=child^.get(top);
         last        :=child^.get(bottom);
         selected    :=upmark^.y2+1;
         while (focus <> nil) and (focus<>last^.next) do
         begin
                  moveto(xWin+4,selected);
                  focus^.draw;
                  if focus^.active then activated:=focus;
                  focus:=focus^.next;
                  inc(selected,ystep);
         end;
         if (activated=nil) and (child<>nil) then child^.get(top)^.activate;
end;

procedure Tscrollmenu.HandleEvent ;
begin
         if child<>nil then child^.handleevent;
         if not window^.hidden then
         begin
                  upmark^.handleevent;
                  downmark^.handleevent;
         end;
         if next<>nil  then next^.handleevent;
         if (event <> evNothing) and not hidden then
         begin
                  case Event of
                           evmouse    : handlemouse;
                           evkeyboard : if active then handlekeyboard;
                  end;
         end;
end;

procedure tscrollmenu.handlekeyboard;
begin
         if not window^.hidden then
         begin
                  case keycode of
                           cmup   : if child^.get(top)^.active then
                           begin
                                    if top > 1 then
                                    begin
                                             dec(top);
                                             dec(bottom);
                                             show;
                                    end;
                                    event:=evNothing;
                                    keycode:=0;
                           end;
                           cmdown : if child^.get(bottom)^.active then
                           begin
                                    if bottom < child^.count then
                                    begin
                                             inc(top);
                                             inc(bottom);
                                             show;
                                    end;
                                    event:=evNothing;
                                    keycode:=0;
                           end;
                           cmPgDn: if not child^.get(child^.count)^.active then
                           begin
                                    bottom:=bottom+lines;
                                    if bottom > child^.count then bottom:=child^.count;
                                    top:=bottom-lines+1;
                                    if top < 1 then top:=1;
                                    show;
                                    child^.get(bottom)^.activate;
                                    event:=evNothing;
                                    keycode:=0;
                           end;
                           cmPgUp: if not child^.active then
                           begin
                                    top:=top-lines;
                                    if top < 1 then top:=1;
                                    bottom:=top+lines-1;
                                    if bottom > child^.count then bottom:=child^.count;
                                    show;
                                    child^.get(top)^.activate;
                                    event:=evNothing;
                                    keycode:=0;
                           end;
                  end;{case}
         end
         else tmenuitem.handlekeyboard;
end;

procedure tscrollmenu.hide;
begin
         tpulldownmenu.hide;
         upmark^.hidden:=true;
         downmark^.hidden:=true;
end;

destructor tscrollmenu.done;
begin
         dispose(upmark,done);
         dispose(downmark,done);
         tpulldownmenu.done;
end;

function convstr;
var
         code:integer;
         X   :real;
         mess:tmessagebox;
begin
     while pos(' ',stringval) > 0 do delete(stringval,pos(' ',stringval),1);
     val(stringval,X,code);
     if code<>0 then
       begin
                  mess.init(' Can''t convert <'+stringval+'> to a number !');
                  repeat until keypressed;
                  mess.close;
                  convstr:=code;
                  exit;
       end;
     convstr:=X;
end;

procedure showmessage;
var
   box    : tmessagebox;
   oldkey : word;
   oldev  : word;
begin
    oldev := event;
    oldkey:= keycode;
    event := evnothing;
    box.init(amessage);
    repeat getevent until event > evnothing;
    box.close;
    event :=oldev;
    keycode:=oldkey;
end;

end.