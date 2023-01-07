{**************************************************************************}
{*  DPS 6.10 main program                                                  *}
{*  (c) 1993,1994 by Karel Rimm,                                          *}
{*  Laboratory of electron microscopy and X-ray analysis,                 *}
{*  Tallinn Technical University, Ehitajate tee 5,EE0026 Tallinn, Estonia.*}
{**************************************************************************}

program DPSMain;
uses
    Dos, Crt, Graph,
    DPSInter, DPSPD3,DPSFiler,DPSPrint,DPSFit,DPSGraph,
    GVDrive, GVViews, GVMenus, GVDial, GVStatic, GVMath, GVFiler;
type
    ppd3menu = ^tpd3menu;
    tpd3menu = object (tpulldownmenu)
                ppattern  : p2pd3pattern;
                namelabel : plistitem;
                fitmenu   : pprofitmenu;
                constructor init(AName : string; APattern : p2pd3pattern);
                procedure run;         virtual;
                procedure handleevent; virtual;
                procedure hide;        virtual;
               end;

    ppeaksearchmenu=^tpeaksearchmenu;
    tpeaksearchmenu= object (tpulldownmenu)
                constructor init (nsmooth,convrange,minpeak:plongint);
              end;

    pcorrmenu = ^tcorrmenu;
    tcorrmenu = object (tpulldownmenu)
                  constructor init(areald, astdd :preal);
                end;
const
     cmcleardesk = $FE00;
     cmsavedesk  = $FE01;
     cmsavegraph = $FE02;
     cmrotate    = $FE03;
     cmsave_for_Excel =$FE04;
var
    main                              : tmenuBar;
    patbar                            : pmenubar;
    deskmenu,options,promenu,plotmenu : ppulldownmenu;
    info                              : plistbox;
    desk                              : pdesktop;
    newpd3                            : ppd3menu;
    fmem                              : plistitem;
    mess                              : tmessagebox;
    i                                 : integer;
    cmkey                             : word;
    txt                               : str32;

constructor tpd3menu.init;
begin
     tpulldownmenu.init(AName);
     ppattern  := apattern;
     namelabel := new(plistitem,init(' '{+aname},1,nil,8));
     namelabel^.setcolors(black,cyan);
     { namelabel will be destructed by info^ (listbox)}
end;

procedure tpd3menu.run;
begin
     if window^.hidden then
      begin
       getsettings;
       settextstyle(style.font,style.direction,style.charsize);
       if ppattern^=nil then ppattern^:=new(ppd3pattern,init);
       put(new(pfiler,init(@ppattern^,dpsdir,'Open','PD3',10)));
       if ppattern^^.data<>nil then
         begin
           put(new(prealdial,init('Y offset',6,@ppattern^^.yshift)));
           put(new(ppeaksearchmenu,init(@ppattern^^.ps_smooth,
           @ppattern^^.ps_convrange,@ppattern^^.ps_minpeak)));
           if ppattern^^.peaks<> nil then
            begin
                 put(new(pcorrmenu,init(@ppattern^^.cor_real,@ppattern^^.cor_std)));
                 put(new(pmenuitem,init('Save peaks',cmsavepeaks)));
            end;
           fitmenu:=new(pprofitmenu,init('Profile fitting',ppattern^));
           put(fitmenu);
           put(new(pmenuitem,init('Close',cmclosepd3)));
         end;

       restoresettings;
      end;
    tpulldownmenu.run;
end;

procedure tpd3menu.handleevent;
var newcm :word;
begin
    tpulldownmenu.handleevent;
    if not window^.hidden then
    begin
     newcm   :=keycode;
     keycode :=cmEsc;
     case newcm of
          cmfindpeaks : begin
                             hide;
                             mess.init(' Processing ... ');
                             ppattern^^.findpeaks;
                             mess.close;
                        end;
          cmsavepeaks : begin
                             mess.init(' Saving peaks ');
                             ppattern^^.savepeaks;
                             mess.close;
                        end;
          cmcorrection: begin
                             ppattern^^.correction;
                        end;
          cmfitting   : begin
                             fitmenu^.run;
                        end;
          cmclosepd3  : begin
                             if ppattern^<>nil then dispose(ppattern^,done);
                             ppattern^:=nil;
                             namelabel^.owner:=nil;
                             hide;
                        end;
          else  keycode:=newcm;
          end;
   end;

