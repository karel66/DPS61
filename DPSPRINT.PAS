{**************************************************************************}
{*  DPS 6.1 printing EPSON codes.                                          *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}
{$M 1024,0,0}
Unit dpsprint;

Interface
Uses gvmenus, dpsinter, dpspd3;
Type
  pprintop = ^tprintop;
  tprintop = Object (tpulldownmenu)
               Procedure run; Virtual;
               Procedure hide; Virtual;
             End;
  
Implementation
Uses graph, dpsfiler, gvviews, gvdial, gvdrive, gvmath;

Type
  pprinter  = ^tprinter;
  tprinter  = Object (tmenuitem)
                Procedure run; Virtual;
              End;
  
  pprintline = ^printline;
  printline = Array [1..10] Of Byte;

Var
  lst                         : text;
  printfile                   : string[40];
  mess                        : tmessagebox;
  start,stop,printstep        : real;
  stoppage, transp            : Boolean;
  patr                        : array [1..15] of printline;
  sh                          : array [1..15] of real;
  upper                       : word;
  firstchan                   : word;

Procedure convert (Pattern: ppd3Pattern; image: pprintline; idx: integer);
Var
  n        : integer;
  angindex : real;
  y        : LongInt;

Begin
  angindex:=idx;
  For n:= 1 to 10 Do
  Begin
    if (angindex >= 1) and (angindex <= pattern^.maxindex) then
     y :=Round(plot.yaxis^.scale*(Pattern^.yshift+
       Pattern^. data^ [round(angindex)]))
    else y:=0;
    if y > 255 then y:=255;
    image^[n] := y;
    if y > upper then upper:=y;
    angindex:=angindex + printstep/pattern^.step;
  End
End;

Procedure tprintop. run;
var i: integer;
Begin
  start :=pd3pat[1]^.start;
  stop  :=pd3pat[1]^.stop;
  printstep:=100;
  for i := 1 to npatterns do
   if (pd3pat[i]<>nil) and
      (pd3pat[i]^.data<>nil) and
      (plot.input[i]^.dataon) then
      if pd3pat[i]^.step < printstep then printstep:=pd3pat[i]^.step;

  getsettings;
  settextstyle(style.font,style.direction,style.charsize);
  put (new(pdial,init('Print to ',@printfile)));
  put (new(prealdial, init ('Step deg/dot      ', 6, @printstep)));
  put (new(prealdial, init ('Start at 2-theta  ', 6, @start) ) );
  put (new(prealdial, init ('Stop at 2-theta   ', 6, @stop)));
  put (New (pcheckbox, init ('Pages   ', @stoppage) ) );
  put (New (pprinter, init ('Begin printing ...           ', cmesc) ) );
  restoresettings;
  tpulldownmenu. run;
End;

Procedure tprintop. hide;
Begin
  tpulldownmenu. hide;
  If child <> Nil Then
  Begin
    Dispose (child, done);
    child := Nil;
  End;
End;

Procedure tprinter. run;
  Const
    bits: Array [0..7] Of Integer = (128, 64, 32, 16, 8, 4, 2, 1);
    ESC = Chr (27);
  Var
    nofpages,page,nofline  : Word;
    ml, Pos,  n, old       : Word;
    i                      : longint;
    level1, level2, level3 : word;
    angle, fracangle       : Real;
    marker,c               : Char;
    txt                    : String;
    y                      : LongInt;
    stick                  : Array [0..10] Of Boolean;
    peakmark               : array [1..15] of pstick;

  Label finish;

      Procedure setpixels (patr: pprintline);
      Var n: Word;
      Begin
        For n := 0 To 7 Do
        Begin
          level1 := patr^ [n + 1];
          level2 := patr^ [n + 2];
          level3 := patr^ [n + 3];
          level1 := (level1 + level2) ShR 1;
          level3 := (level2 + level3) ShR 1;
          If ( (Pos <= level1) And (Pos >= level2) ) Or
             ( (Pos >= level1) And (Pos <= level2) ) Or
             ( (Pos <= level3) And (Pos >= level2) ) Or
             ( (Pos >= level3) And (Pos <= level2) )  
          Then
            ml := ml Or bits [n];
        End;
      End;

      procedure resetsticks (channo:pchannel; var cstick :pstick);
      begin
        cstick:=nil;
        if channo^.stickson then
           begin
             cstick:=channo^.sticks;
             while (cstick<>nil) and (cstick^.x < start) do
                                          cstick:=cstick^.next;
           end;
      end;

      procedure printlabels(var cstick :pstick);
      var
         dist : real;
      begin
      if cstick=nil then exit;
      Repeat
          dist :=(cstick^.x - angle)/printstep;
          If dist < 8  then
            begin
                write(lst, cstick^.name);
                cstick:=cstick^.next;
            end;
      Until (dist >= 8) Or (cstick = nil);
      end;

