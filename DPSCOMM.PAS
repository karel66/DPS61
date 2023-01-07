unit dpscomm;
interface
uses dos,graph,gvmenus,gvcomm,dpspd3;
const
     cmreceive=$FD00;
type
   preceiver =^treceiver;
   treceiver = object (tpulldownmenu)
                 sport     : pcomport;
                 oldfile   : pathstr;
                 newpd3    : ppd3pattern;
                 constructor init;
                 procedure handlekeyboard; virtual;
                 procedure receive;
                 procedure hide;           virtual;
               end;



implementation
uses Crt,GVDrive,GVViews,GVDial,DPSInter;
var mess : tmessagebox;

constructor treceiver.init;
begin
     tpulldownmenu.init('Serial port');
     sport:=new(pcomport,init('Transfer settings', 3 , 9600, 8, 2, 'none'));
     put(sport);
     put(new(pmenuitem,init('Receive data',cmreceive)));
end;

procedure treceiver.handlekeyboard;
begin
     if keycode=cmReceive then receive;
     tpulldownmenu.handlekeyboard;
end;


procedure treceiver.receive;
var
   pd3dialog             : pscrollmenu;
   p                     : pView;
   fin,pb                : ^byte;
   b                     : byte;
   beg                   : pointer;
   raw                   : file of word;
   data                  : word;
   nb,check,block        : longint;
   txt                   : string[20];

begin
   if keypressed then readkey;
   sport^.readbyte; { buffer empty }
   nb:=0;
   check:=0;
        mess.init(' Waiting for data. Press any key to cancel.');
        repeat sport^.readbyte until (sport^.error=0) or (keypressed);
        beep;
        mess.close;
   if keypressed then exit;
        mess.init(' Receiving ');
        block:=20+2*maxnpoints;
        getmem(beg,block);
        pb:=beg;
        repeat sport^.readbyte until sport^.error >=128 ; { waits for timeout }
        repeat pb^:=sport^.readbyte until sport^.error=0; { waits  for first byte }
   {main loop}
       repeat
        inc(check,pb^);
        inc(pb);
        inc(nb);
        pb^:=sport^.readbyte;
       until (sport^.error >=128) or (nb > block);
   { loop end }
   mess.close;
   dec(pb);
   dec(check,pb^);
   dec(pb);
   dec(check,pb^);
   if nb > block then showmessage('Difractogram to long');
   if (pb^<>lo(check)) and (nb < block) then showmessage('Check sum error ');
   dec(pb);
   fin:=pb;
   pb:=beg;
   dec(pb);
   nb:=-4;
   assign(raw,'dps.raw');
   rewrite(raw);
  repeat
     inc(pb);
     inc(nb);
     data:=pb^;
     if pb<>fin then inc(pb);
     inc(data,256*pb^);
     write(raw,data);
  until pb=fin;
  close(raw);
  freemem(beg,block);

  newpd3:=new(ppd3pattern,init);
  pd3dialog:=new(pscrollmenu,init('',10));
  with pd3dialog^ do
  begin
       put(new(pdial,init('&SAMPLE IDENT=',@newpd3^.sample)));
       put(new(pdial,init('&FILE IDENT=',@newpd3^.fullpath)));
       put(new(pdial,init('&DATE=',@newpd3^.date)));
       put(new(pdial,init('&ANODE=',@newpd3^.anode)));
       put(new(pdial,init('&COUNT TIME=',@newpd3^.ctime)));
       put(new(pdial,init('&STEP SIZE=',@newpd3^.Xstep)));
       put(new(pdial,init('&FIRSTX=',@newpd3^.firstX)));
       put(new(pdial,init('&LASTX=',@newpd3^.lastX)));
       put(new(pdial,init('&MAXY=',@newpd3^.maxY)));
       put(new(pdial,init('&NPOINTS=',@newpd3^.npoints)));
       put(new(pdial,init('&GEN KV=',@newpd3^.GenKV)));
       put(new(pdial,init('&GEN MA=',@newpd3^.GenMA)));
       put(new(pdial,init('&DIV SLIT=',@newpd3^.DivSlit)));
       put(new(pdial,init('&REC SLIT=',@newpd3^.RecSlit)));
       put(new(pdial,init('&XUNITS=',@newpd3^.xunits)));
       put(new(pdial,init('&YUNITS=',@newpd3^.yunits)));
       put(new(pdial,init('&YFACTOR=',@newpd3^.yfactor)));
       put(new(pdial,init('&DETECTOR=',@newpd3^.detector)));
       put(new(pdial,init('&DIFFRACTOMETER=',@newpd3^.diffract)));
       put(new(pdial,init('&MONOCHROMATOR=',@newpd3^.monochr)));
       put(new(pdial,init('&GENERATOR TYPE=',@newpd3^.generator)));
       put(new(pdial,init('&PDFNO=',@newpd3^.pdfno)));
       put(new(pdial,init('&ICDD-DX=',@newpd3^.icdddx)));
     end;

  xstep:=textwidth('XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');

  str(nb,newpd3^.npoints);
  newpd3^.load('dps.cfg');
  newpd3^.sample:=' Data from diffractometer';
  newpd3^.fullpath :=dpsdir;
  newpd3^.date     :=datetime;
  assign(raw,'dps.raw');
  reset(raw);
  read(raw,data);  str(data/100:6:2,newpd3^.firstX);
  read(raw,data);  str(data/100:6:2,newpd3^.lastX);
  read(raw,data);  str(data/100:6:2,newpd3^.Xstep);
  read(raw,data);  str(data/100:6:2,newpd3^.ctime);
  check:=0; nb:=0;
  repeat
    inc(nb);
    read(raw,data);
    newpd3^.data^[nb]:=data;
    if data > check then check:=data;
  until (eof(raw)) or (nb=maxnpoints);
  close(raw);
  str(check,newpd3^.maxY);
  pd3dialog^.run;
end;

procedure treceiver.hide;
var
  p                     : pview;
  x                     : real;
  lin,col,n,points      : word;
begin
  if (not window^.hidden) and (newpd3^.fullpath<>'') then
  begin
       fsplit(newpd3^.fullpath,newpd3^.dir,newpd3^.name,newpd3^.exte);
       if newpd3^.exte='' then newpd3^.fullpath:=newpd3^.fullpath+'.PD3';
       assign(output,newpd3^.fullpath);
{Si-}
       rewrite(output);
{Si+}
      if ioresult=0 then
       begin
            p:=child;
  { writes out PD3 labels }
           while p<>nil do
               begin
                    writeln(p^.name,p^.owner^);
                    p:=p^.next;
               end;
           writeln('&XYDATA=(X++(Y..Y))');
           newpd3^.start :=convstr(newpd3^.firstx);
           newpd3^.step  :=convstr(newpd3^.xstep);
           points        :=round(convstr(newpd3^.npoints));
           x:=newpd3^.start;
           n:=0;
           for lin:= 1 to points div 8 do
           begin
                write(x:7:3);
                for n:=n+1 to n+8 do write(newpd3^.data^[n]:8:0);
                x:=x+8*newpd3^.step;
                writeln;
           end;
           if n < points then
           begin
                write(x:7:3);
                while n < points do
                      begin
                           inc(n);
                           write(newpd3^.data^[n]:8:0);
                      end;
           writeln;
       end;
       write('&END=');
      end;
  close(output);  assigncrt(output);  rewrite(output);
  dispose(newpd3,done);
  end;
  tpulldownmenu.hide;
end;

end.