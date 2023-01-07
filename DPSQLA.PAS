{$M 16384,0,50000}

  uses graph,crt,dos,dpsinter;
type
    drec     = record  d,idnum,height :word; end;
    refrec   = record  d,height       :word; end;
    phaserec = record
                       name         :string[20];
                       idnum        :word;
                       comp         :string[60];
               end;

    bandrec  = record   dpeak                       :longint;
                        dmax,dmin,intens            :word;
                        fit                         :boolean;
               end;
    ddata    = array [1..50] of record
                           peaknum,d,score,relint,ir  :word   end;
    susrec   = record   id,dnum,dsc,score,ri       : word;
                        dd                         :^ddata;
               end;

    
var
     dTable                                :array [1..5000] of drec;
     phases                                :array [0..200] of phaserec;
     dt                                    :file of drec;
     tablefile,phasefile                   :string[40];
     list                                  :text;
     minscore                              :word;
     suspect                               :array [0..200] of ^susrec;
     peaks                                 :array [1..200] of ppeak;
     newpeak                               :ppeak;
     dbands                                :array [1..200] of bandrec;
     sc                                    :susrec;
     remsus                                :susrec;
     cd                                    :ddata;
     lastd,lastphase,dnum                  :word;
     peaknum,lastpeak,mind                 :word;
     maxpeak,maxd,maxrange                 :word;
     maxheight                               :longint;
     infile,qlafile,date                   :string[30];
     title                                 :string;
     anode                                 :string[2];
     la,la1,la2,lbeta                      :real;
     searchwindow,relint,minheight           :real;
     suspnum,first,last,sumheight,i,j,k,l    :word;
     key                                   :char;
     maxir,minir,irstep,maxnum,linenum,begline     :word;
     cdi,ir,deltad1,deltad2,remnum         :word;
     max,peak,num,score,roundnum           :word;
     currpeak,isum                         :longint;
     RPI,lni,intsum,sumscore,de,ci         :real;
     secround                              :boolean;
     code                                  :integer;

{*} function phasenum(id:word)  :word;
    var i :word;
    begin
      i:=1;
      while (phases[i].idnum<>id) and (i<=lastphase) do inc(i);
      if i > lastphase then phasenum:=0
      else  phasenum:=i;
    end;

{*} Procedure getlambda(anode:string);
    type
    anoderec = record  anode      :string[2];
                       l,l1,l2,lb :real;
               end;
    const
          anodes: array[1..2] of anoderec =
            ((anode:'Cu'; l:1.5422; l1:1.54056; l2:1.54433; lb:1.4),
             (anode:'Fe'; l:1.9;   l1:1.9;     l2:1.9;  lb:1.9));
    begin
       for i:=1 to 2 do
                if anode=anodes[i].anode then with anodes[i] do
                      begin la:=l;la1:=l1;la2:=l2;lbeta:=lb; end;
    end;

{*} Procedure GetDBands(lambda:real);
    begin
         for peaknum:=1 to lastpeak do
          with dbands[peaknum] do
          with  peaks[peaknum]^ do
           begin
            dpeak :=round(80000*sin(pi*x/360)/lambda);
            dmax  :=round(80000*sin(pi*(x+fwhm/2)/360)/lambda);
            dmin  :=round(80000*sin(pi*(x-fwhm/2)/360)/lambda);
            intens:=round(1000.0*height/maxheight);
            fit   :=false;
           end;
         mind:=dbands[lastpeak].dmin;
    end;

