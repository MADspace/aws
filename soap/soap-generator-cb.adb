------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                            Copyright (C) 2003                            --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimkov - Pascal Obry                                --
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

--  $Id$

separate (SOAP.Generator)
package body CB is

   -----------------
   -- End_Service --
   -----------------

   procedure End_Service
     (O    : in out Object;
      Name : in     String)
   is
      L_Name : constant String := Format_Name (O, Name);
      Buffer : String (1 .. 1_024);
      Last   : Natural;
   begin
      --  Spec

      Text_IO.New_Line (CB_Ads);
      Text_IO.Put_Line (CB_Ads, "end " & L_Name & ".Cb;");

      --  Copy SOAP_CB definition now

      Text_IO.Reset (Tmp_Adb, Text_IO.In_File);

      while not Text_IO.End_Of_File (Tmp_Adb) loop
         Text_IO.Get_Line (Tmp_Adb, Buffer, Last);
         Text_IO.Put_Line (CB_Adb, Buffer (1 .. Last));
      end loop;

      --  End SOAP_CB

      Text_IO.New_Line (CB_Adb);
      Text_IO.Put_Line (CB_Adb, "      else");
      Text_IO.Put_Line (CB_Adb, "         return Message.Response.Build");
      Text_IO.Put_Line (CB_Adb, "            (Message.Response.Error.Build");
      Text_IO.Put_Line (CB_Adb,
                        "               (Message.Response.Error.Client,");
      Text_IO.Put_Line
        (CB_Adb,
         "                  ""Wrong SOAP action "" & SOAPAction));");
      Text_IO.Put_Line (CB_Adb, "      end if;");

      Text_IO.Put_Line (CB_Adb, "   end SOAP_CB;");

      --  Body

      Text_IO.New_Line (CB_Adb);
      Text_IO.Put_Line (CB_Adb, "end " & L_Name & ".Cb;");
   end End_Service;

   -------------------
   -- New_Procedure --
   -------------------

   procedure New_Procedure
     (O          : in out Object;
      Proc       : in     String;
      SOAPAction : in     String;
      Namespace  : in     String;
      Input      : in     WSDL.Parameters.P_Set;
      Output     : in     WSDL.Parameters.P_Set;
      Fault      : in     WSDL.Parameters.P_Set)
   is
      pragma Unreferenced
        (SOAPAction, Namespace, Input, Output, Fault);

      use type WSDL.Parameters.P_Set;

      L_Proc : constant String := Format_Name (O, Proc);
   begin
      Text_IO.New_Line (CB_Adb);

      Text_IO.Put_Line (CB_Adb, "   function " & Proc & "_CB is");
      Text_IO.Put_Line (CB_Adb, "      new " & To_String (O.Unit)
                          & ".Server." & L_Proc & "_CB ("
                          & To_String (O.Types_Spec) & "." & Proc & ");");

      --  Write SOAP_CB body

      if O.First_Proc then
         Text_IO.Put (Tmp_Adb, "      if ");
         O.First_Proc := False;
      else
         Text_IO.Put (Tmp_Adb, "      elsif ");
      end if;

      Text_IO.Put_Line (Tmp_Adb, "SOAPAction = """ & Proc & """ then");
      Text_IO.Put_Line (Tmp_Adb, "         return " & Proc
                          & "_CB (SOAPAction, Payload, Request);");
      Text_IO.New_Line (Tmp_Adb);
   end New_Procedure;

   -------------------
   -- Start_Service --
   -------------------

   procedure Start_Service
     (O             : in out Object;
      Name          : in     String;
      Documentation : in     String;
      Location      : in     String)
   is
      pragma Unreferenced (Location, Documentation);

      L_Name : constant String := Format_Name (O, Name);
   begin
      --  Spec

      Text_IO.Put_Line (CB_Ads, "with AWS.Response;");
      Text_IO.Put_Line (CB_Ads, "with AWS.Server;");
      Text_IO.Put_Line (CB_Ads, "with AWS.Status;");
      Text_IO.New_Line (CB_Ads);
      Text_IO.Put_Line (CB_Ads, "with SOAP.Dispatchers.Callback;");
      Text_IO.Put_Line (CB_Ads, "with SOAP.Message.Payload;");
      Text_IO.New_Line (CB_Ads);
      Text_IO.Put_Line (CB_Ads, "package " & L_Name & ".Cb is");
      Text_IO.New_Line (CB_Ads);
      Text_IO.Put_Line (CB_Ads, "   use AWS;");
      Text_IO.Put_Line (CB_Ads, "   use SOAP;");
      Text_IO.New_Line (CB_Ads);
      Text_IO.Put_Line
        (CB_Ads,
         "   subtype Handler is SOAP.Dispatchers.Callback.Handler;");

      Text_IO.New_Line (CB_Ads);
      Text_IO.Put_Line (CB_Ads, "   function SOAP_CB");
      Text_IO.Put_Line (CB_Ads, "     (SOAPAction : in String;");
      Text_IO.Put_Line (CB_Ads,
                        "      Payload    : in Message.Payload.Object;");
      Text_IO.Put_Line (CB_Ads, "      Request    : in AWS.Status.Data)");
      Text_IO.Put_Line (CB_Ads, "      return Response.Data;");

      --  Body

      Text_IO.Put_Line (CB_Adb, "with SOAP.Client;");
      Text_IO.Put_Line (CB_Adb, "with SOAP.Message.Response.Error;");
      Text_IO.New_Line (CB_Adb);
      Text_IO.Put_Line (CB_Adb, "with " & To_String (O.Types_Spec) & ";");
      Text_IO.New_Line (CB_Adb);
      Text_IO.Put_Line (CB_Adb, "with " & L_Name & ".Server;");
      Text_IO.Put_Line (CB_Adb, "with " & L_Name & ".Types;");
      Text_IO.New_Line (CB_Adb);
      Text_IO.Put_Line (CB_Adb, "package body " & L_Name & ".Cb is");
      Text_IO.New_Line (CB_Adb);
      Text_IO.Put_Line (CB_Adb, "   use SOAP;");

      --  Tmp body

      Text_IO.New_Line (Tmp_Adb);
      Text_IO.Put_Line (Tmp_Adb, "   -------------");
      Text_IO.Put_Line (Tmp_Adb, "   -- SOAP_CB --");
      Text_IO.Put_Line (Tmp_Adb, "   -------------");
      Text_IO.New_Line (Tmp_Adb);
      Text_IO.Put_Line (Tmp_Adb, "   function SOAP_CB");
      Text_IO.Put_Line (Tmp_Adb, "     (SOAPAction : in String;");
      Text_IO.Put_Line (Tmp_Adb,
                        "      Payload    : in Message.Payload.Object;");
      Text_IO.Put_Line (Tmp_Adb, "      Request    : in AWS.Status.Data)");
      Text_IO.Put_Line (Tmp_Adb, "      return Response.Data is");
      Text_IO.Put_Line (Tmp_Adb, "   begin");
   end Start_Service;

end CB;
