unit dpsgraph;
interface
uses dos,dpsinter,dpspd3;
     var  grffile : pathstr;

     procedure savegraph;
     procedure save_for_excel;

implementation
uses Crt,GVMath;
procedure savegraph;
var
   i,j,k,l,ndat         : integer;
   lowindex,highindex   : integer;
   twotheta,step,stop   : real;
   grf                  : text;
   pea                  : text;
   datfile              : string[12];
   cp                   : pstick;
begin
   if pos('.',grffile)=0 then grffile:=grffile+'.grf';
   assign(grf,grffile);
   rewrite(grf);
   writeln(grf,'1243');

   assign(pea,'peaks.dat');
   rewrite(pea);
   close(pea);
   ndat:=1;
   for i:= 1 to plot.nchan do
     if plot.input[i]^.connected and plot.input[i]^.dataon then
       begin
         inc(ndat);
         step:=plot.input[i]^.xstep;
         stop:=plot.input[i]^.xend;
         lowindex  :=1 + trunc((plot.xstart - plot.input[i]^.xstart)/step);
         if lowindex < 1 then lowindex:=1;
         twotheta  :=plot.input[i]^.xstart + (lowindex-1)*step;
         highindex :=1 + trunc((plot.xend - plot.input[i]^.xstart)/step);

         assign(output,colors[i]+'.dat');
         rewrite(output);
         for j:= lowindex to highindex do
           begin
             if twotheta <= stop then
              with plot.input[i]^ do
                writeln(twotheta:6:2,' ',
                       min(plot.yend,(data^[j]+yoffset)):6:2);
             twotheta:=twotheta+step;
           end;
         close(output);

         if plot.input[i]^.stickson then
         begin
           append(pea);
           cp:=plot.input[i]^.sticks;
           while cp <> nil do
            begin
             if (cp^.x > plot.xstart) and (cp^.x < plot.xend)
               then writeln(pea, cp^.x:7:3,' ',cp^.y1:7:2,' "',cp^.name,'"');
             cp:=cp^.next;
            end;
           close(pea);
         end;

       end;

     assigncrt(output);rewrite(output);
     writeln(grf,ndat,' 2 0 0 0');
     for i:= 1 to plot.nchan do
     if plot.input[i]^.connected and plot.input[i]^.dataon then
       begin
         datfile:=colors[i];
         while pos(' ',datfile) > 0 do delete(datfile,pos(' ',datfile),1);
         writeln(grf,datfile);
         writeln(grf,'65 66 48 2"NO " 48');
         if plot.input[i]^.dots then write(grf,'"NO " ')
            else write(grf,'"YES" ');
         writeln(grf,'"SOLID" 1.500e-001 ',i);
         if plot.input[i]^.dots then write(grf,'"YES" ')
            else write(grf,'"NO " ');
         writeln(grf,'33 1.000e-001 1 1');
         writeln(grf,'48 9.900e+028 9.900e+028 0.000e+000 "DEFAULT" 1.000e-001 1');
         writeln(grf,'"SOLID" 0 1.500e-001 9.9000000e+029 9.9000000e+029 200 2.000e+000 1');
         writeln(grf,'9.9000000e+029 9.9000000e+029 9.9000000e+029 9.9000000e+029 1.500e-001');
       end;
       { peaks.dat }
         writeln(grf,'PEAKS');
         writeln(grf,'65 66 67 3 "NO " 48');
         writeln(grf,'"NO" "SOLID" 1.500e-001 ',i);
         writeln(grf,'"YES" 91 1.000e-001 1 1');
         writeln(grf,'67 0.000e-000 0.000e-000 9.000e+001 "DEFAULT" 1.000e-001 1');
         writeln(grf,'"SOLID" 0 1.500e-001 9.9000000e+029 9.9000000e+029 200 2.000e+000 1');
         writeln(grf,'9.9000000e+029 9.9000000e+029 9.9000000e+029 9.9000000e+029 1.500e-001');

     writeln(grf,'"X-AXIS"');
     writeln(grf,'1.5000000e+000 1.0000000e+000 6.0000000e+000 88');
     writeln(grf,'9.9000000e+028 9.9000000e+028 9.9000000e+028 1 1');
     writeln(grf,'0.0000000e+000 9.9000000e+028 1.5000000e-001 1 1');
     writeln(grf,'10 2 1');
     writeln(grf,'1 9.9000000e+028 1.0000000e+000 9.9000000e+028 2.0000000e-001');
     writeln(grf,'"SET10" "SET10" "Two-Theta (Deg)"');
     writeln(grf,'4.0000000e-002');
     writeln(grf,'"Y-AXIS"');
     writeln(grf,'1.5000000e+000 1.0000000e+000 6.0000000e+000 89');
     writeln(grf,'0.0000000e+000 ',plot.yend,' 9.9000000e+028 1 1');
     writeln(grf,'2.7000000e+002 9.9000000e+028 1.5000000e-001 1 1');
     writeln(grf,'10 2 1');
     writeln(grf,'1 9.9000000e+028 0.0000000e+000 9.9000000e+028 2.0000000e-001');
     writeln(grf,'"SET10" "SET10" "Counts"');
     writeln(grf,'4.0000000e-002');
     close(grf);
end;

procedure save_for_excel;
var
   minstep,argx,y_1,y_2,y_c   :real;
   i,maxstep,index,nx         :integer;
   xlf                        :text;
begin
   minstep:=1e20;
   assign(xlf,'DPS_XL.CSV');
   rewrite(xlf);
   for i:= 1 to plot.nchan do
   if plot.input[i]^.connected and plot.input[i]^.dataon then
      begin
           {searches for minimal scan-step}
           if minstep > plot.input[i]^.xstep
              then minstep:=plot.input[i]^.xstep;
           write(xlf,';',pd3pat[i]^.sample);
      end;
   writeln(xlf);
   maxstep:=round((plot.xend-plot.xstart)/minstep); {max step number in minsteps}
   argx   :=plot.xstart-minstep;
   for nx:=1 to maxstep do
    begin
         argx:=argx + minstep;
         write(xlf,argx:5:3);
         for i:= 1 to plot.nchan do
         if plot.input[i]^.connected and plot.input[i]^.dataon then
          with plot.input[i]^ do
             begin
              index :=1+trunc((argx - xstart)/xstep);
              if (index > 1) and (argx <= xend) then
                begin
                     y_1:=data^[index-1];
                     y_2:=data^[index];
                     y_c:=yoff^ + y_1 +(y_2 - y_1)*(argx - xstart - xstep*(index - 1))/minstep;
                     write(xlf,';',round(y_c));
                end;
             end;
         writeln(xlf);
    end;
    close(xlf);

end;

begin
     grffile:='DPS6.GRF';
end.