{*} Procedure PreScore;
var
         d,dnum,mind,firstpeak             :word;

     function suspected(idnum:word):boolean;
        var i              :word;
            sc             :susrec;
        begin   i:=0;
         repeat
               inc(i);
               sc:=suspect[i]^;
         until   (sc.id=idnum) or (i > suspnum);
         if i <= suspnum then suspected:=true else suspected:=false;
        end;

    begin
     maxd      :=dTable[1].d;
     firstpeak :=1;
     suspnum   :=0;
     dnum      :=1;

     while dbands[firstpeak].dmax < maxd do inc(firstpeak);
     for peaknum:=firstpeak to lastpeak do
     with dbands[peaknum] do
      begin
       while (dmin > dTable[dnum].d) and (dnum <= lastd) do inc(dnum);
       if dnum > lastd then exit; {end of dtable}
       repeat
        if (not suspected(dTable[dnum].idnum)) and
                                  (dTable[dnum].height > 20)  then
         begin
           sc.id:=dTable[dnum].idnum;
                 {* get d values *}
           cdi:=0;
           for i:=first to last do
                           with dTable[i] do
                    if idnum=sc.id then  begin
                                             inc(cdi);
                                             cd[cdi].d:=d;
                                             cd[cdi].relint:=height;
                                          end;
                 {* get d scores *}
           peak :=1;
           for i:=1 to cdi do
             begin
               d:=cd[i].d;
               while (dbands[peak].dpeak < d) and
                                 (peak < lastpeak) do inc(peak);
               deltad1:=abs(dbands[peak].dpeak - d);
               if peak > 1 then
                deltad2:=abs(dbands[peak-1].dpeak - d) else deltad2:=deltad1;
               if deltad2 < deltad1 then
                begin
                   deltad1:=deltad2;
                   dec(peak);
                end;
               with cd[i] do
                begin
                   score  :=round(100/(1 + 4*sqr(deltad1/(dmax-dmin))));
                   ir     :=round(10*intens/relint);
                   peaknum:=peak;
                end;
             end;
                {* save *}
               new(sc.dd);
               sc.dd^   :=cd;
               sc.dnum  :=cdi;
               inc(suspnum);
               new(suspect[suspnum]);
               suspect[suspnum]^:=sc;
            end;
          inc(dnum)
        until  (dnum > lastd) or (dTable[dnum].d > dmax);
       end
    end;

{*} Procedure removesuspect(num:word);
    var i     :word;
    begin
         suspect[0]:=suspect[num];
         for i:=num to suspnum-1 do suspect[i]:=suspect[i+1];
         suspect[suspnum]:=suspect[0];
         if suspnum > 0 then dec(suspnum);
         inc(remnum);
    end;

{*} Procedure deletesuspect(num:word);
    var i     :word;
    begin
         for i:=num to suspnum-1 do suspect[i]:=suspect[i+1];
         if suspnum > 0 then
            begin
                 dispose(suspect[suspnum]);
                 dec(suspnum);
            end;
    end;

{*} Procedure printout(wait :boolean);
    begin
     writeln;
     writeln('Peak identification  (lambda = ',la1:7:5,' A )');
     writeln;
     writeln('              Peak                           Reference ');
     writeln('--------------------------------   -----------------------------------');
     writeln('     2theta   FWHM    I      d       d       phase                 I  ');
     writeln('--------------------------------   -----------------------------------');
     linenum:=linenum+13;
     for i:=1 to lastpeak do
      with dbands[i] do
      begin
       relint:=100.0*peaks[i]^.height/maxheight;
       write(i:3,'. ',peaks[i]^.x:3:3,'   ',peaks[i]^.fwhm:1:2);
       if relint > 1 then write(round(relint):5,' ')
                                     else write('   ',relint:1:1);
       write('   ',40000/dpeak:1:3,'   ');
       l:=0;
       with  dbands[i] do
        for j:=1 to suspnum-1 do
          with suspect[j]^ do
           begin
            cd:=dd^;
            for k:=1 to dnum do
              with cd[k] do
                if (peaknum=i) and (ri*relint/8000 > minheight)
                then
                 begin
                   if l > 0 then write('                                   ');
                   writeln(40000/d:2:3,'   ',phases[phasenum(id)].name,relint:5);
                   inc(l);
                   inc(linenum);
                   if (linenum)mod(60)=0 then
                            begin writeln;writeln;writeln;
                                  writeln(infile);writeln; end;
                 end;
          end;

        if l=0 then begin
               writeln;
               inc(linenum);
               if (linenum)mod(60)=0 then
                 begin writeln;writeln;writeln;writeln(infile);writeln; end;
            end;
       if wait then key:=readkey;
      end;
   if not wait then
    repeat
      inc(linenum);
      writeln(' ');
    until (linenum)mod(60)=0;
    writeln('_');
end;

