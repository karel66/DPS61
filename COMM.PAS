unit Comm;
interface
 procedure InitComm(port:byte; baudrate:word; parity:char; stopbits,length:byte);
 procedure Send(data:byte);
 procedure Rece(var data:byte);
 function commStatus:word;
 var commerr   :boolean;
          errstatus :byte;
          
 implementation
 uses dos;
var
         regs :registers;
         pnum :byte;
         
procedure InitComm;
var
         bauds,pty,stb,lt  :byte;
begin
         pnum:=port-1;
         case baudrate of
                  110 : bauds:=0;
                  150 : bauds:=$20;
                  300 : bauds:=$40;
                  600 : bauds:=$60;
                  1200 : bauds:=$80;
                  2400 : bauds:=$A0;
                  4800 : bauds:=$C0;
                  9600 : bauds:=224;
         end;
         case parity of
                  'n' : pty:=0;
                  'e' : pty:=$18;
                  'o' : pty:=$08;
         end;
         case stopbits of
                  1 : stb:=0;
                  2 : stb:=$04;
         end;
         case length of
                  7 : lt:=2;
                  8 : lt:=3;
         end;
         with regs do
         begin
                  dx:=pnum;
                  ah:=0;
                  al:=bauds+pty+stb+lt;
         end;
         intr($14,regs);
end;

procedure Send;
    begin
             with regs do
             begin
                      dx:=pnum;
                      ah:=1;
                      al:=data;
                      intr($14,regs);
                      if ah > $7F then commerr:=true else commerr:=false;
             end;
    end;

function commStatus;
   begin
            with regs do
            begin
                     dx:=pnum;
                     ah:=3;
                     intr($14,regs);
                     commstatus:=ax;
            end;
   end;

procedure Rece;
   begin
            commerr:=false;
            errstatus:=0;
            with regs do
            begin
                     dx:=pnum;
                     ah:=2;
                     intr($14,regs);
                     if ah > 0 then
                     begin
                              commerr:=true;
                              errstatus:=ah;
                     end
                     else data:=al;
            end;
   end;

end.