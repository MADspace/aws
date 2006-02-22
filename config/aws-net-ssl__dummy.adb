------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2006                            --
--                                 AdaCore                                  --
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

--  This is a dummy implementation used when AWS is built without SSL
--  support. Every use of this interface will raise the Program_Error
--  exception.

with System;

package body AWS.Net.SSL is

   type TS_SSL is new System.Address;

   -------------------
   -- Accept_Socket --
   -------------------

   procedure Accept_Socket
     (Socket     : in     Net.Socket_Type'Class;
      New_Socket : in out Socket_Type) is
   begin
      raise Program_Error;
   end Accept_Socket;

   -------------
   -- Connect --
   -------------

   procedure Connect
     (Socket   : in out Socket_Type;
      Host     : in     String;
      Port     : in     Positive;
      Wait     : in     Boolean := True) is
   begin
      raise Program_Error;
   end Connect;

   ------------------
   -- Do_Handshake --
   ------------------

   procedure Do_Handshake (Socket : in out Socket_Type) is
   begin
      raise Program_Error;
   end Do_Handshake;

   ----------
   -- Free --
   ----------

   procedure Free (Socket : in out Socket_Type) is
   begin
      raise Program_Error;
   end Free;

   ----------------
   -- Initialize --
   ----------------

   procedure Initialize
     (Config               : in out SSL.Config;
      Certificate_Filename : in     String;
      Security_Mode        : in     Method     := SSLv23;
      Key_Filename         : in     String     := "";
      Exchange_Certificate : in     Boolean    := False) is
   begin
      raise Program_Error;
   end Initialize;

   -------------
   -- Pending --
   -------------

   function Pending (Socket : in Socket_Type) return Stream_Element_Count is
   begin
      raise Program_Error;
      return 0;
   end Pending;

   -------------
   -- Receive --
   -------------

   procedure Receive
     (Socket : in     Socket_Type;
      Data   :    out Stream_Element_Array;
      Last   :    out Stream_Element_Offset) is
   begin
      raise Program_Error;
   end Receive;

   -------------
   -- Release --
   -------------

   procedure Release (Config : in out SSL.Config) is
   begin
      raise Program_Error;
   end Release;

   -------------------
   -- Secure_Client --
   -------------------

   function Secure_Client
     (Socket : in Net.Socket_Type'Class;
      Config : in SSL.Config := Null_Config) return Socket_Type
   is
      pragma Unreferenced (Socket, Config);
      S : Socket_Type;
   begin
      raise Program_Error;
      return S;
   end Secure_Client;

   -------------------
   -- Secure_Server --
   -------------------

   function Secure_Server
     (Socket : in Net.Socket_Type'Class;
      Config : in SSL.Config := Null_Config) return Socket_Type
   is
      pragma Unreferenced (Socket, Config);
      S : Socket_Type;
   begin
      raise Program_Error;
      return S;
   end Secure_Server;

   ----------
   -- Send --
   ----------

   procedure Send
     (Socket : in     Socket_Type;
      Data   : in     Stream_Element_Array;
      Last   :    out Stream_Element_Offset) is
   begin
      raise Program_Error;
   end Send;

   ----------------
   -- Set_Config --
   ----------------

   procedure Set_Config
     (Socket : in out Socket_Type;
      Config : in     SSL.Config) is
   begin
      raise Program_Error;
   end Set_Config;

   --------------
   -- Shutdown --
   --------------

   procedure Shutdown (Socket : in Socket_Type) is
   begin
      raise Program_Error;
   end Shutdown;

   -----------------
   -- Socket_Pair --
   -----------------

   procedure Socket_Pair (S1, S2 : out Socket_Type) is
   begin
      raise Program_Error;
   end Socket_Pair;

end AWS.Net.SSL;