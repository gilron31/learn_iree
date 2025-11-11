We will test the following models:
- MobileNetV2
- WhisperTiny
- QuartzNet
All with a f32 and f16 variants. 

Possible examination points:
- [ ] `iree-benchmark-module` vs running in a loop in python. 
	- In general, try to track down possible points of overhead. 
	- What is the runtime overhead?
- [x] Beware of multithreading. use `taskset 01`
	- IREE bypasses taskset, use `--task_topology_cpu_ids=0`
- [ ] Play with compilation flags:
	- Mainly `-O3`.
- [ ] run under `perf stat -d` or `perf record`
	- [ ] My cpu doe
- [ ] run under tracy
- [ ] Compare to TFLite. 
- [ ] Compare to Torch and Torch.compile.

## MobileNetV2
Previously converted to `.mlir`.
Start with compiling to `.vmfb`:
```bash
./builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-compile --iree-hal-target-device=local --iree-hal-local-target-device-backends=llvm-cpu --iree-llvmcpu-target-cpu=host --iree-opt-level=O3 ./conversions/converted_mlirs/mobilenetv2_f32.mlir -o ./conversions/compiled_vmfbs/mobilenetv2_f32_O3.vmfb
```
Now run it:
```bash
./builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-benchmark-module --device=local-task --module=./conversions/compiled_vmfbs/mobilenetv2_f32_O3.vmfb --function=main --input="1x3x224x224xf32"
```

output:
```bash
-----------------------------------------------------------------------------------------
Benchmark                               Time             CPU   Iterations UserCounters...
-----------------------------------------------------------------------------------------
BM_main/process_time/real_time       5.35 ms         32.7 ms          128 items_per_second=186.869/s
```

It is pretty lacking, doing the math we find out that `1/5.35ms = 186.9/s`. And it seems like we did 128 iterations. But what is CPU time?

### Are we running multicore by default?
- Very much yes. 
- I ran with `--benchmark_min_time=5s` and took time to look at the `htop`. Indeed I see about 8 cores running and 10 child processes.
- When I try to run under `taskset -a -c 0` (which is supposed to constraint it to run on core 0 only) it doesn't work (exact same timing and processes). Apparently taskset is kind of like an initial recommendation for the threads that run under it. The program can change the affinity of it's child threads manually (buzzwords like `pthread_setaffinity_np()` and `sched_setaffinity()`). 
- Looking into the benchmark `--help` I spotted an option `--task_topology_cpu_ids=` which seems nice. I ran a bit of experiments:

| # cpus   | rate (1/s) | rate per core |
| -------- | ---------- | ------------- |
| 1        | 39         | 39            |
| 2        | 69         | 34            |
| 3        | 85         | 28            |
| 4        | 100        | 25            |
| 5        | 120        | 24            |
| 6        | 120        | 20            |
| 7        | 140        | 20            |
| 8        | 140        | 18            |
| 9        | 150        | 16            |
| 10       | 160        | 16            |
| 11       | 173        | 16            |
| no limit | 180        | -             |
- From now on we will strictly work with `--task_topology_cpu_ids=0`, meaning, only a single cpu core (number 0).
- Possible follow-up questions:
	- Other flags for the benchmark that are might worth to go into.
		- `--task_topology_group_count=`
		- `--task_topology_mode=` 
		- `--task_topology_performance_level=`

From now on I am running everything with ` --benchmark_min_time=5s --task_topology_cpu_ids=0`.

### More flag experimentation
- `--batch_size=1000000`
	- Scales the performace linearly, unbounded (tried 10^6) which makes me think i don't understand what is it doing. 
- `--print_statistics`
	- prints some memory usage statistics that seem too large too mean anything:
```
[[ iree_hal_allocator_t memory statistics ]]
  HOST_LOCAL:            0B peak /            0B allocated /            0B freed /            0B live
DEVICE_LOCAL:      8181760B peak /   2942479872B allocated /   2942479872B freed /            0B live
```
-  `--benchmark_{report|display}_aggregates_only={false|true}` does nothing...

### `--iree-opt-level`
I ran three experiments, compiling MobileNetV2 with O0, O1, O3 and they all had exactly the same benchmark. What is going on here?
Oh wait, the vmfbs all have the exact same size...

### Now I am RTFM-ing
https://iree.dev/developers/performance/profiling-cpu-events/


### Tracy
I remember from past experience that it was a pain to get it working but that it was quite impressive and helpful at the end. I will not go into that rabbit hole right now. 

Ok let's go

### Compiling WhisperTiny

Running 
```bash
./builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-compile --iree-hal-target-device=local --iree-hal-local-target-device-backends=llvm-cpu --iree-llvmcpu-target-cpu=host --iree-opt-level=O3 ./conversions/converted_mlirs/whisper_tiny_f32.mlir -o ./conversions/compiled_vmfbs/whisper_tiny_f32_O3.vmfb
```
I get a compilation error:

```
./conversions/converted_mlirs/whisper_tiny_f32.mlir:143:11: error: 'func.func' op exceeded stack allocation limit of 32768 bytes for function. Got 48256 bytes
    %30 = torch.aten.layer_norm %26, %27, %28, %29, %float1.000000e-05, %true : !torch.vtensor<[1,1500,384],f32>, !torch.list<int>, !torch.vtensor<[384],f32>, !torch.vtensor<[384],f32>, !torch.float, !torch.bool -> !torch.vtensor<[1,1500,384],f32>
```

seems like an easy fix given the optional flag `--iree-llvmcpu-stack-allocation-limit=65536`. 

