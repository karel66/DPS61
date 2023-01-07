{**************************************************************************}
{*  GVision dialog objects unit                                           *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}
unit gvdial;
interface
uses GVDrive,GVViews,GVMenus;
type
         pDial   =^tDial;
         tDial   = object (tmenuitem)
                  xd           : word;
                  oldstr       : string;
                  writebeg     : boolean;
                  constructor init  (Aname : string; AOwner : pstring);
                  procedure activate;       virtual;
                  procedure draw;           virtual;
                  procedure handleevent;    virtual;
                  procedure handlekeyboard; virtual;
                  procedure run;            virtual;
                  procedure hide;           virtual;
         end;

         prealdial=^trealdial;
         trealdial= object (tdial)
                    realnumber : preal;
                    valstr     : str32;
                    digits     : integer;
                    decim      : integer;
                    power      : integer;
                    constructor Init (aname :str32; ndig : integer;
                                                    anumber : preal);
                    procedure setdigits;
                    procedure draw;      virtual;
                    procedure normalize; virtual;
                  end;

         pintegerdial=^tintegerdial;
         tintegerdial= object (tdial)
                       integnumber : plongint;
                       digits      : integer;
                       power       : integer;
                       valstr      : str32;
                       constructor init (aname : str32; ndig : integer; anumber : plongint);
                       procedure setdigits;
                       procedure draw; virtual;
                       procedure normalize; virtual;
                  end;

         pCheckBox=^tCheckbox;
         tcheckbox= object (tmenuitem)
                  xc,labwidth : word;
                  yes,no : str32;
                  switch : pboolean;
                  constructor init  (Aname : str32; Aswitch : pboolean);
                  procedure setlabels (yeslab,nolab:str32);
                  procedure show;
                  procedure draw; virtual;
                  procedure Run; virtual;
         end;
         
implementation
uses dos,Graph;

{* tDial *}
constructor tDial.init;
begin
         tmenuitem.init(Aname,0);
         owner   :=AOwner;
         inc(width,textwidth(owner^+' ')); { owner^ should be defined... }
         inc(height,2);
         oldstr:=owner^;
end;

procedure TDial.activate;
begin
     tmenuitem.activate;
     writebeg:=true;
end;

procedure TDial.draw;
var i:word;
begin
      tmenuitem.draw;
      xd  := x1+textwidth(' '+name+' ');
      x2  := x1+width;
      if x2 > gmaxx then x2:=gmaxx;

         CallMouse(hidemouse);
         getsettings;
         setfillstyle(solidfill,white);
         bar(xd-4,y1+2,x2-4,y2-3);
         setcolor(black);
         rectangle(xd-6,y1+1,X2-2,y2-1);
         setcolor(white);
         line(xd-6,y2-1,X2-2,y2-1);
         line(X2-2,y1+1,X2-2,y2-2);
         CallMouse(showmouse);
         restoresettings;
      run;
end;

procedure tDial.Run;
begin
         CallMouse(hidemouse);
         getsettings;
         setfillstyle(solidfill,white);
         settextjustify(lefttext,centertext);
         settextstyle(style.font,style.direction,style.charsize);
         setcolor(fgcolor);
         bar(xd-4,y1+2,x2-4,y2-3);
         moveto(xd,ycenter);
         outtext (owner^);
         oldstr :=owner^;
         CallMouse(showmouse);
         restoresettings;
end;

procedure tdial.handleevent;
begin
     tmenuitem.handleevent;
     if (oldstr<>owner^) and not hidden then run;
end;

procedure tdial.handlekeyboard;
begin
         if lo(keycode) in [31..230] then
                        begin
                             if writebeg then
                                begin
                                     owner^:='';
                                     writebeg:=false;
                                end;
                              owner^:=owner^+chr(lo(keycode));
                              keycode:=0;
                         end;
         case keycode of
                  cmBs : begin
                              delete(owner^,length(owner^),1);
                              writebeg:=false;
                              keycode:=0;
                         end;
                 cmDel : begin
                               owner^:='';
                               writebeg:=false;
                               keycode:=0;
                         end;
         cmLeft,cmRight: begin
                              writebeg:=false;
                              keycode:=0;
                         end;
                cmEnter: begin
                              keycode:=cmDown;
                              tmenuitem.handlekeyboard;
                         end;
                else tmenuitem.handlekeyboard;
         end;
end;

procedure tdial.hide;
begin
     normalize;
     tmenuitem.hide;
end;

constructor trealdial.init;
begin
     realnumber := anumber;
     digits     := ndig;
     if digits < 1 then digits:=1;
     setdigits;
     tdial.init(aname,@valstr);
end;

procedure trealdial.setdigits;
begin
     if abs(realnumber^) > 1e-10  then
       begin
        power := trunc(ln(abs(realnumber^))/ln10);
        if abs(power) <= digits - 2 then
           begin
               if power >= 0 then decim:=digits-power-2
                    else  decim:= digits - 2 ;
               str(realnumber^:digits:decim,valstr)
           end
           else
           begin
               if power >=0 then decim:=0 else decim:= -power;
               str(realnumber^:abs(power)+2:decim,valstr);
           end;
       end
     else str(realnumber^:digits:0,valstr);
end;

procedure trealdial.draw;
begin
     setdigits;
     tdial.draw;
end;

procedure trealdial.normalize;
begin
     realnumber^:=convstr(valstr);
     tdial.normalize;
end;


constructor tintegerdial.init;
begin
     integnumber:=anumber;
     digits:=ndig;
     if digits < 1 then digits:=1;
     setdigits;
     tdial.init(aname,@valstr);
end;

procedure tintegerdial.setdigits;
begin
     if integnumber^ <> 0  then
        power := trunc(ln(abs(integnumber^))/ln10)
              else power := -1;
     if power <= digits - 1 then  str(integnumber^:digits,valstr)
              else  str(integnumber^:(power+1),valstr);
end;

procedure tintegerdial.draw;
begin
     setdigits;
     tdial.draw;
end;

procedure tintegerdial.normalize;
begin
     tdial.normalize;
     integnumber^:=round(convstr(valstr));
end;

{* tcheckbox *}
constructor tcheckbox.init;
begin
         yes:='YES  ';
         no:=' NO   ';
         labwidth:=textwidth(yes);
         tmenuitem.init(Aname,0);
         width   :=textwidth(' '+name)+labwidth;
         switch  :=ASwitch;
end;

procedure tcheckbox.setlabels;
begin
     yes:=yeslab;
     no :=nolab;
     if textwidth(yes) > textwidth(no) then
        labwidth:=textwidth(yes)
     else labwidth:=textwidth(no);
     width   :=textwidth(' '+name)+labwidth;
end;

procedure tcheckbox.show;
begin
         getsettings;
         callmouse(hidemouse);
         setcolor(fgcolor);
         setfillstyle(solidfill,bgcolor);
         settextjustify(lefttext,centertext);
         Bar(xc,y1+2,x2-2,y2-2);
         moveto(xc,Ycenter);
         if switch^ then outtext(yes) else outtext(no);
         callmouse(showmouse);
         restoresettings;
end;

procedure Tcheckbox.draw;
begin
         tmenuitem.draw;
         xc:=x2-labwidth;
         show;
end;

procedure tcheckbox.Run;
begin
         switch^ :=not switch^;
         show;
end;

end.