end;

procedure tpd3menu.hide;
begin
     tpulldownmenu.hide;
     namelabel^.owner:=@ppattern^^.name;
     if child<>nil then dispose(child,done);
     child:=nil;
end;


constructor tpeaksearchmenu.init;
begin
     tpulldownmenu.init('Peak search');
     put(new(pmenuitem,   init('Run ...                  ',cmfindpeaks)));
     put(new(pintegerdial,init('Number of smoothings     ',3,nsmooth)));
     put(new(pintegerdial,init('Convolution range (5..13)',3,convrange)));
     put(new(pintegerdial,init('Min. height (units sigma)',3,minpeak)));
     put(new(prealdial,   init('Ka2 relative intensity   ',4,@ka2ka1)));
end;

constructor tcorrmenu.init;
begin
     tpulldownmenu.init('Correction');
     put(new(prealdial,init(' Actual d   ',8,areald)));
     put(new(prealdial,init(' Standard d ',8,astdd)));
     put(new(pmenuitem,init(' Run ... ',cmcorrection)));
end;

procedure connectpattern (channelno: word; newpattern: ppd3pattern);
begin
    with newpattern^ do
    begin
        plot.connect (channelno,@maxint,@start,@stop,@step,@yshift,
                      @data,@peaks);
        newset := false;
    end;
end;

procedure configure;
begin
    getdir(0,dpsdir);
    comport   := 3;
    npatterns := 12;
    {$I-}
    assign (input, 'dps.cfg'); reset (input);
    {$I+}
    if ioresult <> 0 then exit;
    readln (npatterns);
          if npatterns > 15 then npatterns:=15;
          if npatterns < 2 then npatterns:=2;
    readln (radius);
    readln (ka2ka1);
    readln (comport);
    readln (dpsdir);
    close  (input);
    assigncrt (input);
    reset (input);
end;

procedure rotate;
var
   cp : ppd3pattern;
   cc : pchannel;
   i,j: integer;
   yoff : real;
begin
   cp   :=pd3pat[1];
   cc   :=plot.input[1];
   for i:=1 to npatterns do
       begin
            if i < npatterns then
                 pd3pat[i]:=pd3pat[i+1]
                                     else pd3pat[i]:=cp;
            with plot do
                 begin
                      if i < npatterns then
                         input[i]:=input[i+1]
                                             else input[i]:=cc;
                      buttons[1,i]^.switch:=@input[i]^.dataon;
                      buttons[2,i]^.switch:=@input[i]^.dots;
                      buttons[3,i]^.switch:=@input[i]^.stickson;
                 end;
       end;
   i:=npatterns;
   while (pd3pat[i]=nil) and (i > 1) do dec(i);
   yoff :=pd3pat[i]^.yshift;
   for i:=i downto 2 do
    if pd3pat[i]<> nil then
     begin
          j := i-1;
          while  (pd3pat[j]=nil) and (j > 1) do dec(j);
          pd3pat[i]^.shifty(pd3pat[j]^.yshift);
     end;
   i:=1;
   while (pd3pat[i]=nil) and (i < npatterns) do inc(i);
   if pd3pat[i]<>nil then pd3pat[i]^.shifty(yoff);
end;


           (* program  body *)