Indeed it worked (both for f16 and f32)!
# Comparing models 
Compiled each of the three models twice, once for f32 and once for f16. 

Ran all of them with:
```bash
./builds/build_compiler_and_runtime_vanilla_v3.8.0/tools/iree-benchmark-module --device=local-task --module=./conversions/compiled_vmfbs/...vmfb --function=main --input=... --benchmark_min_time=5s --task_topology_cpu_ids=0
```

| Model       | FP type | rate (1/s) |
| ----------- | ------- | ---------- |
| MobileNetV2 | fp32    | 39         |
| MobileNetV2 | fp16    | 36 :(      |
| QuartzNet   | fp32    | 16         |
| QuartzNet   | fp16    | 10 :(      |
| WhisperTiny | fp32    | 0.22       |
| WhisperTiny | fp16    | 0.14 :(    |
So...
- All are slower with FP16, which might make sense if my CPU doesn't have good support for them. 
- WhisperTiny is slower than torch by a factor of approx 20x.
- 

# Appendix - My CPU

```
Architecture:                x86_64
  CPU op-mode(s):            32-bit, 64-bit
  Address sizes:             48 bits physical, 48 bits virtual
  Byte Order:                Little Endian
CPU(s):                      16
  On-line CPU(s) list:       0-15
Vendor ID:                   AuthenticAMD
  Model name:                AMD Ryzen 7 8845HS w/ Radeon 780M Graphics
    CPU family:              25
    Model:                   117
    Thread(s) per core:      2
    Core(s) per socket:      8
    Socket(s):               1
    Stepping:                2
    Frequency boost:         enabled
    CPU(s) scaling MHz:      52%
    CPU max MHz:             5137.0000
    CPU min MHz:             400.0000
    BogoMIPS:                7585.26
    Flags:                   fpu vme de pse tsc msr pae mce cx8 apic sep mtrr pge mca cmov pat pse36 clflush mmx fxsr sse sse2 ht syscall nx mmxext fxsr_opt pdpe1gb rdtscp lm constant_tsc rep_good amd_lbr_v2 nopl xtopology nonstop
                             _tsc cpuid extd_apicid aperfmperf rapl pni pclmulqdq monitor ssse3 fma cx16 sse4_1 sse4_2 x2apic movbe popcnt aes xsave avx f16c rdrand lahf_lm cmp_legacy svm extapic cr8_legacy abm sse4a misalignsse 3
                             dnowprefetch osvw ibs skinit wdt tce topoext perfctr_core perfctr_nb bpext perfctr_llc mwaitx cpb cat_l3 cdp_l3 hw_pstate ssbd mba perfmon_v2 ibrs ibpb stibp ibrs_enhanced vmmcall fsgsbase bmi1 avx2 sm
                             ep bmi2 erms invpcid cqm rdt_a avx512f avx512dq rdseed adx smap avx512ifma clflushopt clwb avx512cd sha_ni avx512bw avx512vl xsaveopt xsavec xgetbv1 xsaves cqm_llc cqm_occup_llc cqm_mbm_total cqm_mbm_l
                             ocal user_shstk avx512_bf16 clzero irperf xsaveerptr rdpru wbnoinvd cppc arat npt lbrv svm_lock nrip_save tsc_scale vmcb_clean flushbyasid decodeassists pausefilter pfthreshold vgif x2avic v_spec_ctrl 
                             vnmi avx512vbmi umip pku ospke avx512_vbmi2 gfni vaes vpclmulqdq avx512_vnni avx512_bitalg avx512_vpopcntdq rdpid overflow_recov succor smca fsrm flush_l1d
Virtualization features:     
  Virtualization:            AMD-V
Caches (sum of all):         
  L1d:                       256 KiB (8 instances)
  L1i:                       256 KiB (8 instances)
  L2:                        8 MiB (8 instances)
  L3:                        16 MiB (1 instance)
NUMA:                        
  NUMA node(s):              1
  NUMA node0 CPU(s):         0-15
Vulnerabilities:             
  Gather data sampling:      Not affected
  Ghostwrite:                Not affected
  Indirect target selection: Not affected
  Itlb multihit:             Not affected
  L1tf:                      Not affected
  Mds:                       Not affected
  Meltdown:                  Not affected
  Mmio stale data:           Not affected
  Reg file data sampling:    Not affected
  Retbleed:                  Not affected
  Spec rstack overflow:      Mitigation; Safe RET
  Spec store bypass:         Mitigation; Speculative Store Bypass disabled via prctl
  Spectre v1:                Mitigation; usercopy/swapgs barriers and __user pointer sanitization
  Spectre v2:                Mitigation; Enhanced / Automatic IBRS; IBPB conditional; STIBP always-on; PBRSB-eIBRS Not affected; BHI Not affected
  Srbds:                     Not affected
  Tsa:                       Vulnerable: Clear CPU buffers attempted, no microcode
  Tsx async abort:           Not affected
  Vmscape:                   Mitigation; IBPB before exit to userspace
```

### Sadly, my laptop does not have `perf`
Something with kernel versions. Probably fixable but a rabbithole indeed 
https://bugs.launchpad.net/ubuntu/+source/linux-hwe-6.14/+bug/2117147#:~:text=Bug%20Description,corresponding%20perf%20and%20bpftool%20binaries.

I also tried to install AMDuProf,
```
N: Download is performed unsandboxed as root as file '/home/gilro/Downloads/amduprof_5.1-701_amd64.deb' couldn't be accessed by user '_apt'. - pkgAcquire::Run (13: Permission denied)
```
chmod fixed it.
But the profile wasn't helpful, maybe i should try again with debug symbols. 
