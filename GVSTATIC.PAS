{**************************************************************************}
{*  GVision static objects.                                               *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}
unit gvstatics;
interface
uses Graph,gvdrive,gvviews,gvmenus;
type
      plistitem = ^tlistitem;
      tlistitem = object (tview)
                  namefield,ownerfield,X3,yc  : integer;
                  oldtext                     : string;
                  constructor init (AName: str32; namewidth:word;
                                   AOwner:pstring; ownerwidth:word);
                  procedure draw; virtual;
                  procedure handleevent; virtual;
                  procedure refresh;
         end;

         plistbox=^tlistbox;
         tlistbox= object (tview)
                  constructor init (left,right : word);
                  procedure draw;virtual;
                  procedure run;virtual;
         end;

         pcontrol= ^tcontrol;
         tcontrol= object (tview)
                  switch    : pboolean;
                  state     : boolean;
                  constructor init (ASwitch:pboolean);
                  procedure draw; virtual;
                  procedure run; virtual;
                  procedure show; virtual;
                  procedure handlemouse; virtual;
         end;
         
         pLED   = ^tLED;
         tLED   = object (tcontrol)
                  color :word;
                  constructor init (AColor:word; ASwitch:pboolean);
                  procedure show; virtual;
         end;
         
         pButton= ^tButton;
         tButton= object (tcontrol)
                  constructor init (AName:str32; ASwitch:pboolean);
                  procedure show; virtual;
         end;
         
implementation
{ tlistitem }
constructor tlistitem.init;
begin
         getsettings;
         settextstyle(smallfont,horizdir,5);
         tview.init;
         fgcolor:=black;
         bgcolor:=lightgray;
         if owner<>nil then oldtext   :=owner^
            else oldtext:=' ';
         owner     :=AOwner;
         name      :=AName;
         height    :=textheight(name)+8;
         namefield :=namewidth*textwidth('B');
         ownerfield:=ownerwidth*textwidth('B');
         width     :=namefield + ownerfield + textwidth(' ');
         restoresettings;
end;

procedure tlistitem.draw;
begin
         tview.draw;
         active:=true;
         callmouse(hidemouse);
         getsettings;
         settextstyle(smallfont,horizdir,5);
         settextjustify(lefttext,centertext);
         setfillstyle(solidfill,bgcolor);
         setcolor(fgcolor);
         X3:=X1+namefield;
         X2:=X1+width;
         y2:=y1+height;
         yc:=(y1 + y2) shr 1;
         Bar(X1,y1,X2,y2);
         setcolor(white);
         line(X3,y2-1,X2-3,y2-1);
         line(X2-3,y2-1,X2-3,y1+2);
         setcolor(darkgray);
         line(X2-3,y1+2,X3,y1+2);
         line(X3,y1+2,X3,y2-2);
         setcolor(black);
         moveto(X1,yc);
         outtext(name);
         moveto(X3,yc);
         if owner<>nil then
            begin
                 oldtext:=owner^;
                 while textwidth(oldtext) > ownerfield do
                                           delete(oldtext,length(oldtext),1);
                 if pos(' ',oldtext) <> 1 then outtext(' ');
                 outtext(oldtext);
                 oldtext:=owner^;
            end;
         restoresettings;
         callmouse(showmouse);
end;

procedure tlistitem.refresh;
begin
         if owner=nil then exit;
         callmouse(hidemouse);
         getsettings;
         settextstyle(smallfont,horizdir,5);
         settextjustify(lefttext,centertext);
         setfillstyle(solidfill,bgcolor);
         oldtext:=owner^;
         while textwidth(oldtext) > ownerfield do
                  delete(oldtext,length(oldtext),1);
         Bar(X3+1,y1+3,X2-4,y2-3);
         setcolor(fgcolor);
         moveto(X3,yc);
         if pos(' ',oldtext) <> 1 then outtext(' ');
         outtext(oldtext);
         oldtext:=owner^;
         restoresettings;
         callmouse(showmouse);
end;

procedure tlistitem.handleevent;
begin
     if (owner<>nil) and (event <> evnothing) then
                     if (owner^ <> oldtext) then refresh;
     tview.handleevent;
end;

{ listbox }
constructor tlistbox.init;
begin
         tview.init;
         X1:=left;
         X2:=gmaxx-right;
         width:=X2-X1;
         fgcolor:=black;
         bgcolor:=lightgray;
end;

procedure tlistbox.draw;
var
         pline,pcol               : pview;
         X,column,wd,wd1,i,maxh   : integer;