begin
{Main.Init}
    CallMouse (hideMouse);
    setfillstyle (solidfill, lightgray);
    bar (0, 0, gmaxx, gmaxy);
    setcolor (black);
    setfillstyle(solidfill,lightgray);
    rectangle(1,1,gmaxx,23);
    bar(3,3,gmaxx-1,23);
    settextstyle (smallfont, horizdir, 5);
    moveto(20,12);
    outtext('Diffractogram processing system DPS 6.2');
    configure;
    getdir(0,maindir);

    options:=new(ppulldownmenu,init (' Settings '));
    options^. put (new (prealdial, init ('Ka2/Ka1 ratio ',5,@ka2ka1) ) );
    options^. put (new (pdial, init ('PD3 directory ', @dpsdir) ) );
    options^. put (new (pintegerdial, init ('Diffractometer connection COM',5, @comport) ) );
    options^. put (new (pmenuitem,init('Save setup                         ',cmSaveSetup)));

    for i:=1 to npatterns do pd3pat[i]:=NIL;

    desk  := new(pdesktop,init(dpsdir+'\DPS.DES'));
    deskmenu:=new(ppulldownmenu,init('Desktop'));
    deskmenu^.put (new(pdial,init('',@desk^.fullpath)));
    deskmenu^.put (new(pfiler,init(@desk,dpsdir,'Load ','DES',10)));
    deskmenu^.put (new(pmenuitem,init('Clear ',cmcleardesk)));
    deskmenu^.put (new(pmenuitem,init('Save  ',cmsavedesk)));
    deskmenu^.put (new(pmenuitem,init('Rotate colors ',cmrotate)));

    plotmenu:=new (ppulldownmenu,init('Print & Plot'));
    plotmenu^.put (new(pprintop,init('Print                    ')));
    plotmenu^.put (new(pmenuitem,init('Save view as Excel .CSV file', cmsave_for_Excel)));
    plotmenu^.put (new(pmenuitem,init('Save view as Grapher .GRF file', cmsavegraph)));
    plotmenu^.put (new(pdial,init('',@grffile)));

    main. init (24);
    main. put (deskmenu);
    main. put (plotmenu);
    main. put (options);
    main. put (new(preceiver,init(' COM ',6)));
    main. put (new(pmenuitem,init('  Quit  ',cmAltX)));
    main. draw;

    fmem:=new(plistitem, init('Free memory',12,@txt,12));
    moveto (4,main.y2+2);
    moveto (gmaxx-fmem^.width,3);
    fmem^.draw;

    info  :=new(plistbox,init(1,1));
    for i:=1 to npatterns do
        begin
             newpd3:=new(ppd3menu,init(colors[i],@pd3pat[i]));
             newpd3^.width:=textwidth('XXXXXXXXX');
             info^.put(newpd3);
             info^.put(newpd3^.namelabel);
        end;

    main.chain(info);
    moveto(1,main.y2+2);
    info^.setcolors(black,cyan);
    info^.draw;
    plot. init (2, info^.y2+4, gmaxx - 2, gmaxy-2, 20,
                                 npatterns ,'Intensity vs. 2-theta');
    plot. yaxis^. start := 0;
    settextstyle (smallfont, horizdir, 5);
    plot. settracehandle (new(ppeakeditor,init));
    plot. draw;

    CallMouse (showMouse);
    if memavail < 100000
        then showmessage('WARNING ! NOT ENOUGH FREE MEMORY ! ');
    desk^.load('dps.des');
    deskmenu^.run;
{Main.Run}
    keycode:=0;
    repeat
        main. handleevent;
        plot. handleevent;
        cmkey :=keycode;
        keycode:=0;
        case cmkey of
             cmSaveSetup          : begin
                                         savecfg;
                                         options^.hide;
                                    end;
             cmsavedesk           : desk^.save;
             cmcleardesk          : begin
                                         desk^.clear;
                                         deskmenu^.hide;
                                         plot.run;
                                    end;
             cmsavegraph          : begin
                                         savegraph;
                                         plotmenu^.hide;
                                    end;
             cmsave_for_Excel     : begin
                                         save_for_Excel;
                                         plotmenu^.hide;
                                    end;
             cmrotate             : begin
                                         rotate;
                                         deskmenu^.hide;
                                         info^.run;
                                         plot.run;
                                    end;
             else keycode:=cmkey;
        end;
        {checks if new patterns loaded}
        for i:= 1 to npatterns do
            if (pd3pat[i]<>nil) then
               if pd3pat[i]^.newset then connectpattern (i,pd3pat[i]);
        str(memavail:8,txt);
        fmem^.refresh;
        event:=evnothing;
        {waits an event}
        repeat getevent until event <> evnothing;
    until keycode = cmAltX; {finishes if Alt+X pressed}
{Main.Done}
    savecfg;
    main. done;
    plot. done;
    closegraph;
end.