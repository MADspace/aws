------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2004                            --
--                                ACT-Europe                                --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

with System.Address_To_Access_Conversions;

with AWS.Net.Thin;

function Poll
  (Fds     : in System.Address;
   Nfds    : in AWS.OS_Lib.Definitions.nfds_t;
   Timeout : in C.int)
   return C.int
is
   use AWS.Net;
   use AWS.OS_Lib;

   use type Thin.Events_Type;
   use type C.int;
   use type C.long;
   use type System.Address;

   Failure : constant C.int := -1;

   type Timeval is record
      tv_sec  : C.long; -- Seconds
      tv_usec : C.long; -- Microseconds
   end record;
   pragma Convention (C, Timeval);

   subtype Nfds_Range is Definitions.nfds_t range 1 .. Nfds;

   type FD_Array is array (Nfds_Range) of C.int;
   pragma Convention (C, FD_Array);

   type Poll_Array is array (FD_Array'Range) of Thin.Pollfd;
   pragma Convention (C, Poll_Array);

   package Conversion is
     new System.Address_To_Access_Conversions (Poll_Array);

   type FD_Set_Type is record
      Count : C.int := 0;
      Set   : FD_Array;
   end record;
   pragma Convention (C, FD_Set_Type);

   procedure FD_SET (FD : in C.int; Set : in out FD_Set_Type);
   pragma Inline (FD_SET);

   function FD_ISSET (FD : in C.int; Set : in System.Address) return C.int;
   pragma Import (Stdcall, FD_ISSET, "__WSAFDIsSet");

   function C_Select
     (Nfds      : in C.int;
      readfds   : in System.Address;
      writefds  : in System.Address;
      exceptfds : in System.Address;
      timeout   : in System.Address)
      return C.int;
   pragma Import (Stdcall, C_Select, "select");

   Poll_Ptr : constant Conversion.Object_Pointer
     := Conversion.To_Pointer (Fds);

   Timeout_V : aliased Timeval;

   Rfds : aliased FD_Set_Type;
   Wfds : aliased FD_Set_Type;
   Efds : aliased FD_Set_Type;

   Rfdsa : System.Address;
   Wfdsa : System.Address;

   FD_Events : Thin.Events_Type;
   Rs        : C.int;

   ------------
   -- FD_SET --
   ------------

   procedure FD_SET (FD : in C.int; Set : in out FD_Set_Type) is
   begin
      Set.Count := Set.Count + 1;
      Set.Set (Definitions.nfds_t (Set.Count)) := FD;
   end FD_SET;

begin
   if Fds = System.Null_Address then
      return Failure;
   end if;

   --  Setup (convert data from Poll to Select layout)

   Timeout_V.tv_sec  := C.long (Timeout) / 1000;
   Timeout_V.tv_usec := C.long (Timeout) mod 1000;

   for J in Nfds_Range loop
      FD_Events := Poll_Ptr (J).Events;

      if (FD_Events and (Definitions.POLLIN or Definitions.POLLPRI)) /= 0 then
         FD_SET (C.int (Poll_Ptr (J).FD), Rfds);
      elsif (FD_Events and Definitions.POLLOUT) /= 0 then
         FD_SET (C.int (Poll_Ptr (J).FD), Wfds);
      end if;

      FD_SET (C.int (Poll_Ptr (J).FD), Efds);
   end loop;

   --  Any non-null descriptor set must contain at least one handle
   --  to a socket (MSDN).

   if Rfds.Count = 0 then
      Rfdsa := System.Null_Address;
   else
      Rfdsa := Rfds'Address;
   end if;

   if Wfds.Count = 0 then
      Wfdsa := System.Null_Address;
   else
      Wfdsa := Wfds'Address;
   end if;

   --  Call Win32 Select

   if Timeout < 0 then
      Rs := C_Select (0, Rfdsa, Wfdsa, Efds'Address, System.Null_Address);
   else
      Rs := C_Select (0, Rfdsa, Wfdsa, Efds'Address, Timeout_V'Address);
   end if;

   --  Build result (convert back from Select to Poll layout)

   if Rs > 0 then
      Rs := 0;

      for J in Nfds_Range loop
         Poll_Ptr (J).REvents := 0;

         if FD_ISSET (C.int (Poll_Ptr (J).FD), Rfds'Address) /= 0 then
            Poll_Ptr (J).REvents := Poll_Ptr (J).REvents or Definitions.POLLIN;
            Rs := Rs + 1;
         end if;

         if FD_ISSET (C.int (Poll_Ptr (J).FD), Wfds'Address) /= 0 then
            Poll_Ptr (J).REvents
              := Poll_Ptr (J).REvents or Definitions.POLLOUT;
            Rs := Rs + 1;
         end if;

         if FD_ISSET (C.int (Poll_Ptr (J).FD), Efds'Address) /= 0 then
            Poll_Ptr (J).REvents
              := Poll_Ptr (J).REvents or Definitions.POLLERR;
            Rs := Rs + 1;
         end if;
      end loop;
   end if;

   return Rs;
end Poll;