begin
         callmouse(hidemouse);
         getsettings;
         setfillstyle(solidfill,bgcolor);
         settextstyle(smallfont,horizdir,5);
         settextjustify(lefttext,centertext);
         setcolor(fgcolor);
         y1:=gety;
         maxh:=1;
         pline:=child;
         while pline<>nil do
               begin
                    if pline^.height > maxh then maxh:=pline^.height;
                    pline:=pline^.next;
               end;
         pline:=child;
         y2:=y1+2;
         while (y2 + pline^.height < gmaxy) and (pline<>nil) do
         begin
                  Bar(X1,y2,X2,y2+maxh);
                  pcol:=pline;
                  wd:=0;
                  wd1:=0;
                  column:=0;
                  repeat
                        wd1:=pcol^.width;
                        inc(wd,wd1);
                        inc(column);
                        pcol:=pcol^.next
                  until (wd > width) or (pcol=nil);
                  if (column > 1) and (pcol<>nil) then
                  begin
                           dec(column);
                           dec(wd,wd1);
                  end;
                  wd:=trunc((width-wd)/column)-1;
                  X:=X1+1;
                  pcol:=pline;
                  for i:=1 to column do
                  begin
                           moveto(X,y2);
                           inc(pcol^.width,wd);
                           pcol^.draw;
                           inc(X,pcol^.width);
                           pcol:=pcol^.next;
                  end;
                  inc(y2,maxh);
                  pline:=pcol;
         end;
         inc(y2);
         height:= y2-y1;
         setcolor(black);
         rectangle(x1,y1,x2,y2);
         restoresettings;
         callmouse(showmouse);
end;

procedure tlistbox.run;
var
   cl : pview;
begin
     cl:=@child^;
     while cl<>nil do
           begin
                cl^.handleevent;
                cl:=@cl^.next^;
           end;
end;


constructor tcontrol.init;
begin
         tview.init;
         state  :=false;
         switch :=aswitch;
         if switch<>nil then state :=switch^;
end;

procedure tcontrol.draw;
begin
         tview.draw;
         show;
end;

procedure tcontrol.show;
begin
end;

procedure tcontrol.run;
begin
         if switch=nil then exit;
         switch^:=not switch^;
         state  :=switch^;
         show;
end;

procedure tcontrol.handlemouse;
begin
         if (switch=nil) or hidden then exit;
         if state<>switch^ then
         begin
                  show;
                  state:=switch^;
         end;
         if mousein and (mouse.lbutton > 0)  then
         begin
                  run;
                  event:=evNothing;
                  keycode:=0;
         end;
end;

constructor tLED.init;
begin
         tcontrol.init(ASwitch);
         color:=AColor;
         width:=10;
         height:=6;
end;

procedure tLED.show;
begin
         getsettings;
         callmouse(hidemouse);
         if switch^ then setfillstyle(solidfill,color)
         else setfillstyle(solidfill,lightgray);
         X2:=X1+width;
         y2:=y1+height;
         setcolor(black);
         rectangle(X1,y1,X2,y2);
         Bar(X1+1,y1+1,X2-1,y2-1);
         restoresettings;
         callmouse(showmouse);
end;

constructor tbutton.init;
begin
         tcontrol.init(aswitch);
         name  :=aname;
         width :=textwidth(' '+name+' ');
         height:=textheight(name)+8;
end;

procedure tbutton.show;
begin
         getsettings;
         callmouse(hidemouse);
         setfillstyle(solidfill,lightgray);
         settextstyle(defaultfont,horizdir,1);
         settextjustify(lefttext,centertext);
         width :=6+textwidth(name);
         height:=textheight(name)+8;
         X2:=X1+width;
         y2:=y1+height;
         setcolor(black);
         rectangle(X1,y1,X2,y2);
         Bar(X1+1,y1+1,X2-1,y2-1);
         if (switch^) and (switch<>nil) then
         begin
                  setcolor(white);
                  line(X1+1,y2-1,X2-1,y2-1);
                  line(X2-1,y2-1,X2-1,y1+1);
                  setfillstyle(solidfill,lightgreen);
                  Bar(X2-5,y2-10,X2-3,y2-8);
                  moveto(X1+3,y1+9);
         end
         else
         begin
                  setcolor(white);
                  line(X1+1,y1+1,X2-1,y1+1);
                  line(X1+1,y1+1,X1+1,y2-1);
                  setfillstyle(solidfill,darkgray);
                  Bar(X2-4,y2-7,X2-2,y2-5);
                  moveto (X1+4,y1+10);
         end;
         setcolor(black);
         outtext(name);
         restoresettings;
         callmouse(showmouse);
end;
end.

