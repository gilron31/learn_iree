- Cloned iree <https://github.com/iree-org/iree>
- Cloned iree-turbine <https://github.com/iree-org/iree-turbine>
- Checked out v3.8.0 in both (form 15.10.2025 - this is pretty new)
- Setting up the build was really as easy as:

```
git clone 
git submodule update --init --recursive
cmake -G Ninja -S ../../clean_clones/iree -B . 
```

- Building the runtime was pretty fast (~15s) `cmake --build . -j8 -t iree-runtime`
- Building the compiler is harder, will probably take around 1h.  `cmake --build . -j8 -t iree-compile`
- `python3 -m venv venv_online_everything`
- `pip install iree-base-compiler==3.8.0`
- `pip install iree-base-runtime==3.8.0`

## Issues and follow-up questions

- Why does whisper tiny not compiling to MLIR?\
  - Probably because there is a procedural logic there and varying size output. We can try to call only the inside function that does most of the work.
- MobilenetV2 worked fine.
- NothingModel (a single FC) worked fine.
- calling `model.eval().cpu()` is important.
- Yolox is kinda broken and hard to install. A real pain.
  - Turns out that moving from python 3.12 to 3.10 can make it work.
  - In the 3.10 env (`venv_yolox`) I installed`iree-turbine==3.8.0`,`iree-base-compiler==3.8.0`, `iree-base-runtime==3.8.0` and `torch==2.5.1+cpu`.

<details><summary>Yolox patch for deplyment</summary>

```

diff --git a/yolox/models/yolo_head.py b/yolox/models/yolo_head.py
index 3e51768..868b92a 100644
--- a/yolox/models/yolo_head.py
+++ b/yolox/models/yolo_head.py
@@ -202,12 +202,12 @@ class YOLOXHead(nn.Module):
                 dtype=xin[0].dtype,
             )
         else:

-            self.hw = [x.shape[-2:] for x in outputs]
             # [batch, n_anchors_all, 85]
             outputs = torch.cat(
                 [x.flatten(start_dim=2) for x in outputs], dim=2
             ).permute(0, 2, 1)
             if self.decode_in_inference:

+                self.hw = [x.shape[-2:] for x in outputs]
                 return self.decode_outputs(outputs, dtype=xin[0].type())
             else:
                 return outputs

```

</details>

- Yolox eventually worked (see patch).
- QuartzNet worked fine.
-

## Compiling the MLIRs

- First I ran

```
../builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-compile --iree-hal-target-device=local --iree-hal-local-target-device-backends=llvm-cpu --iree-llvmcpu-target-cpu=host --iree-opt-level=O2 converted_mobilenetv2_default_config.mlir -o mobilenetv2_default_config_cpu.vmfb
```

Which worked fine. Tested with:

```
../builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-run-module --device=local-task --module=mobilenetv2_default_config_cpu.vmfb  --function=main --input="1x3x224x224xf32=0"
```

Which had some output.

- I then looked into it in Ghidra:
- It had all kinda strings:

