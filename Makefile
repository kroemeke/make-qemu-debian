MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:
BUILDDIR := build
DEBIAN_IMG_URL := https://cdimage.debian.org/images/cloud/sid/daily/latest/debian-sid-generic-amd64-daily.qcow2
DEBIAN_IMG_FILE := debian.qcow2
KERNEL_CMDLINE := root=PARTUUID=4c26831d-eb9c-4239-9b6b-48fa177baff4 ro console=tty0 console=ttyS0,115200 earlyprintk=ttyS0,115200 consoleblank=0 debug

.PHONY: all
all: prepare cidata download extract run

.PHONY: prepare
prepare:
	mkdir -p $(BUILDDIR)
	mkdir -p $(BUILDDIR)/boot

.PHONY: clean
clean:
	rm cidata.iso
	rm vmlinuz
	rm initrd
	rm -rf $(BUILDDIR)

.PHONY: distclean
distclean: clean
	rm $(DEBIAN_IMG_FILE)

.PHONY: download
download:
	wget $(DEBIAN_IMG_URL) -O $(DEBIAN_IMG_FILE)

.PHONY: cidata
cidata:
	echo "Creating cloud-init iso image"
	xorrisofs -o cidata.iso -V cidata -r -J cidata/

.PHONY: extract
extract:
	@echo "Extracting grub.cfg from $(DEBIAN_IMG_FILE)"
	@virt-cat -a $(DEBIAN_IMG_FILE) /boot/grub/grub.cfg > $(BUILDDIR)/grub.cfg
	@sed -nE '/^\s*linux\s+\/boot\/vmlinuz-[^ ]+/ { s|^\s*linux\s+(/boot/vmlinuz-[^ ]+).*|\1|p; q }' $(BUILDDIR)/grub.cfg > $(BUILDDIR)/kernel.path
	@sed -nE '/^\s*initrd\s+\/boot\/initrd.img-[^ ]+/ { s|^\s*initrd\s+(/boot/initrd.img-[^ ]+).*|\1|p; q }' $(BUILDDIR)/grub.cfg > $(BUILDDIR)/initrd.path
	@echo "Extracting vmlinuz and initrd from $(DEBIAN_IMG_FILE)"
	@bash -c '\
       KERNELPATH=$$(cat $(BUILDDIR)/kernel.path); \
       INITRDPATH=$$(cat $(BUILDDIR)/initrd.path); \
       echo "Kernel: $$KERNELPATH"; \
			 virt-cat -a $(DEBIAN_IMG_FILE) $$KERNELPATH > $(BUILDDIR)$$KERNELPATH; \
       echo "Initrd: $$INITRDPATH"; \
			 virt-cat -a $(DEBIAN_IMG_FILE) $$INITRDPATH > $(BUILDDIR)$$INITRDPATH; \
			 cp $(BUILDDIR)$$KERNELPATH vmlinuz; \
			 cp $(BUILDDIR)$$INITRDPATH initrd; \
    '

.PHONY: run
run:
	qemu-system-x86_64 \
		-enable-kvm \
		-nographic \
		-m 1G \
		-cdrom cidata.iso \
		-kernel vmlinuz \
		-initrd initrd \
		-append '$(KERNEL_CMDLINE)' \
		-drive file=$(DEBIAN_IMG_FILE),format=qcow2,index=0,media=disk \
		-serial mon:stdio
