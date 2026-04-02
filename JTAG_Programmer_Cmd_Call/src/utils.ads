pragma Style_Checks (Off);
with Interfaces;
package utils is

TMS_Pin : constant := 4; -- PA4
TCK_Pin : constant := 5; -- PA5
TDO_Pin : constant := 6; -- PA6
TDI_Pin : constant := 7; -- PA7
type Bit is mod 2**1
   with Size => 1;
type Byte is new Interfaces.Unsigned_8;
type Bit_Array is array (Natural range <>) of Bit;

Buffer_Size : constant := 512;
type Byte_Array is array (0 .. Buffer_Size - 1) of Byte with Volatile;
DMA_Buffer  : aliased Byte_Array;  --  USART2 RX  (DMA1 Channel 5)
DMA1_Buffer : aliased Byte_Array;  --  USART1 RX  (DMA1 Channel 3)
type State is (IDLE, INIT_CONFIG, PROG_BITSTREAM, PROG_FIRMWARE, ESCAPE);
protected type ProgState is
   procedure Set (V : in State);
   function  Get return State;
   private
      Value : State := IDLE;
end ProgState;
Current_State : ProgState;

procedure Pin_Low(Pin : Natural);
procedure Pin_High(Pin : Natural);
procedure Pulse_TCK;
procedure SPI_Enable;
procedure SPI_Disable;
procedure Transceive_Byte (Data_Out : Byte);
procedure Transceive_Last_Byte (Data_Out : Byte);

end Utils;