Begin
  assign(lst,printfile);
  {$I-}
  reWrite (Lst);
  {$I+}
  if IOResult<>0 then
  begin
       write(chr(7));
       showmessage('Can''t open '+printfile);
  end;

  firstchan :=npatterns+1;
  for i:= 1 to npatterns do
   if (pd3pat[i]<>nil) and
      (pd3pat[i]^.data<>nil) and
      (plot.input[i]^.dataon) then
       begin
            if i < firstchan then firstchan:=i;
            sh[i]:=(pd3pat[i]^.start - start)/pd3pat[i]^.step;
       end;
  nofpages  := round((stop-start)/printstep);
  angle     := start;
  for i:=1 to npatterns do
        resetsticks(plot.input[i],peakmark[i]);

  mess.init ('   Printing to '+ printfile);
  WriteLn (Lst, ESC, '@', ESC, '3', Chr (24), Chr (18) );
  write (lst, chr(15)); {small font}
  WriteLn (Lst, '  DPS 6.1  diffractogram print ', DateTime);
  for i:=firstchan to npatterns do
   if (pd3pat[i]<>nil) and plot.input[i]^.dataon then with pd3pat[i]^ do
     WriteLn (Lst, '  ',
     fullpath,' ',sample,' ; ',anode,' ', genkv,' kV ',genma,
                ' mA ; step ',xstep,' deg ; count time ',ctime,' sec ;',
                     ' intensity offset',yshift:6:0);

  Write (Lst, '  2theta', ESC, '*', Chr (0), Chr (4), Chr (1) );
  For ml := 1 To 259 Do Write (Lst, Chr (1) );
  WriteLn (Lst, Chr (3), ' ',  (255.0 / plot.yaxis^.scale):6:0, ' counts');
  mess.close;

  For page := 0 To nofpages Do
  Begin
    If (page > 0) And stoppage Then
    Begin
      showmessage (' Press any key to print next page, Esc to cancel');
      If keycode = cmEsc then goto finish ;
      WriteLn (Lst);
      Write (Lst, '  ', pd3pat[firstchan]^. fullpath,' ... ');
      WriteLn (Lst, '  Page ', page + 1);
      Write (Lst, ' 2 theta', ESC, '*', Chr (0), Chr (4), Chr (1) );
      For ml := 1 To 259 Do Write (Lst, Chr (1) );
      WriteLn (Lst, Chr (3), ' ', Round (255 / plot.yaxis^.scale), ' counts');
    End;
    mess.init(' Printing ');

    For nofline := 0 To 79 Do
    Begin
      if angle > stop then goto finish;
      marker := Chr (0);
      fracangle := 1.0 - Frac (angle);
      If fracangle = 1.0 Then fracangle := 0;
      If (fracangle < 8 * printstep) And (Round (angle) > old) Then
      Begin
        Write (Lst, '  ', angle: 3: 0, '.0 ');
        marker := Chr (bits [Trunc (fracangle / printstep) ] );
        old := Round (angle);
      End Else Write (Lst, '        ');

      upper:=0;
      for i:=firstchan to npatterns do
       if plot.input[i]^.dataon and (pd3pat[i]<>nil) then
        convert (pd3pat[i],@patr[i],
                      trunc( 1+ (angle-start)/pd3pat[i]^.step - sh[i]));
      upper := upper + 5;
      If (upper) Mod (26) = 0 Then Inc (upper);

      Write (Lst, ESC, '*', Chr (0), Chr ( (upper) Mod (256) ), Chr ( (upper) Div (256) ) );
      Write (Lst, marker, marker, marker, marker, Chr (255) );
      For n := 0 To 7 Do stick [n] := True;
      For Pos := 1 To upper - 5 Do
      Begin
        ml := 0;
        for i:=firstchan to npatterns do
           if plot.input[i]^.dataon and (pd3pat[i]^.data<>nil) then
                                                setpixels (@patr[i]);
        Write (Lst, Chr (ml) );
      End;
      Write (Lst, ' ');
      for i:=1 to npatterns do printlabels(peakmark[i]);
      WriteLn (Lst,' ');
      angle:=angle+8*printstep;
    End;
   mess.close;
  End;
finish:
  Write (Lst, Chr (12), ESC, '@');
  close ( lst );
  mess.close;
End;

Begin
  printfile:='PRN ';
  stoppage := true;
End.