{*} Procedure Scoring(s:word);
    var i,ir   :word;
        j,lowint,peak        :longint;
    begin
        sc:=suspect[s]^;
        cd:=sc.dd^;
        isum:=0; intsum:=0; num:=0;
    (* get average intensity ratio *)
        for i:=1 to sc.dnum do with cd[i] do
         begin
           peak:=round(dbands[peaknum].intens/10);{rel int %}
           ir  :=round(100*peak/relint);
           if ir < 150 then
              begin
                   isum  :=isum + relint*peak;  {peak weight is relint}
                   intsum:=intsum + relint;
              end
         end;
        if intsum > 0 then  sc.ri:=round(isum/intsum)
                                               else sc.ri:=0;
        rpi:=sc.ri/100;
        isum:=0; intsum:=0;
    (* get intensity ratio *)
        if rpi > 0 then
         begin
          lowint:=round(120*minheight/rpi);
          for i:=1 to sc.dnum do with cd[i] do
          begin
           if (relint > lowint) and (ir < 150)  then
                 begin
                      j     :=relint;
                      if not dbands[peaknum].fit then j:=j+j;
                      isum  :=isum + j*ir;
                      intsum:=intsum + j;
                 end;
          end;
        end;
       if intsum > 0 then  sc.ri:=round(isum/intsum)  else sc.ri:=0;
        rpi:=sc.ri/100;
        sc.dd^:=cd;

           {* Final score *}

        num:=0;  sumscore:=0; intsum:=0;
        if rpi > 0 then
         begin
          (* minimal Irel *)   if rpi > 0.02 then ci:=110*minheight/rpi
                                        else ci:=50*minheight/rpi;
          for i:=1 to sc.dnum do
           with cd[i] do
           if relint > ci then
            begin
              inc(num);
              j :=relint;
              if not dbands[peaknum].fit then j:=j+j;
              de:=dbands[peaknum].intens/10;
              intsum  :=intsum+j;
              sumscore:=sumscore +
                        round(j*score/(1 + de*abs(de - rpi*relint)/10000));
            end;
         end;
      if intsum > 0 then
         sc.score:=round(sumscore/intsum)  else sc.score:=0;
      sc.dsc  :=num;
      suspect[s]^:=sc;
    end;

{*} procedure printunk;
   var i,j :word;
   begin
   writeln;
   writeln(' Unidentified peaks (d,Irel):');j:=0;
   writeln;
   for i:=1 to peaknum do with dbands[i] do
       if not fit then
        begin  inc(j);
               write(40000/dpeak:20:3,round(intens/10):4);
               if (j)mod(2)=0 then writeln;
         end;
     writeln;
    end;

{*} Procedure Listing(roundnum:word);
var i,lc,nlines:word;
    begin
     writeln;
     sc:=suspect[roundnum]^;
     cd:=sc.dd^;
     with sc do  with phases[phasenum(id)] do
      begin
       writeln(roundnum:2,'. ',name,' ',copy(comp,1,pos('  ',comp)),
                                            ' ',copy(comp,28,10));
       writeln('    final score ',sc.score:3,' , mean weighted I(obs)/I(ref) ',sc.ri/100:4:2);
       writeln;
       writeln('   I(obs)  d(obs)   d(ref)  I(ref)  I(o)/I(r)  d score');
      end;
     window(1,wherey,79,22);
     nlines:=sc.dnum;
     if nlines > 15 then nlines:=15;
     for i:=1 to sc.dnum do with cd[i] do
     if sc.ri*relint/8000 > minheight then with dbands[peaknum] do
      begin
        if fit then write('  *') else write('   ');
        if score > 20 then writeln(round(intens/10):4,40000/dpeak:9:3,
                                   40000/d:9:3,relint:7,ir/100:10:2,score:9)
        else
            writeln(40000/d:22:3,relint:7);
      end;
     writeln;
     window(1,1,79,24);
    end;

{*} procedure makedif;
    var outfile                  :string;
        num                      :word;
    begin
    window(1,20,79,23);
    clrscr; num:=0;
    if suspnum > 0 then
       begin
            write(' Phase number (all peaks- 0):');
            readln(num);
       end;
    outfile:=copy(infile,1,pos('.',infile))+'DIF';
    assign(list,outfile);rewrite(list);
    writeln(list,title);
    writeln(list,'0  0  0  0  0  0  0');
    writeln(list,'-1  0  0  0');
    if num > 0 then
    begin
     sc:=suspect[num]^;
     cd:=sc.dd^;
     for i:=1 to sc.dnum do
         if cd[i].score > 50 then
            with cd[i] do
              writeln(list,' 0 0 0 ',40000/dbands[peaknum].dpeak:7:4,
                                            sqrt(relint)*sqr(la1*d/8000):12:3);
     end
      else for i:=1 to peaknum do
           with dbands[i] do
                    writeln(list,' 0 0 0 ',40000/dpeak:7:4,
                         sqrt(peaks[i]^.height)*sqr(la1*dpeak/8000):12:3);
    write(list,'99 99 99 1');
    close(list);
    swapvectors;
    exec('latco5.exe',outfile);
    swapvectors;
    if doserror>0 then write(' Dos error code is:',doserror);
    end;