```
.comment::00000000 IREE u8"IREE" utf8
.debug_str::00000000 main$async_dispatch_26_conv_14x14x192x3x3_f32 "main$async_dispatch_26_conv_14x14x192x3x3_f32" ds
.shstrtab::00000001 .dynsym u8".dynsym" utf8
.shstrtab::00000009 .hash u8".hash" utf8
.shstrtab::0000000f .dynstr u8".dynstr" utf8
.shstrtab::00000017 .rela.dyn u8".rela.dyn" utf8
.shstrtab::00000021 .rodata u8".rodata" utf8
.shstrtab::00000029 .eh_frame u8".eh_frame" utf8
.shstrtab::00000033 .text u8".text" utf8
.shstrtab::00000039 .data.rel.ro u8".data.rel.ro" utf8
.shstrtab::00000046 .dynamic u8".dynamic" utf8
.shstrtab::0000004f .relro_padding u8".relro_padding" utf8
.shstrtab::0000005e .debug_abbrev u8".debug_abbrev" utf8
.shstrtab::0000006c .debug_info u8".debug_info" utf8
.shstrtab::00000078 .debug_str u8".debug_str" utf8
.shstrtab::00000083 .debug_pubnames u8".debug_pubnames" utf8
.shstrtab::00000093 .debug_pubtypes u8".debug_pubtypes" utf8
.shstrtab::000000a3 .debug_line u8".debug_line" utf8
.shstrtab::000000af .comment u8".comment" utf8
.shstrtab::000000b8 .symtab u8".symtab" utf8
.shstrtab::000000c0 .shstrtab u8".shstrtab" utf8
.shstrtab::000000ca .strtab u8".strtab" utf8
.strtab::00000001 iree_hal_executable_library_query u8"iree_hal_executable_library_query" utf8
.strtab::00000023 _DYNAMIC u8"_DYNAMIC" utf8
00100001 ELF "ELF" ds
00100211 iree_hal_executable_library_query u8"iree_hal_executable_library_query" utf8
0011a43f <module_linked "<module_linked" ds
0011b010 main$async_dispatch_0_slow_memcpy "main$async_dispatch_0_slow_memcpy" ds
0011b032 main$async_dispatch_1_conv_32x112x112x3x3x3_f32 "main$async_dispatch_1_conv_32x112x112x3x3x3_f32" ds
0011b062 main$async_dispatch_2_conv_112x112x32x3x3_f32 "main$async_dispatch_2_conv_112x112x32x3x3_f32" ds
0011b090 main$async_dispatch_3_elementwise_32x12544_f32 "main$async_dispatch_3_elementwise_32x12544_f32" ds
0011b0bf main$async_dispatch_4_matmul_like_16x12544x32_f32 "main$async_dispatch_4_matmul_like_16x12544x32_f32" ds
0011b0f1 main$async_dispatch_5_matmul_like_96x112x112x16_f32 "main$async_dispatch_5_matmul_like_96x112x112x16_f32" ds
0011b125 main$async_dispatch_6_conv_56x56x96x3x3_f32 "main$async_dispatch_6_conv_56x56x96x3x3_f32" ds
0011b151 main$async_dispatch_7_elementwise_96x3136_f32 "main$async_dispatch_7_elementwise_96x3136_f32" ds
0011b17f main$async_dispatch_8_matmul_like_24x3136x96_f32 "main$async_dispatch_8_matmul_like_24x3136x96_f32" ds
0011b1b0 main$async_dispatch_9_matmul_like_144x56x56x24_f32 "main$async_dispatch_9_matmul_like_144x56x56x24_f32" ds
0011b1e3 main$async_dispatch_10_conv_56x56x144x3x3_f32 "main$async_dispatch_10_conv_56x56x144x3x3_f32" ds
0011b211 main$async_dispatch_11_elementwise_144x3136_f32 "main$async_dispatch_11_elementwise_144x3136_f32" ds
0011b241 main$async_dispatch_12_matmul_like_24x3136x144_f32 "main$async_dispatch_12_matmul_like_24x3136x144_f32" ds
0011b274 main$async_dispatch_13_matmul_like_144x56x56x24_f32 "main$async_dispatch_13_matmul_like_144x56x56x24_f32" ds
0011b2a8 main$async_dispatch_14_conv_28x28x144x3x3_f32 "main$async_dispatch_14_conv_28x28x144x3x3_f32" ds
0011b2d6 main$async_dispatch_15_elementwise_144x784_f32 "main$async_dispatch_15_elementwise_144x784_f32" ds
0011b305 main$async_dispatch_16_matmul_like_32x784x144_f32 "main$async_dispatch_16_matmul_like_32x784x144_f32" ds
0011b337 main$async_dispatch_17_matmul_like_192x28x28x32_f32 "main$async_dispatch_17_matmul_like_192x28x28x32_f32" ds
0011b36b main$async_dispatch_18_conv_28x28x192x3x3_f32 "main$async_dispatch_18_conv_28x28x192x3x3_f32" ds
0011b399 main$async_dispatch_19_elementwise_192x784_f32 "main$async_dispatch_19_elementwise_192x784_f32" ds
0011b3c8 main$async_dispatch_20_matmul_like_32x784x192_f32 "main$async_dispatch_20_matmul_like_32x784x192_f32" ds
0011b3fa main$async_dispatch_24_matmul_like_32x784x192_f32 "main$async_dispatch_24_matmul_like_32x784x192_f32" ds
0011b42c main$async_dispatch_25_matmul_like_192x28x28x32_f32 "main$async_dispatch_25_matmul_like_192x28x28x32_f32" ds
0011b460 main$async_dispatch_26_conv_14x14x192x3x3_f32 "main$async_dispatch_26_conv_14x14x192x3x3_f32" ds
0011b48e main$async_dispatch_27_elementwise_192x196_f32 "main$async_dispatch_27_elementwise_192x196_f32" ds
0011b4bd main$async_dispatch_28_matmul_like_64x196x192_f32 "main$async_dispatch_28_matmul_like_64x196x192_f32" ds
0011b4ef main$async_dispatch_29_matmul_like_384x14x14x64_f32 "main$async_dispatch_29_matmul_like_384x14x14x64_f32" ds
0011b523 main$async_dispatch_30_conv_14x14x384x3x3_f32 "main$async_dispatch_30_conv_14x14x384x3x3_f32" ds
0011b551 main$async_dispatch_31_elementwise_384x196_f32 "main$async_dispatch_31_elementwise_384x196_f32" ds
0011b580 main$async_dispatch_32_matmul_like_64x196x384_f32 "main$async_dispatch_32_matmul_like_64x196x384_f32" ds
0011b5b2 main$async_dispatch_36_matmul_like_64x196x384_f32 "main$async_dispatch_36_matmul_like_64x196x384_f32" ds
0011b5e4 main$async_dispatch_40_matmul_like_64x196x384_f32 "main$async_dispatch_40_matmul_like_64x196x384_f32" ds
0011b616 main$async_dispatch_44_matmul_like_96x196x384_f32 "main$async_dispatch_44_matmul_like_96x196x384_f32" ds
0011b648 main$async_dispatch_45_matmul_like_576x14x14x96_f32 "main$async_dispatch_45_matmul_like_576x14x14x96_f32" ds
0011b67c main$async_dispatch_46_conv_14x14x576x3x3_f32 "main$async_dispatch_46_conv_14x14x576x3x3_f32" ds
0011b6aa main$async_dispatch_47_elementwise_576x196_f32 "main$async_dispatch_47_elementwise_576x196_f32" ds
0011b6d9 main$async_dispatch_48_matmul_like_96x196x576_f32 "main$async_dispatch_48_matmul_like_96x196x576_f32" ds
0011b70b main$async_dispatch_53_matmul_like_576x14x14x96_f32 "main$async_dispatch_53_matmul_like_576x14x14x96_f32" ds
0011b73f main$async_dispatch_54_conv_7x7x576x3x3_f32 "main$async_dispatch_54_conv_7x7x576x3x3_f32" ds
0011b76b main$async_dispatch_55_elementwise_576x49_f32 "main$async_dispatch_55_elementwise_576x49_f32" ds
0011b799 main$async_dispatch_56_matmul_like_160x49x576_f32 "main$async_dispatch_56_matmul_like_160x49x576_f32" ds
0011b7cb main$async_dispatch_57_matmul_like_960x7x7x160_f32 "main$async_dispatch_57_matmul_like_960x7x7x160_f32" ds
0011b7fe main$async_dispatch_58_conv_7x7x960x3x3_f32 "main$async_dispatch_58_conv_7x7x960x3x3_f32" ds
0011b82a main$async_dispatch_59_elementwise_960x49_f32 "main$async_dispatch_59_elementwise_960x49_f32" ds
0011b858 main$async_dispatch_60_matmul_like_160x49x960_f32 "main$async_dispatch_60_matmul_like_160x49x960_f32" ds
0011b88a main$async_dispatch_68_matmul_like_320x49x960_f32 "main$async_dispatch_68_matmul_like_320x49x960_f32" ds
0011b8bc main$async_dispatch_69_matmul_like_1280x49x320_f32 "main$async_dispatch_69_matmul_like_1280x49x320_f32" ds
0011b8ef converted_mobilenetv2_default_config.mlir "converted_mobilenetv2_default_config.mlir" ds
0011b929 zR "zR" ds
```

Which we should figure out how to get rid off.

I then compiled QuartzNet (took 5s)

```
../builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-compile --iree-hal-target-device=local --iree-hal-local-target-device-backends=llvm-cpu --iree-llvmcpu-target-cpu=host --iree-opt-level=O2 converted_quartznet.mlir -o quartznet_cpu.vmfb
```

```
../builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-run-module --device=local-task --module=quartznet_cpu.vmfb  --function=main --input="1x300x128xf32=0"
```

Also worked fine.

## Benchmarking

Building the benchmark exe

```
cmake --build . -j10 -t iree-benchmark-module
```

### QuartzNet

```
../builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-benchmark-module --device=local-task --module=quartznet_cpu.vmfb  --function=main --input="1x300x128xf32=0"
```

```
-----------------------------------------------------------------------------------------
Benchmark                               Time             CPU   Iterations UserCounters...
-----------------------------------------------------------------------------------------
BM_main/process_time/real_time       13.5 ms         83.1 ms           44 items_per_second=73.8066/s
```

### YoloX
