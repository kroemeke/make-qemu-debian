# make-qemu-debian
Simple qemu Makefile for experimenting with latest kernels / debugging.

Downloads debian cloud image qcow2 file.
Bakes in cloud-init config into an iso
Extracts kernel and initrd from qcow2 file so that we can use -kernel and -initrd and -append in qemu
Boots up debian with cloud init iso and specified kernel.

TODO:
  * Add step to build latest kernel from Linus's tree