{*} Procedure qlist;
    var i,j:word;
    begin
     writeln('  Phase search  , file  ',infile,'   ',datetime);writeln;
     writeln('  ',title);
     writeln('-------------------------------------------------------------------');
     writeln('      Phase                  lines     RPI    score ');
     writeln('-------------------------------------------------------------------');
     for i:=1 to roundnum - 1 do with suspect[i]^ do
     writeln(i:3,'. ',phases[phasenum(id)].name,'  ',dsc:6,RI/100:10:2,score:6,
              '     ',phases[phasenum(id)].comp);
              linenum:=roundnum + 10;
     writeln;
     writeln(' Unidentified peaks (d and I):');j:=0;write(' ');
     for i:=1 to peaknum do with dbands[i] do
       if  not fit then
        begin inc(j);
            write(40000/dpeak:6:3,round(intens/10):4,'    ');
            if (j)mod(5) =0 then begin writeln;write(' '); end;
            if wherey > 22 then exit;
         end;
     if j=0 then writeln('none');
    end;


{*} Procedure accept;
    var  txt   : string[3];
    begin
         assign(output,qlafile);
         append(output);
         listing(roundnum);
         if remnum > 0  then begin inc(suspnum); dec(remnum); end;
         cd:=sc.dd^;
         ci:=sc.ri/10;
         for i:=1 to sc.dnum do with cd[i] do
          if score > 40 then
                begin
                     with peaks[peaknum]^ do
                     begin
                      if not dbands[peaknum].fit then
                           str(0.5*la1/sin(pi*x/360):7:3,name);
                      while pos(' ',name) > 0 do
                            delete (name,pos(' ',name),1);
                      str(relint:3,txt);
                      if cd[i].ir < 200 then
                       name:=name+'/'+phases[phasenum(sc.id)].name+':'+txt;
                     end;
                     currpeak:=dbands[peaknum].intens;
                     currpeak:=currpeak - round(ci*relint);
                     if currpeak < 0 then
                        dbands[peaknum].intens:=0
                          else dbands[peaknum].intens:=currpeak;
                     dbands[peaknum].fit := true;
                    end;
        inc(roundnum);
       close(output);
       assigncrt(output);rewrite(output);
      end;

{*} procedure Loaddata;
var temp : string[32];
    tf   : text;
    num  : real;

    label pxfile;
    begin
      assign(tf,'qla.cfg');
{$I-} reset(tf);
{$I+} if ioresult=0 then
        begin
             readln(tf,tablefile);
             readln(tf,infile);
             readln(tf,minscore);
             close(tf);
        end;
     assign(tf,'qla.cfg');
     rewrite(tf);
     writeln;
     write('Database [',tablefile,']:');
     readln(temp);
     if temp<>'' then tablefile:=temp;
     lastd:=0;
{$i-}assign(dt,tablefile);
     reset(dt);
{$i+} if ioresult=0 then  begin

         while not eof(dt) do begin inc(lastd); read(dt,dTable[lastd]);end;
         close(dt); end
      else begin assigncrt(output);rewrite(output);
           write('QLA ERROR : DATBASE NOT FOUND');halt(0);end;
     lastphase:=0;
     with phases[0] do begin
          name:='***                  ';comp:='';end;
     phasefile:=copy(tablefile,1,pos('.',tablefile))+'PHA';
     assign(input,phasefile);
      if ioresult=0 then  begin
            reset(input);
            while not eof(input) do
                  begin
                       inc(lastphase);
                       with phases[lastphase] do
                         readln(name,idnum,comp);
                  end;
           close(input); end
        else
         begin assigncrt(output);rewrite(output);
         write('QLA ERROR : DATABASE FILE NOT FOUND');halt(0);end;
 pxfile:
     peaknum:=0; maxheight:=0; minheight:=$FFFFFFFF;
     assigncrt(input);reset(input);
     write('Input file [',infile,']:');
     readln(temp);
     if temp<>'' then infile:=temp;
     if pos('.',infile)=0 then infile:=infile+'.pea'; close(input);
     {$i-}
     assign(input,infile);
     reset(input);
     {$i+}
     if ioresult=0 then
        begin
         readln(title); readln(anode);
            while not seekeof(input) do
             begin
              inc(peaknum);
              peaks[peaknum]:=new(ppeak,init(0,0,0,''));
               with peaks[peaknum]^ do
                begin
                 read(num);
                 readin;
                 if height < 1 then height:=1;
                 if height > maxheight then maxheight:=round(height);
                 if height < minheight then minheight:=round(height);
                end;
             end;
            minheight:=minheight/maxheight;
            lastpeak:=peaknum;
            close(input);
         end
       else
         begin
           writeln('File ',infile,' not found ');
           goto pxfile;
         end;
      assigncrt(input);reset(input);
      write('Minimal acceptable score [',minscore:3,']:');
      readln(temp);
      if temp<>'' then val(temp,minscore,code);
      writeln(tf,tablefile);
      writeln(tf,infile);
      writeln(tf,minscore);
      close(tf);
     end;

