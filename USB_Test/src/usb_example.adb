with STM32;           use STM32;
with STM32.Device;    use STM32.Device;
with STM32.GPIO;      use STM32.GPIO;
with STM32.USARTs;    use STM32.USARTs;
with STM32_SVD.USART; use STM32_SVD.USART;
with HAL;             use HAL;
with Ada.Real_Time;   use Ada.Real_Time;
with System; use System;
with System.Storage_Elements; use System.Storage_Elements;
with Interfaces; use Interfaces;

procedure Main is
   USART2_BRR  : Unsigned_32 with Address => To_Address (16#4000_440C#);

   COM_Port : USART renames USART_2;
   Incoming_Byte : UInt9; 
   Next_Time     : Time;

   -- The User LED on Nucleo-F070RB is PA5
   LED : GPIO_Point renames PA5;
begin
   -- 1. Initialize LED first so we can see if we get past clock init
   Enable_Clock (GPIO_A);
   Configure_IO (LED, (Mode => Mode_Out, Resistors => Floating, others => <>));
   Set (LED); -- Turn it on immediately so we know the chip reached this line

   -- 2. Power up USART2
   Enable_Clock (COM_Port);
   Configure_IO (PA2, (Mode => Mode_AF, AF => GPIO_AF_TIM1_1, others => <>));
   Configure_IO (PA3, (Mode => Mode_AF, AF => GPIO_AF_TIM1_1, others => <>));

   -- 2. Manual Baud Rate Override (Assuming 48MHz)
   -- We reach into the SVD (System View Description) to set the register directly
   USART2_BRR := 16#01A1#; --  115200 @ 48MHz

   -- 3. Set standard settings
   Set_Word_Length (COM_Port, Word_Length_8);
   Set_Stop_Bits (COM_Port, Stopbits_1);
   Set_Parity (COM_Port, No_Parity);
   Set_Mode (COM_Port, Tx_Rx_Mode);
   
   Enable (COM_Port);

   Next_Time := Clock;

   loop
      -- Toggle LED every 500ms
      Toggle (LED);

      -- Echo Logic
      if Rx_Ready (COM_Port) then
         Receive (COM_Port, Incoming_Byte);
         while not Tx_Ready (COM_Port) loop
            null;
         end loop;
         Transmit (COM_Port, Incoming_Byte);
      end if;

      Next_Time := Next_Time + Milliseconds (500);
      delay until Next_Time;
   end loop;
end Main;