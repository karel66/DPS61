{**************************************************************************}
{*  DPS 6.1 file handling.                                                *}
{*  (c) 1993 by Karel Rimm,                                               *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}

unit dpsfiler;
interface
uses Dos,GVDrive,GVMenus,GVFiler,DPSPD3;
type
   pdesktop = ^tdesktop;
   tdesktop = object (tdiskfile)
                     constructor init(ADesk:pathstr);
                     procedure load(newfile:pathstr); virtual;
                     procedure clear;
                     procedure save;
              end;

   preceiver =^treceiver;
   treceiver = object (tscrollmenu)
                 oldfile:pathstr;
                 newpd3 : ppd3pattern;
                 procedure run; virtual;
                 procedure hide; virtual;
               end;

   procedure savecfg;

implementation
uses Crt,Graph,GVViews,Comm,GVDial,GVmath,DPSInter;
var
   mess               : tmessagebox;
   code               : integer;
   pd3labels          : pview;

constructor tdesktop.init;
begin
     tdiskfile.init;
     fullpath:=ADesk;
end;

procedure tdesktop.load;
var
   infile : text;
   yoff   : real;
   newpat : pathstr;
   c      : char;
   i      : integer;
   xstart,xend,ystart,yend : real;
begin
   fullpath:=newfile;
   clear;
   assign(infile,fullpath);
{$i-}
   reset(infile);
{$i+}
   if ioresult=0 then
    begin
     readln(infile,xstart,xend);
     readln(infile,ystart,yend);
     for i:=1 to npatterns do
      if not seekeof(infile) then
       begin
         readln(infile,yoff,c,newpat);
         if (newpat<>'EMPTY') and (newpat<>'') then
            begin
                 pd3pat[i]:=new(ppd3pattern,init);
                 pd3pat[i]^.load(newpat);
                 pd3pat[i]^.shifty(yoff);
                 pd3pat[i]^.newset:=false;
                 with pd3pat[i]^ do
                 plot.connect (i,@maxint,@start,@stop,@step,@yshift,
                      @data,@peaks);
           end;
       end;
     close(infile);
     plot.xstart:=xstart;
     plot.xend:=xend;
     plot.ystart:=ystart;
     plot.yend:=yend;
     plot.run;
    end
    else showmessage(' Desktop file '+fullpath+' not found');
end;

procedure tdesktop.clear;
var i:integer;
begin
     for i:=1 to npatterns do
       if pd3pat[i]<>nil then
         begin
              dispose(pd3pat[i],done);
              pd3pat[i]:=nil;
              plot.input[i]^.disconnect;
         end;
end;


procedure tdesktop.save;
var
   i  : integer;
begin
     if fullpath='' then exit;
     assign(output,fullpath);
     rewrite(output);
     writeln(plot.xstart:6:3,' ',plot.xend:6:3);
     writeln(plot.ystart:6:3,' ',plot.yend:6:3);
     for i:=1 to npatterns do
        if pd3pat[i]<>nil then
           writeln (pd3pat[i]^.yshift:5:0,' ',
              pd3pat[i]^. dir + pd3pat[i]^. name + pd3pat[i]^. exte)
                 else writeln('    0 EMPTY');
     close(output);
     assigncrt(output);
     rewrite(output);
end;


procedure savecfg;
var
    aline         : string;
    oldcfg,newcfg : text;
    i             : integer;
begin
    assign (newcfg,'dps.tmp'); rewrite(newcfg);
    assign (oldcfg, 'dps.cfg'); reset(oldcfg);
    readln(oldcfg); writeln(newcfg,npatterns:6,'   max number of patterns;');
    readln(oldcfg); writeln(newcfg,radius:6:0 ,'   diffractometer radius in mm;');
    readln(oldcfg); writeln(newcfg,ka2ka1:6:3 ,'   Ka2/Ka1 ratio;');
    readln(oldcfg); writeln(newcfg,comport:6  ,'   serial connection port number;');
    readln(oldcfg); writeln(newcfg,dpsdir);
    while not seekeof(oldcfg) do
          begin
               readln(oldcfg,aline);
               writeln(newcfg,aline);
          end;
    close(oldcfg);
    erase(oldcfg);
    close(newcfg);
    rename(newcfg,'dps.cfg');
end;

procedure treceiver.run;
var
   p                     : pView;
   fin,pb                : ^byte;
   b                     : byte;
   beg                   : pointer;
   raw                   : file of word;
   data                  : word;
   nb,check,block        : longint;
   code                  : integer;
   txt                   : string[20];
   port                  : byte;

begin

   initcomm(lo(comport),9600,'n',2,8);
   if keypressed then halt; {*readkey;*}
   rece(b); { buffer empty }
   nb:=0; check:=0;
        mess.init(' Waiting for data. Press any key to cancel.');
        repeat rece(b) until (errstatus=0) or (keypressed);
        beep;
        mess.close;
   if keypressed then exit;
        mess.init(' Receiving ');
        block:=20+2*maxnpoints;
        getmem(beg,block);
        pb:=beg;
        repeat rece(pb^) until errstatus >=128 ; { waits for timeout }
        repeat rece(pb^) until (errstatus=0) or keypressed; { waits  for first byte }
   {main loop}
       repeat
        inc(check,pb^);
        inc(pb);
        inc(nb);
        rece(pb^);
       until (errstatus >=128) or (nb > block);
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
  tscrollmenu.run;
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
           val(newpd3^.firstx,newpd3^.start,code);
           val(newpd3^.xstep,newpd3^.step,code);
           val(newpd3^.npoints,points,code);
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
  tscrollmenu.hide;
end;

end.