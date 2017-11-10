with Ada.Text_IO; use Ada.Text_IO;

package body Bitcoin.Script is
  use Byte_Array_Stacks;

  -----------------
  -- Comparisons --
  -----------------
  function Is_Zero (Bytes : in Byte_Array) return Boolean is (Bytes = (Bytes'Range => 16#00#));
  function Is_One  (Bytes : in Byte_Array) return Boolean is begin
    return (for all I in Bytes'First .. Bytes'Last => Bytes (I) = 16#00#) and then Bytes (Bytes'Last) = 16#01#;
  end;

  ------------
  -- Parser --
  ------------
  package body Parser is
    Program_Counter : Natural := Script'First - 1;

    function  At_EOS  return Boolean is (Program_Counter > Script'Last);
    function  Peek    return Byte    is (Script (Positive'Succ (Program_counter)));
    function  Current return Byte    is (Script (Program_Counter));
    function  Next    return Byte    is begin Skip; return Current; end;
    procedure Skip                   is begin Program_Counter := Positive'Succ (Program_counter); end;
    function  Assert     (Opcodes : in Opcode_Kind_Array) return Boolean is begin return (for some Opcode of Opcodes => Opcode = Peek); end;
    procedure Skip_Until (Opcodes : in Opcode_Kind_Array) is begin while not Assert (Opcodes) loop Skip; end loop; end;
    procedure Skip_Until (Opcode  : in Opcode_Kind)       is begin Skip_Until ((1 => Opcode)); end;
    procedure Ensure     (Opcodes : in Opcode_Kind_Array) is begin if not Assert (Opcodes) then raise Unexpected_Opcode; end if; end;
    procedure Ensure     (Opcode  : in Opcode_Kind)       is begin Ensure ((1 => Opcode)); end;

    -------------------
    -- Skip_If_Block --
    -------------------
    procedure Skip_If_Block is begin
      Skip_Until ((OP_IF, OP_NOTIF, OP_ELSE, OP_ENDIF));
      while Assert ((OP_IF, OP_NOTIF)) loop
        Skip;
        Skip_If_Else_Block;
        Skip_Until ((OP_IF, OP_NOTIF, OP_ELSE, OP_ENDIF));
      end loop;
    end;

    ---------------------
    -- Skip_Else_Block --
    ---------------------
    procedure Skip_Else_Block is begin
      Skip_Until ((OP_IF, OP_NOTIF, OP_ELSE, OP_ENDIF));
      while Assert ((OP_IF, OP_NOTIF, OP_ELSE)) loop
        Skip;
        Skip_If_Else_Block;
        Skip_Until ((OP_IF, OP_NOTIF, OP_ELSE, OP_ENDIF));
      end loop;
    end;

    ------------------------
    -- Skip_If_Else_Block --
    ------------------------
    procedure Skip_If_Else_Block is begin
      Skip_If_Block;
      Ensure ((OP_ELSE, OP_ENDIF));
      if Next = OP_ENDIF then return; end if;
      Skip_Else_Block;
      Ensure (OP_ENDIF);
      Skip;
    end;
  end;

  ----------------------
  -- Combine Unsigned --
  ----------------------
  function Combine (High, Low                  : in Byte)        return Unsigned_16 is (Shift_Left (Unsigned_16 (High), 8)  or Unsigned_16 (Low));
  function Combine (High, Low                  : in Unsigned_16) return Unsigned_32 is (Shift_Left (Unsigned_32 (High), 16) or Unsigned_32 (Low));
  function Combine (Highest, High, Low, Lowest : in Byte)        return Unsigned_32 is (Combine (Combine (Highest, High), Combine (Low, Lowest)));

  --------------
  -- Evaluate --
  --------------
  procedure Evaluate (Script : in Byte_Array) is
    package Script_Parser is new Parser (Script); use Script_Parser;

    Primary_Stack   : Stack_Type;
    Secondary_Stack : Stack_Type;

    -------------------------
    -- Push_Bytes_To_Stack --
    -------------------------
    procedure Push_Bytes_To_Stack (Stack : in out Stack_Type; Quantity : in Positive) is
      Accumulator : Byte_Array := (1 .. Quantity => 0);
    begin
      for I in Accumulator'Range loop Accumulator (I) := Next; end loop;
      Push (Stack, Accumulator);
    end;

    ---------------------
    -- Evaluate_Opcode --
    ---------------------
    procedure Evaluate_Opcode (Opcode : in Opcode_Kind) is

      ----------------------------
      -- Evaluate_If_Else_Block --
      ----------------------------
      procedure Evaluate_If_Else_Block is
        Top : Byte_Array := Pop (Primary_Stack);
      begin
        if ((Current = OP_IF    and then not Is_Zero (Top))
        or  (Current = OP_NOTIF and then     Is_Zero (Top))) then
          while not Assert ((OP_ELSE, OP_ENDIF)) loop Evaluate_Opcode (Next); end loop;
          Ensure ((OP_ELSE, OP_ENDIF));
          if Next = OP_ENDIF then return; end if;
          Skip_Else_Block;
          Ensure (OP_ENDIF);
          Skip;
        else
          Skip_If_Block;
          Ensure ((OP_ELSE, OP_ENDIF));
          if Next = OP_ENDIF then return; end if;
          while not Assert (OP_ENDIF) loop Evaluate_Opcode (Next); end loop;
          Ensure (OP_ENDIF);
          Skip;
        end if;
      end;

    begin
    
      if not Opcode'Valid then
        if not (To_Byte (Opcode) in Data_Count_Range) then raise Invalid_Opcode; end if;
        Put_Line ("Push Data: " & Byte'Image (To_Byte(Opcode)));
        Push_Bytes_To_Stack (Primary_Stack, Positive (To_Byte (Opcode)));
        return;
      end if;
      
      Put_Line ("Evaluate Opcode: " & Opcode_Kind'Image (Opcode));

      case Opcode is

        when Disabled_Opcode_Kind => raise Disabled_Opcode;
        when Reserved_Opcode_Kind => raise Reserved_Opcode;
        when Ignored_Opcode_Kind  => null;

        ----------
        -- Data --
        ----------
        -- An empty array of bytes is pushed onto the stack. (This is not a no-op: an item is added to the stack.)
        when OP_0 => Push (Primary_Stack, (1 .. 4 => 16#00#));

        -- The number -1 is pushed onto the stack.
        when OP_1NEGATE => Push (Primary_Stack, (1 .. 4 => 16#FF#));

        -- The number in the word name (1-16) is pushed onto the stack.
        when OP_1 .. OP_16 => Push (Primary_Stack, (1 .. 3 => 16#00#, 4 => (To_Byte (Opcode) - (To_Byte (OP_1) - 16#01#))));

        -- The next byte contains the number of bytes to be pushed onto the stack.
        when OP_PUSHDATA1 => Push_Bytes_To_Stack (Primary_Stack, Positive (To_Byte (Next)));

        -- The next two bytes contain the number of bytes to be pushed onto the stack.
        when OP_PUSHDATA2 => Push_Bytes_To_Stack (Primary_Stack, Positive (Combine (Next, Next)));

        -- The next four bytes contain the number of bytes to be pushed onto the stack.
        when OP_PUSHDATA4 => Push_Bytes_To_Stack (Primary_Stack, Positive (Combine (Next, Next, Next, Next)));

        ------------------
        -- Flow Control --
        ------------------
        -- Does nothing.
        when OP_NOP => null;

        -- OP_IF: If the top stack value is not False, the statements are executed. The top stack value is removed.
        -- OP_NOTIF: If the top stack value is False, the statements are executed. The top stack value is removed.
        when OP_IF .. OP_NOTIF => Evaluate_If_Else_Block;

        -- OP_ELSE: If the preceding OP_IF or OP_NOTIF or OP_ELSE was not executed then these statements are 
        --          and if the preceding OP_IF or OP_NOTIF or OP_ELSE was executed then these statements are not.
        -- OP_ENDIF: Ends an if/else block. All blocks must end, or the transaction is invalid. An OP_ENDIF without 
        --           OP_IF earlier is also invalid.
        -- These are only expected inside an IF/NOTIF block
        when OP_ELSE .. OP_ENDIF => raise Unexpected_Opcode;

        -- Marks transaction as invalid if top stack value is not true.
        when OP_VERIFY => if not Is_One (Pop (Primary_Stack)) then raise Verification_Failed; end if;

        -- Marks transaction as invalid. A standard way of attaching extra data to transactions is to add a zero-value
        -- output with a scriptPubKey consisting of OP_RETURN followed by exactly one pushdata op. Such outputs are 
        -- provably unspendable, reducing their cost to the network. Currently it is usually considered non-standard 
        -- (though valid) for a transaction to have more than one OP_RETURN output or an OP_RETURN output with more 
        -- than one pushdata op.
        when OP_RETURN => raise Op_Return_Encountered;

        -----------
        -- Stack --
        -----------
        -- Puts the input onto the top of the alt stack. Removes it from the main stack.
        when OP_TOALTSTACK => Push (Secondary_Stack, Pop (Primary_Stack));

        -- Puts the input onto the top of the main stack. Removes it from the alt stack.
        when OP_FROMALTSTACK => Push (Primary_Stack, Pop (Secondary_Stack));

        -- Puts the number of stack items onto the stack.
        when OP_DEPTH => Push (Primary_Stack, (1 => Byte (Size (Primary_Stack))));

        -- Removes the top stack item.
        when OP_DROP =>
          Pop (Primary_Stack);

        -- Removes the top two stack items.
        when OP_2DROP => 
          Pop (Primary_Stack); 
          Pop (Primary_Stack);

        -- Duplicates the top stack item.
        when OP_DUP => 
          Push (Primary_Stack, Peek (Primary_Stack));

        -- Duplicates the top two stack items.
        when OP_2DUP => 
          Push (Primary_Stack, Peek (Primary_Stack));
          Push (Primary_Stack, Peek (Primary_Stack));

        -- Duplicates the top three stack items.
        when OP_3DUP => 
          Push (Primary_Stack, Peek (Primary_Stack));
          Push (Primary_Stack, Peek (Primary_Stack)); 
          Push (Primary_Stack, Peek (Primary_Stack));

        -- If the top stack value is not 0, duplicate it.
        when OP_IFDUP => if Peek (Primary_Stack) /= (1 => 0) then Push (Primary_Stack, Peek (Primary_Stack)); end if;

        -- Removes the second-to-top stack item.
        when OP_NIP => 
          declare First : Byte_Array := Pop (Primary_Stack); begin
            Pop (Primary_Stack);
            Push (Primary_Stack, First);
          end;

        -- Copies the second-to-top stack item to the top.
        -- [1, 2] => [2, 1, 2]
        when OP_OVER => 
          declare 
            First  : Byte_Array := Pop  (Primary_Stack);
            Second : Byte_Array := Peek (Primary_Stack);
          begin
            Push (Primary_Stack, First);
            Push (Primary_Stack, Second);
          end;

        -- Copies the pair of items two spaces back in the stack to the front.
        -- [1, 2] => [1, 2, 1, 2]
        when OP_2OVER =>
          declare 
            First  : Byte_Array := Pop  (Primary_Stack);
            Second : Byte_Array := Peek (Primary_Stack);
          begin
            Push (Primary_Stack, First);
            Push (Primary_Stack, Second);
            Push (Primary_Stack, First);
          end;

        -- The top three items on the stack are rotated to the left.
        -- [1, 2, 3] => [2, 3, 1]
        when OP_ROT =>
          declare 
            First  : Byte_Array := Pop (Primary_Stack);
            Second : Byte_Array := Pop (Primary_Stack);
            Third  : Byte_Array := Pop (Primary_Stack);
          begin
            Push (Primary_Stack, First);
            Push (Primary_Stack, Third);
            Push (Primary_Stack, Second);
          end;

        -- The fifth and sixth items back are moved to the top of the stack.
        -- [1, 2, 3, 4, 5, 6] =>  [5, 6, 1, 2, 3, 4]
        when OP_2ROT => 
          declare 
            First  : Byte_Array := Pop (Primary_Stack);
            Second : Byte_Array := Pop (Primary_Stack);
            Third  : Byte_Array := Pop (Primary_Stack);
            Fourth : Byte_Array := Pop (Primary_Stack);
            Fifth  : Byte_Array := Pop (Primary_Stack);
            Sixth  : Byte_Array := Pop (Primary_Stack);
          begin
            Push (Primary_Stack, Fourth);
            Push (Primary_Stack, Third);
            Push (Primary_Stack, Second);
            Push (Primary_Stack, First);
            Push (Primary_Stack, Sixth);
            Push (Primary_Stack, Fifth);
          end;

        -- The top two items on the stack are swapped.
        -- [1, 2] => [2, 1]
        when OP_SWAP => 
          declare 
            First  : Byte_Array := Pop (Primary_Stack);
            Second : Byte_Array := Pop (Primary_Stack);
          begin
            Push (Primary_Stack, First);
            Push (Primary_Stack, Second);
          end;

        -- Swaps the top two pairs of items.
        -- [1, 2, 3, 4] => [3, 4, 1, 2]
        when OP_2SWAP =>
          declare 
            First  : Byte_Array := Pop (Primary_Stack);
            Second : Byte_Array := Pop (Primary_Stack);
            Third  : Byte_Array := Pop (Primary_Stack);
            Fourth : Byte_Array := Pop (Primary_Stack);
          begin
            Push (Primary_Stack, Second);
            Push (Primary_Stack, First);
            Push (Primary_Stack, Fourth);
            Push (Primary_Stack, Third);
          end;

        -- The item n back in the stack is copied to the top.
        when OP_PICK => null;

        -- The item n back in the stack is moved to the top.
        when OP_ROLL => null;

        -- The item at the top of the stack is copied and inserted before the second-to-top item.
        when OP_TUCK => null;

        ------------
        -- Splice --
        ------------
        when OP_SIZE => Push (Primary_Stack, (1 => Byte (Peek (Primary_Stack)'Length)));

        when others => raise Unimplemented_Feature with Opcode_Kind'Image (Opcode);
      end case;
    end;
  begin
    while not At_EOS loop Evaluate_Opcode (Next); end loop;
  end;
end;
