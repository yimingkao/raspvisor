# If cross compiling from windows use native GNU-Make 4.2.1
# https://sourceforge.net/projects/ezwinports/files/
# download "make-4.2.1-without-guile-w32-bin.zip" and set it on the enviroment path
# There is no need to install cygwin or any of that sort of rubbish

# This little section enables us to make compatible windows and linux make files
RM = -rm -rf
SLASH = /
MKDIR := /bin/mkdir -p

# You will need to change the first line (ARMGNU) of these to match your compiler directories
#ARMGNU := aarch64-elf
ARMGNU := /home/android_camera/iCatchtek/tool-chain10/bin/aarch64-icatchtek-elf
SMARTSTART := SmartStart64.S
SPECIAL_FLAGS := -mcpu=cortexa53 -mstrict-align -fno-tree-loop-vectorize -fno-tree-slp-vectorize

ifeq ($(EL1), YES)
LINKER_FILE := rpi64-el1.ld
else
LINKER_FILE := rpi64.ld
endif

INCLUDEPATH ?= FreeRTOS

# Temp directory for object files to go into
TOP_DIR := .
BUILD_DIR ?= ${TOP_DIR}/build

# Set the C compilation flags common to all platforms.
CFLAGS  :=

# Optimize for speed.
CFLAGS += -O0

# Enable most useful compiler warnings.
CFLAGS  += -Wall

# Require full prototypes for all functions.
CFLAGS  += -Wstrict-prototypes

# Do not allow gcc to replace function calls with calls to gcc builtins, except
# when explicitly requested through a __builtin prefix.  This ensures that gcc
# does not attempt to replace any of our code with its own.
CFLAGS  += -fno-builtin

# Assume that the memory locations pointed to by any two pointers can alias,
# even if the types of the variables pointed to are not compatible as defined in
# the C standard.  Enabling this option is fairly common, since most programmers
# don't fully understand aliasing in C, and this forces the "expected" behavior.
CFLAGS  += -fno-strict-aliasing

# Do not allow multiple definitions of uninitialized global variables.
CFLAGS  += -fno-common 

# Place each function in a separate section so that the linker can apply garbage
# collection to remove unused functions (the --gc-sections linker flag).
CFLAGS  += -ffunction-sections

# Do not generate position-independent code.  (This flag may be unneeded, since
# generally you have to specify -fPIC to *get* the compiler to generate
# position-independent code).
CFLAGS  += -fno-pic

# Treat signed overflow as fully defined as per two's complement arithmetic,
# even though the C standard specifies that signed overflow is undefined
# behavior.  Many programmers are not aware of this, so we force the expected
# behavior.
CFLAGS  += -fwrapv

# ADD any special AARCH compile mode flags
CFLAGS  += $(SPECIAL_FLAGS)

ifeq ($(EL1), YES)
  CFLAGS += -DEL1_BUILD=1 -ffreestanding -nostartfiles -std=c11 -mcpu=cortex-a53
  IMGFILE := FreeRTOS.bin
else
  CFLAGS += -ffreestanding -nostartfiles -std=c11 -mcpu=cortex-a53
  IMGFILE := kernel8.img
endif

# Set linker flags common to all platforms.  platformVars can add additional
# flags if needed.  Do not use the "-Wl," prefix either here on in platformVars.
LDFLAGS := -Wl,-T $(LINKER_FILE) -Wl,--gc-sections -Wl,--build-id=none

# Set default external libraries.  FreeRTOS is, of course, stand-alone and
# ordinarily does not need to be linked to any external libraries; however,
# platformVars can add -lgcc to this if needed by the platform.
LDLIBS  := -lc -lm -lgcc

# platform name
PLATFORM := RaspberryPi

# The loader directory should have a directory to match the platform string
# In that directory is a Makerules file that specifies what .C and .S files to include
# They will appear in the C_FILES and S_FILES lists respectively
# (The loader should always be first entry, ensuring the image starts with it if you want multiple directories.)
SYSCOMPS := $(TOP_DIR)/loader/$(PLATFORM)
INCLUDEPATH1 ?=  $(TOP_DIR)/loader/$(PLATFORM)
INCLUDEPATH2 ?=  $(TOP_DIR)/FreeRTOS/Source/include
INCLUDEPATH3 ?=  $(TOP_DIR)/FreeRTOS/Source/portable/GCC/$(PLATFORM)

INCLUDE = -I$(INCLUDEPATH1) -I$(INCLUDEPATH2) -I$(INCLUDEPATH3) -I$(TOP_DIR)/Demo

# Directory which has our demo files to compile
DEMOCOMPS := $(TOP_DIR)/Demo

# Directory that has the FreeRTOS source
RTOSCOMPS := $(TOP_DIR)/FreeRTOS/Source

# List of all components to include  ... Loader + FreeRTOS + Demo
COMPS := $(SYSCOMPS) $(RTOSCOMPS) $(DEMOCOMPS)

# Include component files, each should add its part to the compile source
# This builds two lists C_FILES and S_FILES from iteration thru the makerules files
COMP_SRC :=
include $(COMPS:%=%/Makerules)

CFILES := $(strip $(filter-out %.S, $(COMP_SRC)))
SFILES := $(strip $(filter-out %.c, $(COMP_SRC)))
SOFILES := $(patsubst %.S,$(BUILD_DIR)/%.o, $(notdir $(SFILES)))
COFILES := $(patsubst %.c,$(BUILD_DIR)/%.o, $(notdir $(CFILES)))

all: create_folder freertos.elf

# Control silent mode  .... we want silent in clean
.SILENT: clean
clean :
	$(RM) build
	$(RM) *.elf
	$(RM) *.list
	$(RM) *.map
	$(RM) *.img FreeRTOS.bin
.PHONY: clean

# How we compile assembler files
$(SOFILES): $(SFILES)
	$(ARMGNU)-gcc -MMD -MP -g -c $(CFLAGS) $(INCLUDE) $(filter %/$(patsubst %.o,%.S,$(notdir $@)), $(SFILES)) -c -o $@ -lc -lm -lgcc

# How we compile C files
 $(COFILES): $(CFILES)
	$(ARMGNU)-gcc -MMD -MP -g -c $(CFLAGS) $(INCLUDE) $(filter %/$(patsubst %.o,%.c,$(notdir $@)), $(CFILES)) -c -o $@ -lc -lm -lgcc

$(SFILES): ;
$(CFILES): ;


create_folder:
	$(MKDIR) build
.PHONY: create_folder

freertos.elf : $(SOFILES) $(COFILES)
	$(ARMGNU)-gcc $(CFLAGS) -o $@ $(LDFLAGS) $^ $(LDLIBS)
	$(ARMGNU)-objdump -d freertos.elf > freertos.list
	$(ARMGNU)-objcopy freertos.elf -O binary $(IMGFILE)
	$(ARMGNU)-nm -n freertos.elf > freertos.map
