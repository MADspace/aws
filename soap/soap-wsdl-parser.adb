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

with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with DOM.Core.Nodes;

with SOAP.Types;
with SOAP.Utils;

package body SOAP.WSDL.Parser is

   use Ada;
   use Ada.Exceptions;
   use Ada.Strings.Unbounded;
   use type DOM.Core.Node;

   Verbose_Mode : Verbose_Level := 0;
   Skip_Error   : Boolean       := False;

   function Get_Node
     (Parent  : in DOM.Core.Node;
      Element : in String;
      Name    : in String        := "";
      NS      : in Boolean       := False)
      return DOM.Core.Node;
   --  Returns child node named Name

   function First_Child (Parent : in DOM.Core.Node) return DOM.Core.Node;
   --  Returns the first child, ship #text nodes

   function Next_Sibling (N : in DOM.Core.Node) return DOM.Core.Node;
   --  Returns the next sibling, ship #text nodes

   function Length (NL : in DOM.Core.Node_List) return Natural;
   --  Returns the number of nodes in NT, ship #text nodes

   function Get_Attr_Value
     (N    : in DOM.Core.Node;
      Name : in String;
      NS   : in Boolean := True)
      return String;
   pragma Inline (Get_Attr_Value);
   --  Returns attribute value for attribute Name in node N. Return the empty
   --  string if the attribute does not exist.

   function "+" (Str : in String) return Unbounded_String
     renames To_Unbounded_String;

   function "-" (Str : in Unbounded_String) return String
     renames To_String;

   procedure Parse_Service
     (O        : in out Object'Class;
      Service  : in     DOM.Core.Node;
      Document : in     WSDL.Object);
   --  Parse WSDL service nodes

   procedure Parse_Binding
     (O        : in out Object'Class;
      Binding  : in     DOM.Core.Node;
      Document : in     WSDL.Object);
   --  Parse WSDL binding nodes

   procedure Parse_Operation
     (O         : in out Object'Class;
      Operation : in     DOM.Core.Node;
      Document  : in     WSDL.Object);
   --  Parse WSDL operation nodes

   procedure Parse_PortType
     (O         : in out Object'Class;
      Operation : in     DOM.Core.Node;
      Document  : in     WSDL.Object);
   --  Parse WSDL PortType nodes

   procedure Parse_Part
     (O        : in out Object'Class;
      Part     : in     DOM.Core.Node;
      Document : in     WSDL.Object);
   --  Parse WSDL part nodes

   procedure Parse_Message
     (O        : in out Object'Class;
      Message  : in     DOM.Core.Node;
      Document : in     WSDL.Object);
   --  Parse WSDL message nodes

   procedure Parse_Element
     (O        : in out Object'Class;
      Element  : in     DOM.Core.Node;
      Document : in     WSDL.Object);
   --  Parse WSDL element nodes

   procedure Add_Parameter
     (O      : in out Object'Class;
      Name   : in     String;
      P_Type : in     Parameter_Type);
   pragma Inline (Add_Parameter);
   --  Add parameter Name / P_Type into O using current mode (O.Mode)

   procedure Add_Parameter
     (O     : in out Object'Class;
      Param : in     Parameters.Parameter);
   pragma Inline (Add_Parameter);
   --  Add parameter into O using current mode (O.Mode)

   function Parse_Parameter
     (O        : in Object'Class;
      N        : in DOM.Core.Node;
      Document : in WSDL.Object)
      return Parameters.Parameter;
   --  Returns parameter in node P

   function Parse_Record
     (O        : in Object'Class;
      R        : in DOM.Core.Node;
      Document : in WSDL.Object)
      return Parameters.Parameter;
   --  Returns record in node N

   function Parse_Array
     (O        : in Object'Class;
      R        : in DOM.Core.Node;
      Document : in WSDL.Object)
      return Parameters.Parameter;
   --  Returns array in node N

   -----------
   -- Debug --
   -----------

   procedure Trace (Message : in String; N : in DOM.Core.Node);
   --  Display trace message and info about the node

   ----------------
   -- Accept_RPC --
   ----------------

   procedure Accept_Document (O : in out Object'Class) is
   begin
      O.Accept_Document := True;
   end Accept_Document;

   -------------------
   -- Add_Parameter --
   -------------------

   procedure Add_Parameter
     (O      : in out Object'Class;
      Name   : in     String;
      P_Type : in     Parameter_Type) is
   begin
      Add_Parameter (O, (Parameters.K_Simple, +Name, null, P_Type));
   end Add_Parameter;

   procedure Add_Parameter
     (O     : in out Object'Class;
      Param : in     Parameters.Parameter) is
   begin
      Parameters.Append (O.Params (O.Mode), Param);
   end Add_Parameter;

   -----------------------
   -- Continue_On_Error --
   -----------------------

   procedure Continue_On_Error is
   begin
      Skip_Error := True;
   end Continue_On_Error;

   -----------------
   -- End_Service --
   -----------------

   procedure End_Service
     (O    : in out Object;
      Name : in     String)
   is
      pragma Unreferenced (O);
      pragma Unreferenced (Name);
   begin
      null;
   end End_Service;

   -----------------
   -- First_Child --
   -----------------

   function First_Child (Parent : in DOM.Core.Node) return DOM.Core.Node is
      N : DOM.Core.Node;
   begin
      Trace ("(First_Child)", Parent);

      N := DOM.Core.Nodes.First_Child (Parent);

      while N /= null and then DOM.Core.Nodes.Node_Name (N) = "#text" loop
         N := DOM.Core.Nodes.Next_Sibling (N);
      end loop;

      return N;
   end First_Child;

   --------------------
   -- Get_Attr_Value --
   --------------------

   function Get_Attr_Value
     (N    : in DOM.Core.Node;
      Name : in String;
      NS   : in Boolean := True)
      return String
   is
      A : DOM.Core.Node;
   begin
      Trace ("(Get_Attr_Value) - " & Name, N);

      A := DOM.Core.Nodes.Get_Named_Item (DOM.Core.Nodes.Attributes (N), Name);

      if A = null then
         return "";
      else

         declare
            V : constant String := DOM.Core.Nodes.Node_Value (A);
         begin
            if NS then
               return V;
            else
               return Utils.No_NS (V);
            end if;
         end;
      end if;
   end Get_Attr_Value;

   --------------
   -- Get_Node --
   --------------

   function Get_Node
     (Parent  : in DOM.Core.Node;
      Element : in String;
      Name    : in String        := "";
      NS      : in Boolean       := False)
      return DOM.Core.Node
   is
      function Get_Node_Int
        (Parent  : in DOM.Core.Node;
         Element : in String;
         Name    : in String)
         return DOM.Core.Node;

      K : Positive := Element'First;
      E : Natural;
      N : DOM.Core.Node := Parent;

      ------------------
      -- Get_Node_Int --
      ------------------

      function Get_Node_Int
        (Parent  : in DOM.Core.Node;
         Element : in String;
         Name    : in String)
         return DOM.Core.Node
      is
         N : DOM.Core.Node;
      begin
         --  Iterate through childs, look for "service"

         N := First_Child (Parent);

         while N /= null loop
            exit when
              ((not NS and then DOM.Core.Nodes.Local_Name (N) = Element)
               or else (NS and then DOM.Core.Nodes.Node_Name (N) = Element))
              and then (Name = "" or else Get_Attr_Value (N, "name") = Name);
            N := Next_Sibling (N);
         end loop;

         return N;
      end Get_Node_Int;

   begin
      Trace ("(Get_Node) - " & Element & " -> " & Name, Parent);

      while K < Element'Last loop
         E := Strings.Fixed.Index (Element (K .. Element'Last), ".");

         if E = 0 then
            E := Element'Last;
            N := Get_Node_Int (N, Element (K .. E), Name);
         else
            E := E - 1;
            N := Get_Node_Int (N, Element (K .. E), "");
         end if;

         K := E + 2;
      end loop;

      return N;
   end Get_Node;

   ------------
   -- Length --
   ------------

   function Length (NL : in DOM.Core.Node_List) return Natural is
      Result : Natural := 0;
   begin
      for K in 0 .. DOM.Core.Nodes.Length (NL) - 1 loop
         declare
            N : constant DOM.Core.Node := DOM.Core.Nodes.Item (NL, K);
         begin
            if DOM.Core.Nodes.Node_Name (N) /= "#text" then
               Result := Result + 1;
            end if;
         end;
      end loop;

      return Result;
   end Length;

   -------------------
   -- New_Procedure --
   -------------------

   procedure New_Procedure
     (O          : in out Object;
      Proc       : in     String;
      SOAPAction : in     String;
      Namespace  : in     String;
      Input      : in     Parameters.P_Set;
      Output     : in     Parameters.P_Set;
      Fault      : in     Parameters.P_Set)
   is
      pragma Unreferenced (O, Proc, SOAPAction, Namespace);
      pragma Unreferenced (Input, Output, Fault);
   begin
      null;
   end New_Procedure;

   ------------------
   -- Next_Sibling --
   ------------------

   function Next_Sibling (N : in DOM.Core.Node) return DOM.Core.Node is
      M : DOM.Core.Node := N;
   begin
      Trace ("(Next_Sibling)", N);

      loop
         M := DOM.Core.Nodes.Next_Sibling (M);
         exit when M = null or else DOM.Core.Nodes.Node_Name (M) /= "#text";
      end loop;

      return M;
   end Next_Sibling;

   -----------
   -- Parse --
   -----------

   procedure Parse
     (O        : in out Object'Class;
      Document : in     WSDL.Object)
   is
      N     : constant DOM.Core.Node := First_Child (DOM.Core.Node (Document));
      NL    : constant DOM.Core.Node_List := DOM.Core.Nodes.Child_Nodes (N);
      Found : Boolean := False;
   begin
      for K in 0 .. DOM.Core.Nodes.Length (NL) - 1 loop
         declare
            S : constant DOM.Core.Node := DOM.Core.Nodes.Item (NL, K);
         begin
            if DOM.Core.Nodes.Node_Name (S) = "service" then
               Parse_Service (O, DOM.Core.Nodes.Item (NL, K), Document);
               Found := True;
            end if;
         end;
      end loop;

      if Verbose_Mode > 0 and then not Found then
         Text_IO.New_Line;
         Text_IO.Put_Line ("No service found in this document.");
      end if;
   end Parse;

   -----------------
   -- Parse_Array --
   -----------------

   function Parse_Array
     (O        : in Object'Class;
      R        : in DOM.Core.Node;
      Document : in WSDL.Object)
      return Parameters.Parameter
   is
      pragma Unreferenced (Document);

      P : Parameters.Parameter (Parameters.K_Composite);
   begin
      Trace ("(Parse_Array)", R);

      pragma Assert
        (R /= null
         and then DOM.Core.Nodes.Node_Name (R) = "complexType");

      declare
         Name : constant String := Get_Attr_Value (R, "name", False);
      begin
         --  Set array name, R is a complexType node

         if Name = "ArrayOfanyType" then
            Raise_Exception
              (WSDL_Error'Identity, "ArrayOfanyType not supported.");
         end if;

         P.Name   := O.Current_Name;
         P.C_Name := +Name;

         return P;
      end;
   end Parse_Array;

   -------------------
   -- Parse_Binding --
   -------------------

   procedure Parse_Binding
     (O        : in out Object'Class;
      Binding  : in     DOM.Core.Node;
      Document : in     WSDL.Object)
   is
      N : DOM.Core.Node;
   begin
      Trace ("(Parse_Binding)", Binding);

      N := Get_Node (Binding, "soap:binding", NS => True);

      --  Check for style (only Document is supported)

      if not O.Accept_Document
        and then Get_Attr_Value (N, "style") = "document"
      then
         Raise_Exception
           (WSDL_Error'Identity, "Document Web Service style not supported.");
      end if;

      --  Check for transport (only HTTP is supported)

      declare
         T : constant String := Get_Attr_Value (N, "transport");
      begin
         if T (T'Last - 4 .. T'Last) /= "/http" then
            Raise_Exception
              (WSDL_Error'Identity, "Only HTTP transport supported.");
         end if;
      end;

      --  Read all operations

      declare
         NL : constant DOM.Core.Node_List
           := DOM.Core.Nodes.Child_Nodes (Binding);
      begin
         for K in 0 .. DOM.Core.Nodes.Length (NL) - 1 loop
            declare
               S : constant DOM.Core.Node := DOM.Core.Nodes.Item (NL, K);
            begin
               if DOM.Core.Nodes.Node_Name (S) = "operation" then
                  begin
                     Parse_Operation
                       (O, DOM.Core.Nodes.Item (NL, K), Document);
                  exception
                     when E : WSDL_Error =>
                        if Skip_Error then
                           Text_IO.Put_Line
                             ("     "
                                & Get_Attr_Value (S, "name")
                                & " skipped : "
                                & Exceptions.Exception_Message (E));
                        else
                           Text_IO.New_Line;
                           Text_IO.Put_Line
                             ("Error in operation "
                                & Get_Attr_Value (S, "name")
                                & " : " & Exceptions.Exception_Message (E));
                           raise;
                        end if;
                  end;
               end if;
            end;
         end loop;
      end;
   end Parse_Binding;

   -------------------
   -- Parse_Element --
   -------------------

   procedure Parse_Element
     (O        : in out Object'Class;
      Element  : in     DOM.Core.Node;
      Document : in     WSDL.Object)
   is
      N        : DOM.Core.Node := Element;
      Sequence : Boolean;
      CT_Node  : DOM.Core.Node;
   begin
      Trace ("(Parse_Element)", Element);

      while N /= null
        and then DOM.Core.Nodes.Local_Name (N) /= "complexType"
      loop
         N := First_Child (N);
      end loop;

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity, "No element found in schema.");
      else
         CT_Node := N;
      end if;

      N := First_Child (N);

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity, "No element found in schema.");

      elsif DOM.Core.Nodes.Local_Name (N) = "sequence" then
         Sequence := True;

      else
         Sequence := False;
      end if;

      declare
         NL   : constant DOM.Core.Node_List := DOM.Core.Nodes.Child_Nodes (N);
         Name : constant String := Get_Attr_Value (CT_Node, "name");
      begin
         if (Length (NL) > 1 and then not Sequence) then
            --  This is a record or composite type

            Add_Parameter (O, Parse_Record (O, CT_Node, Document));

         elsif Utils.Is_Array (Name) then

            Add_Parameter (O, Parse_Array (O, CT_Node, Document));

         else

            for K in 0 .. DOM.Core.Nodes.Length (NL) - 1 loop
               declare
                  N : constant DOM.Core.Node := DOM.Core.Nodes.Item (NL, K);
               begin
                  if DOM.Core.Nodes.Node_Name (N) /= "#text" then
                     Add_Parameter (O, Parse_Parameter (O, N, Document));
                  end if;
               end;
            end loop;
         end if;
      end;
   end Parse_Element;

   -------------------
   -- Parse_Message --
   -------------------

   procedure Parse_Message
     (O        : in out Object'Class;
      Message  : in     DOM.Core.Node;
      Document : in     WSDL.Object)
   is
      N : DOM.Core.Node := Message;
   begin
      Trace ("(Parse_Message)", Message);

      N := First_Child (N);

      while N /= null loop
         Parse_Part (O, N, Document);
         N := Next_Sibling (N);
      end loop;
   end Parse_Message;

   ---------------------
   -- Parse_Operation --
   ---------------------

   procedure Parse_Operation
     (O         : in out Object'Class;
      Operation : in     DOM.Core.Node;
      Document  : in     WSDL.Object)
   is
      N : DOM.Core.Node;
   begin
      Trace ("(Parse_Operation)", Operation);

      O.Proc := +Get_Attr_Value (Operation, "name");

      N := Get_Node (Operation, "soap:operation", NS => True);

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity, "soap:operation not found.");
      end if;

      O.SOAPAction := +Get_Attr_Value (N, "soapAction");

      N := Next_Sibling (N);
      N := First_Child (N);

      O.Namespace  := +Get_Attr_Value (N, "namespace");

      --  Check that input/output/fault is literal
      --  ???

      N := Get_Node
        (First_Child (DOM.Core.Node (Document)),
         "portType.operation", -O.Proc);

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity,
            "portType.operation for " & (-O.Proc) & " not found.");
      end if;

      Parse_PortType (O, N, Document);
   end Parse_Operation;

   ---------------------
   -- Parse_Parameter --
   ---------------------

   function Parse_Parameter
     (O        : in Object'Class;
      N        : in DOM.Core.Node;
      Document : in WSDL.Object)
      return Parameters.Parameter
   is
      P_Type : constant String := Get_Attr_Value (N, "type", False);
   begin
      Trace ("(Parse_Parameter)", N);

      if Is_Standard (P_Type) then
         return (Parameters.K_Simple, +Get_Attr_Value (N, "name"),
                 null, To_Type (P_Type));

      elsif P_Type = "anyType" then
         Raise_Exception
           (WSDL_Error'Identity, "Type anyType is not supported.");

      else
         declare
            R : constant DOM.Core.Node
              := Get_Node (DOM.Core.Node (Document),
                           "definitions.types.schema.complexType", P_Type);
         begin
            if R = null then
               Raise_Exception
                 (WSDL_Error'Identity,
                  "types.schema.complexType for !!" & P_Type & " not found.");
            end if;

            if Utils.Is_Array (P_Type) then
               declare
                  P : Parameters.Parameter := Parse_Array (O, R, Document);
               begin
                  P.Name := +Get_Attr_Value (N, "name");
                  return P;
               end;

            else
               return Parse_Record (O, R, Document);
            end if;
         end;
      end if;
   end Parse_Parameter;

   ----------------
   -- Parse_Part --
   ----------------

   procedure Parse_Part
     (O        : in out Object'Class;
      Part     : in     DOM.Core.Node;
      Document : in     WSDL.Object)
   is
      N       : DOM.Core.Node;
      ET      : Unbounded_String;
   begin
      Trace ("(Parse_Part)", Part);

      ET := +Get_Attr_Value (Part, "element");

      if ET = Null_Unbounded_String then
         ET := +Get_Attr_Value (Part, "type");
      end if;

      if ET = Null_Unbounded_String then
         Raise_Exception
           (WSDL_Error'Identity,
            "No type or element attribute found for part element.");
      end if;

      O.Current_Name := +Get_Attr_Value (Part, "name");

      declare
         T : constant String := -ET;
      begin
         if T = Types.XML_Int then
            Add_Parameter (O, -O.Current_Name, P_Integer);

         elsif T = Types.XML_Float then
            Add_Parameter (O, -O.Current_Name, P_Float);

         elsif T = Types.XML_String then
            Add_Parameter (O, -O.Current_Name, P_String);

         elsif T = Types.XML_Boolean then
            Add_Parameter (O, -O.Current_Name, P_Boolean);

         elsif T = Types.XML_Time_Instant then
            Add_Parameter (O, -O.Current_Name, P_Time);

         elsif T = Types.XML_Date_Time then
            Add_Parameter (O, -O.Current_Name, P_Time);

         elsif T = Types.XML_Base64_Binary then
            Add_Parameter (O, -O.Current_Name, P_B64);

         elsif T = Types.XML_Any_Type then
            Raise_Exception
              (WSDL_Error'Identity,
               "Type anyType is not supported.");

         else
            --  First search for element in the schema

            N := Get_Node
              (First_Child (DOM.Core.Node (Document)),
               "types.schema.element", Utils.No_NS (-ET));

            --  If not present look for a complexType

            if N = null then
               N := Get_Node
                 (First_Child (DOM.Core.Node (Document)),
                  "types.schema.complexType", Utils.No_NS (-ET));
            end if;

            Parse_Element (O, N, Document);
         end if;
      end;
   end Parse_Part;

   --------------------
   -- Parse_PortType --
   --------------------

   procedure Parse_PortType
     (O         : in out Object'Class;
      Operation : in     DOM.Core.Node;
      Document  : in     WSDL.Object)
   is
      procedure Get_Element (M : in DOM.Core.Node);
      --  Returns the element node which contains parameters for node M

      -----------------
      -- Get_Element --
      -----------------

      procedure Get_Element (M : in DOM.Core.Node) is
         N       : DOM.Core.Node;
         Message : Unbounded_String;
      begin
         Message := +Get_Attr_Value (M, "message", False);

         N := Get_Node
           (First_Child (DOM.Core.Node (Document)),
            "message", -Message);

         if N = null then
            --  In this case the message reference the schema element.

            N := Get_Node
              (First_Child (DOM.Core.Node (Document)),
               "types.schema.element", -Message);

            if N = null then
               Raise_Exception
                 (WSDL_Error'Identity,
                  "types.schema.element for " & (-Message) & " not found.");
            end if;

            Parse_Element (O, N, Document);

         else
            Parse_Message (O, N, Document);
         end if;
      end Get_Element;

      N : DOM.Core.Node;

   begin
      Trace ("(Parse_PortType)", Operation);

      --  Input parameters

      N := Get_Node (Operation, "input");

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity, "No input parameters description found.");
      else
         O.Mode := Input;
         Get_Element (N);
      end if;

      --  Output parameters

      N := Get_Node (Operation, "output");

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity, "No output parameters description found.");
      else
         O.Mode := Output;
         Get_Element (N);
      end if;

      --  Fault parameters

      N := Get_Node (Operation, "fault");

      if N /= null then
         O.Mode := Fault;
         Get_Element (N);
      end if;

      if Verbose_Mode > 0 then
         Text_IO.New_Line;
         Text_IO.Put_Line ("Procedure " & (-O.Proc));
         Text_IO.Put_Line ("   Input");
         Parameters.Output (O.Params (Input));

         Text_IO.Put_Line ("   Output");
         Parameters.Output (O.Params (Output));
      end if;

      New_Procedure
        (O, -O.Proc, -O.SOAPAction, -O.Namespace,
         O.Params (Input), O.Params (Output), O.Params (Fault));

      Parameters.Release (O.Params (Input));
      Parameters.Release (O.Params (Output));
      Parameters.Release (O.Params (Fault));
   end Parse_PortType;

   ------------------
   -- Parse_Record --
   ------------------

   function Parse_Record
     (O        : in Object'Class;
      R        : in DOM.Core.Node;
      Document : in WSDL.Object)
      return Parameters.Parameter
   is
      P : Parameters.Parameter (Parameters.K_Composite);
      N : DOM.Core.Node;
   begin
      Trace ("(Parse_Record)", R);

      pragma Assert
        (R /= null
         and then DOM.Core.Nodes.Node_Name (R) = "complexType");

      declare
         Name : constant String := Get_Attr_Value (R, "name", False);
      begin
         --  Set record name, R is a complexType node

         P.Name   := O.Current_Name;
         P.C_Name := +Name;

         --  Enter complexType element

         N := First_Child (R);

         --  Get first element

         N := First_Child (N);

         while N /= null loop
            Parameters.Append (P.P, Parse_Parameter (O, N, Document));
            N := Next_Sibling (N);
         end loop;

         return P;
      end;
   end Parse_Record;

   -------------------
   -- Parse_Service --
   -------------------

   procedure Parse_Service
     (O        : in out Object'Class;
      Service  : in     DOM.Core.Node;
      Document : in     WSDL.Object)
   is
      N             : DOM.Core.Node;
      Name          : Unbounded_String;
      Documentation : Unbounded_String;
      Location      : Unbounded_String;
      Binding       : Unbounded_String;
   begin
      Trace ("(Parse_Service)", Service);

      Name := +Get_Attr_Value (Service, "name");

      N := Get_Node (Service, "documentation");

      if N /= null then
         DOM.Core.Nodes.Normalize (N);
         Documentation :=
           +DOM.Core.Nodes.Node_Value (DOM.Core.Nodes.First_Child (N));
      end if;

      N := Get_Node (Service, "port.soap:address", NS => True);

      if N /= null then
         Location := +Get_Attr_Value (N, "location");
      end if;

      Start_Service (O, -Name, -Documentation, -Location);

      --  Look for the right binding

      N := Get_Node (Service, "port");

      if N /= null then
         Binding := +Get_Attr_Value (N, "binding", False);
      end if;

      N := Get_Node
        (First_Child (DOM.Core.Node (Document)),
         "binding", -Binding);

      if N = null then
         Raise_Exception
           (WSDL_Error'Identity,
            "binding for " & (-Binding) & " not found.");
      end if;

      Parse_Binding (O, N, Document);

      End_Service (O, -Name);
   end Parse_Service;

   -------------------
   -- Start_Service --
   -------------------

   procedure Start_Service
     (O             : in out Object;
      Name          : in     String;
      Documentation : in     String;
      Location      : in     String)
   is
      pragma Unreferenced (O, Name, Documentation, Location);
   begin
      null;
   end Start_Service;

   -----------
   -- Trace --
   -----------

   procedure Trace (Message : in String; N : in DOM.Core.Node) is
   begin
      if Verbose_Mode = 2 then
         Text_IO.Put_Line (Message);

         if N = null then
            Text_IO.Put_Line ("   Node is null.");
         else
            declare
               Name : constant String
                 := DOM.Core.Nodes.Local_Name (N);
               Atts : constant DOM.Core.Named_Node_Map
                 := DOM.Core.Nodes.Attributes (N);
            begin
               Text_IO.Put_Line ("   " & Name);

               for K in 0 .. DOM.Core.Nodes.Length (Atts) - 1 loop
                  Text_IO.Put ("      ");
                  declare
                     N    : constant DOM.Core.Node
                       := DOM.Core.Nodes.Item (Atts, K);
                     Name  : constant String := DOM.Core.Nodes.Local_Name (N);
                     Value : constant String := DOM.Core.Nodes.Node_Value (N);
                  begin
                     Text_IO.Put (Name & " = " & Value);
                  end;
                  Text_IO.New_Line;
               end loop;
            end;
         end if;
      end if;
   end Trace;

   -------------
   -- Verbose --
   -------------

   procedure Verbose (Level : in Verbose_Level := 1) is
   begin
      Verbose_Mode := Level;
   end Verbose;

end SOAP.WSDL.Parser;
