- [ ] First, compile and run a hello_world C program on the emulated environment.
- [ ] Repeat with gcc and clang
- [ ] Repeat in cmake
- [ ] Gain familiarity with static/dynamic linkage issues.
- [ ] Be able to compile a runtime and a `.vmfb` to run them in the armv8 in the QEMU.

## Compiling and running hello_world on a different architecture

### Reading material

- <https://ruvi-d.medium.com/a-master-guide-to-linux-cross-compiling-b894bf909386>
- <https://ruvi-d.medium.com/toolchains-a-horror-story-bef1ef522292>
- Advanced C and C++ Compiling, Stevanovic, Milan
- <https://cliutils.gitlab.io/modern-cmake/chapters/basics.html>

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
   5. Also `aarch64-linux-gnu-gcc -march=armv9.3-a qemu/hello_world.c -o hello_world_aarch64_armv9.3-a` works (though it kinda shouldn't)

3. Created `toy_project`.
   1. The naive compilation line `g++ -I. tools/main.cc src/func_a.cc -o main; ./main 2` Works fine
   2. The cmake version also works ok.
   3. Now trying to cross compile using the toolchain file at `raspberro_i_exp_1/toolchain-linux-armv6.cmake`.
      1. `cmake .. -DCMAKE_TOOLCHAIN_FILE=../../../raspberry_pi_exp_1/toolchain-linux-armv6.cmake ; make main`
      2. Does not work on the target machine:

```bash
./toy_project_main_aarch64: /lib/aarch64-linux-gnu/libstdc++.so.6: version `GLIBCXX_3.4.32' not found (required by ./toy_project_main_aarch64)
./toy_project_main_aarch64: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found (required by ./toy_project_main_aarch64)
```

1. .
   1. Now trying naive direct compilation: `aarch64-linux-gnu-g++ -I. tools/main.cc src/func_a.cc -o main_aarch64; ./main_aarch64 2`
   2. Exactly the same GLIBC errors,
   3. But! compiling statically `aarch64-linux-gnu-g++ -I. -static tools/main.cc src/func_a.cc -o main_aarch64; ./main_aarch64 2` Works...

### Another try

- Copying the `/lib` and `/usr/lib` from the QEMU to a random dir.
  - `scp -r -P 2222 debian@localhost:/lib/ debian@localhost:/usr/lib/ aarch64_sysroot/`
- Let's first try to make the command line work without `-static`
- Then via `cmake`.
- Toying around with the `--sysroot` option (both native gcc and cmake) didn't work. The problem seems to be related to glibc version mismatch:

```bash
./main_aarch64_cmake: /lib/aarch64-linux-gnu/libstdc++.so.6: version `GLIBCXX_3.4.32' not found (required by ./main_aarch64_cmake)
./main_aarch64_cmake: /lib/aarch64-linux-gnu/libc.so.6: version `GLIBC_2.38' not found (required by ./main_aarch64_cmake)
```

- For some reason I can't link the exe to the sysroot glibc and instead it is requires the version of the toolchain glibc (may current observation).

## Questions

- What does a toolchain contain aside from the actual compiler?
- How can I tell the target triple on a device with no gcc installed (can't `gcc -dumpmachine`).
- What is the meaning of the `-march=` flag?
  - It is a more finetuned specification. Between CPU generations and flavors, not between totally different ISA.
- Is cross compilation the same across any cmake project or does it have it's nuances per project? how does
