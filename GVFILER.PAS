unit gvfiler;
interface
uses Dos,Graph,GVDrive,GVMenus;
const
  cmChDrive   = $FF03;
  cmChDir     = $FF04;
  cmLoad      = $FF05;
type
  p2diskfile= ^pdiskfile;
  pdiskfile = ^tdiskfile;
  tdiskfile = object
                    dir              : dirstr;
                    name             : namestr;
                    exte             : extstr;
                    fullpath         : pathstr;
                    constructor init;
                    procedure load(newfile : pathstr); virtual;
                    destructor done; virtual;
              end;

  pFiler=^tFiler;
  tFiler= object (tscrollmenu)
                 diskfile               : pdiskfile;
                 exte                   : extstr;
                 HomeDir,NewDir         : dirstr;
                 constructor init (AFile :p2diskfile;
                 APath : pathstr; AName,AExtension : str32; lenght :word);
                 procedure run ; virtual;
                 procedure hide; virtual;
                 procedure handlekeyboard; virtual;
           end;

  pfileritem=^tfileritem;
  tfileritem= object (tmenuitem)
                 fileinfo : searchrec;
                 constructor init(newinfo:searchrec; amessage: word);
                 procedure run; virtual;
               end;


implementation
var mess :tmessagebox;
constructor tdiskfile.init;
begin
end;
procedure tdiskfile.load;
begin
end;
destructor tdiskfile.done;
begin
end;

constructor tFiler.init;
begin
     tscrollmenu.init(AName,lenght);
     diskfile    :=AFile^;
     exte        :=AExtension;
     getdir(0,homedir);
     NewDir:=APath;
     if copy(NewDir,length(NewDir),1)='\' then
        delete(NewDir,length(NewDir),1);
end;

procedure tFiler.run;
var
   s,s1     : searchrec;
   olddir   : pathstr;
begin
   if window^.hidden then
    begin
    getsettings;
    getdir(0,olddir);
    settextstyle(style.font,style.direction,style.charsize);
{$i-}
    chdir(newdir);
{$i+}
     if ioresult<>0 then
       begin
                    chdir(olddir);
                    showmessage('Directory not found');
       end;
     findfirst('*',directory,s);
     if s.name='.' then findnext(s);
     if s.name<>'..' then
        begin
             s1.name:='A:\';
             put(new(pfileritem,init(s1,cmChDrive)));
             s1.name:='B:\';
             put(new(pfileritem,init(s1,cmChDrive)));
             s1.name:='C:\';
             put(new(pfileritem,init(s1,cmChDrive)));
             s1.name:='D:\';
             put(new(pfileritem,init(s1,cmChDrive)));
        end;
     while doserror=0 do
           begin
                put(new(pfileritem,init(s,cmChDir)));
                FindNext(s)
           end;
     findfirst('*.'+exte,anyfile,s);
     while doserror=0 do
           begin
                put(new(pfileritem,init(s,cmLoad)));
                FindNext(s);
           end;
     top:=1;
     bottom:=lines;
     restoresettings;
   end;
   tscrollmenu.show;
   focus:=nil;
end;

procedure tfiler.hide;
begin
     chdir(homedir);
     tscrollmenu.hide;
     if child <> nil then
        begin
             dispose(child,done);
             child:=nil;
        end;
end;

procedure tfiler.handlekeyboard;
var
   sel : pfileritem;
begin
     if focus<>nil then
     begin
          sel:=@focus^;
          case keycode of
          cmChDrive : begin
                       NewDir:=focus^.name;
                       hide;
                       run;
                       event:=evNothing;
                       keycode:=0;
                      end;
          cmChDir   : begin
                       NewDir:=fexpand (sel^.fileinfo.name);
                       hide;
                       run;
                       event:=evNothing;
                       keycode:=0;
                      end;
          cmLoad    : begin
                       mess.init('Loading '+sel^.fileinfo.name);
                       diskfile^.load (fexpand(sel^.fileinfo.name));
                       mess.close;
                       keycode:=cmEsc;
                      end;
          end;
     end;
     tscrollmenu.handlekeyboard;
end;

constructor tfileritem.init;
begin
     fileinfo:=newinfo;
     if fileinfo.attr=directory then
        tmenuitem.init(fileinfo.name+'\...',amessage)
     else
        tmenuitem.init(fileinfo.name,amessage);
end;

procedure tfileritem.run;
begin
     parent^.focus:=@self;
end;

end.