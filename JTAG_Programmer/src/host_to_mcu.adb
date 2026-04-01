pragma Style_Checks (Off);
with STM32F0x0;               use STM32F0x0;
with STM32F0x0.USART;         use STM32F0x0.USART;
with Utils; use Utils;
package body host_to_mcu is

   procedure Put_Char (C : Character) is
   begin
      while USART2_Periph.ISR.TXE = 0 loop
         null;
      end loop;
      USART2_Periph.TDR.TDR := Character'Pos (C);
   end Put_Char;


   procedure Put_Line (S : String) is
   begin
      for C of S loop
         Put_Char (C);
      end loop;
      Put_Char (ASCII.CR);
      Put_Char (ASCII.LF);
   end Put_Line;

   function Get_Char return Character is
   begin
      while USART2_Periph.ISR.RXNE = 0 loop
         null;
      end loop;
      return Character'Val (USART2_Periph.RDR.RDR);
   end Get_Char;

   procedure Get_Line (Buffer : out String; Last : out Natural) is
      C : Character;
   begin
      Last := Buffer'First - 1;
      loop
         C := Get_Char;
         exit when C = ASCII.CR or C = ASCII.LF;
         exit when Last >= Buffer'Last;
         Last := Last + 1;
         Buffer (Last) := C;
      end loop;
   end Get_Line;

   task body H2M is 
      Input : String (1 .. 256);
      Last : Natural;
      cmd : String (1 .. 256);
   begin

      loop
         Get_Line (Input, Last);

         cmd := Input (1 .. Last);
         if cmd = "exit" then
            Put_Line ("Exiting...");
            Current_State.Set (ESCAPE);
            exit;
         end if;

         if cmd = "help" then
            Put_Line ("Available commands:");
            Put_Line ("  help - Show this help message");
            Put_Line ("  exit - Exit the program");
         elsif cmd = "config" then
            Put_Line ("Initialize FPGA configuration");
            Current_State.Set (INIT_CONFIG);
            while Current_State.Get /= IDLE 
            loop
               null;
            end loop;
            Put_Line ("Send Configuration Bitstream");
            Put_Line ("Configuring FPGA");
            Current_State.Set (PROG_BITSTREAM);
         elsif cmd = "upload" then
            Put_Line ("Send firmware file");
            Put_Line ("Uploading file...");
            Current_State.Set (PROG_FIRMWARE);
         else
            Put_Line ("Unknown command: " & cmd);
         end if;
      end loop;

   end H2M;  

end host_to_mcu;
