{**************************************************************************}
{*  GVisoin basic objects.                                                *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}

unit GVviews;
interface
uses Graph, GVDrive;
type
         PView = ^TView;
         TView = object
                          name                    : str32;
                          owner                   : pstring;
                          X1, y1, X2, y2             : integer;
                          width, height, message    : word;
                          oldcolor                : word;
                          oldfill                 : fillsettingstype;
                          oldstyle                : textsettingstype;
                          active, hidden           : boolean;
                          parent, child, next, focus : pview;
                          fgcolor,bgcolor         : word;
                          constructor init ;
                          procedure chain (nextview : pview);
                          procedure put   (newchild : pview);
                          procedure handleevent ; virtual;
                          procedure handlekeyboard ; virtual;
                          procedure handlemouse ; virtual;
                          procedure draw;           virtual;
                          procedure run;            virtual;
                          procedure activate;       virtual;
                          procedure normalize;      virtual;
                          procedure setcolors(foreground,background : word);
                          procedure hide;           virtual;
                          procedure getsettings;
                          procedure restoresettings;
                          function mousein: boolean; virtual;
                          function count  : word;
                          function get (number : word): pview;
                          destructor done;          virtual;
                 end;
         
implementation
uses dos;
var
         regs: registers;
         
         {* TView *}
         constructor TView. Init;
begin
         owner   := nil;
         parent  := @self;
         next    := nil;
         child   := nil;
         active  := false;
         hidden  := true;
         name    := '';
         X1      := 0;
         y1      := 0;
         width   := 0;
         height  := 0;
         message := 0;
end;

procedure TView. chain (nextview : pView);
begin
         if next <> nil then next^. chain (nextview) else next := nextview;
end;

procedure TView. put (newchild : pView);
begin
         newchild^. parent := @self;
         if child = nil then child := newchild else child^. chain (newchild);
end;

procedure TView. HandleEvent ;
begin
         if child <> nil then child^. handleevent;
         if next  <> nil then next^. handleevent;
         if (event <> evNothing) and not hidden then
         begin
                  case Event of
                           evmouse    : handlemouse;
                           evkeyboard : if active then handlekeyboard;
                  end;
         end;
end;

procedure TView. handlemouse;
begin end;

procedure TView. handlekeyboard;
begin end;

procedure TView. draw;
begin
         X1 := getx;
         y1 := gety;
         hidden := false;
end;

procedure TView. run;
begin end;

function TView. mousein: boolean;
begin
         mousein := false;
         if (mouse. X >= X1) and (mouse. X <= X2)
            and (mouse. y >= y1) and (mouse. y <= y2) and not hidden
         then mousein := true;
end;

function TView. count: word;
var
         c: word;
         p: pview;
begin
         c := 0;
         p := @self;
         repeat
                  inc (c);
                  p := p^. next;
         until p = nil;
         count := c;
end;

function TView. get (number: word): pview;
var
         c: word;
         p: pview;
begin
         p := @self;
         for c := 2 to number do
                  if p^. next <> nil then p := p^. next;
         get := p;
end;

procedure tview. getsettings;
begin
         oldcolor := getcolor;
         getfillsettings (oldfill);
         gettextsettings (oldstyle);
end;

procedure tview. restoresettings;
begin
         setcolor (oldcolor);
         setfillstyle (oldfill. pattern, oldfill. color);
         settextstyle (oldstyle. font, oldstyle. direction, oldstyle. charsize);
         settextjustify (oldstyle. horiz, oldstyle. vert);
end;

procedure tview. activate;
begin
         active := true;
end;

procedure tview. normalize;
begin
         active := false;
end;

procedure tview.setcolors;
begin
         fgcolor:=foreground;
         bgcolor:=background;
end;

procedure tview. hide;
begin
         hidden := true;
end;

destructor TView. done;
begin
         if next <> nil then dispose (next, done);
         if child <> nil then dispose (child, done);
end;

end.