procedure writepeaks;
begin
    { assign(output,infile);
     rewrite(output);
     writeln(title);
     writeln(anode);
     for i:=1 to lastpeak do
         with peaks[i]^ do
         begin
              while pos(' ',name) > 0 do
                            delete (name,pos(' ',name),1);
              writeln(i:3,'.',x:8:4,fwhm:8:3,height:6,bkg:6,'  ',name);
         end;
     close(output);
     assigncrt(output);
     rewrite(output);}
end;

procedure results;
begin
end;

    {******************* main *********************}
begin
   closegraph;
   repeat
     for i:=1 to 200 do suspect[i]:=nil;
     window(1,1,80,24); clrscr;
     write('Qualitative X-Ray Powder Diffraction Analysis.');
     writeln('1992,1993  Karel Rimm.');
     LoadData;
     Getlambda(anode);
     GetDbands(la1);
      qlafile:=copy(infile,1,pos('.',infile))+'qla';
      assign(output,qlafile);rewrite(output);
      writeln(' Phase search listing , file ',infile,'  ',datetime);
      writeln; writeln('    ',title);
      writeln('-------------------------------------------------------------------');
      close(output);
      assigncrt(output);rewrite(output);
     first:=1; last:=1;
     while (dTable[first].d < dbands[1].dmin) and  (first < lastd) do inc(first);
     while (dTable[last].d < dbands[lastpeak].dmax) and (last < lastd) do inc(last);
     Prescore;
     roundnum:=1;remnum:=0;secround:=false;
 if suspnum > 0 then
  begin     {* revolving *}
    repeat
      for i:=roundnum to suspnum do Scoring(i);
      suspect[0]:=suspect[roundnum];
      ci        :=suspect[0]^.score*suspect[0]^.ri;
      k         :=roundnum;
      for i:=roundnum + 1 to suspnum do
                   with suspect[i]^ do
                    if score*ri  > ci
                       then  begin  ci:=score*ri;
                                    k :=i;
                             end;
      suspect[roundnum] :=suspect[k];
      suspect[k]        :=suspect[0];
      sc:=suspect[roundnum]^;
      { * subtraction * }
      if (sc.score > 80) and (sc.ri > 50) then
         begin accept; clrscr; qlist end
      else
      if sc.score > minscore then
           begin
               clrscr;
               Listing(roundnum);
               gotoxy(1,23); write(' Accept (y/n)?');
               if readkey='y' then  Accept  else  Removesuspect(roundnum);
               clrscr;
               Qlist;
           end
      else Removesuspect(roundnum);
   until (roundnum  >= suspnum);
  end;{ revolving }
  writeln;
      assign(output,qlafile);append(output);
      writeln('  * - calculated intensity from overlapping lines');
      writeln('-------------------------------------------------------------------');
      Printunk;
      close(output);
      assign(output,'qlist.qla');rewrite(output);writeln;
      qlist;
      close(output);
      assigncrt(output); rewrite(output);
  write(' Lattice refinement?');
  if readkey='y' then  MakeDIF;
  writeln;
  for i:=1 to 200 do if suspect[i] <> nil then
      begin
           dispose(suspect[i]^.dd);
           dispose(suspect[i]);
           if peaks[i]<>nil then dispose(peaks[i],done);
      end;
  for i:=1 to lastpeak do dispose(peaks[i],done);
  write(' Another analysis?');
  writepeaks;
 until readkey<>'y';
end.