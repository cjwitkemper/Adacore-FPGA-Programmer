# STM32F070RB Blinky

Ada/SPARK project for STM32F0 microcontrollers.

## Prerequisites

1. **Alire** (minimum version 2.1.0)
   - Download from: https://alire.ada.dev
   - Verify installation:
     ```bash
     alr --version
     ```

2. **OpenOCD** (for flashing the board)
   - **Linux (Debian/Ubuntu)**:
     ```bash
     sudo apt install openocd
     ```
   - **Windows**:
     ```
     choco install openocd
     ```
## Setup

### 1. Add a dependency to the light_tasking_stm32f0xx runtime crate
Edit the `alire.toml` file. At the bottom of the file add:
```toml
[[depends-on]]
light_tasking_stm32f0xx = "*"

[configuration.values]
light_tasking_stm32f0xx.MCU_Sub_Family            = "F070"
light_tasking_stm32f0xx.MCU_Pin_Count             = "R"
light_tasking_stm32f0xx.MCU_User_Code_Memory_Size = "B"

light_tasking_stm32f0xx.SYSCLK_Src = "PLL"
light_tasking_stm32f0xx.PLL_Src    = "HSI_2"
light_tasking_stm32f0xx.PLLMUL     = 12
light_tasking_stm32f0xx.AHB_Pre    = "DIV1"
light_tasking_stm32f0xx.APB_Pre    = "DIV1"
```

### 2. Configure the project file
Edit the project file `stm32f070rb_blinky.gpr`.    

- At the top add:
`with "runtime_build.gpr";`

- Directly after `project Stm32f070rb_Blinky is` add the following:
```
for Target use runtime_build'Target;
for Runtime ("Ada") use runtime_build'Runtime ("Ada");
```

- Ensure you include all `src` subfolders:
```ada
for Source_Dirs use ("src/**", "config/");
```

- After the compiler section add the following:
```
package Linker is
  for Switches ("Ada") use Runtime_Build.Linker_Switches;
end Linker;
```

### 3. Generate Device Interfaces (if needed)

The device interfaces are already included in `src/devices/`, but if you need to regenerate them:

**Install svd2ada**:
- Download from: https://github.com/AdaCore/svd2ada

**Generate the device files:**

```bash
# Create directories
mkdir -p src/devices svd

# Download SVD file
wget -O svd/STM32F0x0.svd https://raw.githubusercontent.com/modm-io/cmsis-svd-stm32/main/stm32f0/STM32F0x0.svd

# Generate Ada bindings
svd2ada -o src/devices/ svd/STM32F0x0.svd
```

## Build

```bash
alr build
```

## Flash to Board

### Using OpenOCD

To flash the compiled binary to the STM32F070RB board:

- **Connect the board** via USB.
- **Flash using OpenOCD:**

```bash
openocd -f interface/stlink.cfg -f target/stm32f0x.cfg -c "program bin/stm32f070rb_blinky verify reset exit"
```

## Project Structure

```
stm32f070rb_blinky/
├── src/
│   ├── stm32f070rb_blinky.adb  # Main program
│   └── devices/                # STM32F0 device interfaces
├── svd/                        # SVD files
├── tests/                      # Test suite
├── alire.toml                  # Alire configuration
└── stm32f070rb_blinky.gpr      # GNAT project file
```

## Dependencies

This project uses the `light_tasking_stm32f0xx` crate from the Alire index (requires index 1.4+).
