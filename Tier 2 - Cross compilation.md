- [ ] First, compile and run a hello_world C program on the emulated environment.
- [ ] Gain familiarity with static/dynamic linkage issues.
- [ ] Be able to compile a runtime and a `.vmfb` to run them in the armv8 in the QEMU.

## Compiling and running hello_world on a different architecture

### Reading material

- <https://ruvi-d.medium.com/a-master-guide-to-linux-cross-compiling-b894bf909386>
- <https://ruvi-d.medium.com/toolchains-a-horror-story-bef1ef522292>

## Dear Diary

The QEMU run line just in case:

```
emu-system-aarch64 -machine virt -cpu cortex-a72 -m 2G -bios /usr/share/qemu-efi-aarch64/QEMU_EFI.fd -drive if=virtio,file=debian-12-generic-arm64.qcow2 -drive file=seed.img,if=virtio -netdev user,id=net0,hostfwd=tcp::2222-:22 -device virtio-net-pci,netdev=net0 -nographi
```

1. Downloaded the toolchain via apt

```bash
sudo apt install gcc-aarch64-linux-gnu -y
```

2. Created a `hello_world.c` file under `qemu/`.
   1. `gcc qemu/hello_world.c -o hello_world_native; ./hello_world_native` - Works amazing.
   2. `aarch64-linux-gnu-gcc qemu/hello_world.c -o hello_world_aarch64; ./hello_world_aarch64` - Outputs: `bash: ./hello_world_aarch64: cannot execute binary file: Exec format error`.
   3. Let's send it to the QEMU: `cp -P 2222 ./hello_world_aarch64 debian@localhost:/home/debian`.
   4. On the emulator: `./hello_world_aarch64`: `Hello world`- It works!

## Questions

- What does a toolchain contain aside from the actual compiler?
- How can I tell the target triple on a device with no gcc installed (can't `gcc -dumpmachine`).
- What is the meaning of the `-march=` flag?
-
