package Utils is

TMS_Pin : constant := 4; -- PA4
TCK_Pin : constant := 5; -- PA5
TDO_Pin : constant := 6; -- PA6
TDI_Pin : constant := 7; -- PA7
type Bit_Array is array (Natural range <>) of Bit;

Buffer_Size : constant := 512;
type Byte_Array is array (0 .. Buffer_Size - 1) of Byte with Volatile;
DMA_Buffer  : aliased Byte_Array;  --  USART2 RX  (DMA1 Channel 5)
DMA1_Buffer : aliased Byte_Array;  --  USART1 RX  (DMA1 Channel 3)

type ProgState is (IDLE, PROG_BITSTREAM, PROG_FIRMWARE);
protected State is
   procedure Set_Value (V : in Integer);
   function  Get_Value return Integer;
   private
      pState : ProgState := IDLE;
end State;

procedure Pin_Low;
procedure Pin_High;
procedure Pulse_TCK;
procedure SPI_Enable;
procedure SPI_Disable;

end Utils;