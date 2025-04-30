ARMGNU ?= /home/android_camera/iCatchtek/tool-chain10/bin/aarch64-icatchtek-elf

COPS = -Wall -nostdlib -nostartfiles -ffreestanding -Iinclude -mgeneral-regs-only
ASMOPS = -Iinclude

BUILD_DIR = build
SRC_DIR = src

.PHONY: all
all : kernel8.img

.PHONY: clean
clean :
	rm -rf $(BUILD_DIR) *.img

$(BUILD_DIR)/%_c.o: $(SRC_DIR)/%.c
	mkdir -p $(@D)
	$(ARMGNU)-gcc $(COPS) -MMD -c $< -o $@

$(BUILD_DIR)/%_s.o: $(SRC_DIR)/%.S
	$(ARMGNU)-gcc $(ASMOPS) -MMD -c $< -o $@

C_FILES = $(wildcard $(SRC_DIR)/*.c)
ASM_FILES = $(wildcard $(SRC_DIR)/*.S)
OBJ_FILES = $(C_FILES:$(SRC_DIR)/%.c=$(BUILD_DIR)/%_c.o)
OBJ_FILES += $(ASM_FILES:$(SRC_DIR)/%.S=$(BUILD_DIR)/%_s.o)

DEP_FILES = $(OBJ_FILES:%.o=%.d)
-include $(DEP_FILES)

kernel8.img: $(SRC_DIR)/linker.ld $(OBJ_FILES)
	$(ARMGNU)-ld -T $(SRC_DIR)/linker.ld -o $(BUILD_DIR)/kernel8.elf  $(OBJ_FILES)
	$(ARMGNU)-objcopy $(BUILD_DIR)/kernel8.elf -O binary kernel8.img
	$(ARMGNU)-objdump -d $(BUILD_DIR)/kernel8.elf > kernel8.list

.PHONY: install
install: kernel8.img
	#rm -rf $(SD_BOOT_DIR)/*.img
	#cp src/config.txt $(SD_BOOT_DIR)
	#cp kernel8.img $(SD_BOOT_DIR)
	#-umount $(SD_BOOT_DIR)
	#-umount $(SD_ROOTFS_DIR)
	@echo "kernel8.img build successfully!"

.PHONY: serial
serial:
	cu -s 115200 -l /dev/ttyUSB0
