## Components

### Front-End

Getting from torch/TF models to intermediate `.mlir` representation.

- Should run on a docker or some other generic (probably linux x86 dev machine)
- Should handle as much as compatible versions as possible.

### Back-End - Model compiler

Converting `.mlir` to `.vmxb` model.

- Should support custom target backend.
- A lot of our tweeks will go here.

### Back-End - Runtime compiler

Compiling the Runtime that will load the `.vmxb` and execute it.

- Should also support custom target backend.
- Will also support some tweeks.

### Evaluation Environment

A way to test that the runtime and model work correctly and reasonably fast.

## Project Scope

### Reference Models

- MobileNet(s)
- YOLOX nano
- QuartzNet
- WhisperTiny
- Small Llama?

### Reference Backends

- x86 in a native setting (my linux x86)
- armv6 32bit (raspberry pi zero)
- arduino?
- GPU?

## Philosophy

### Why is it better than TFLite?

- More room for optimizations (Then we should see an improvement right?)
- Easier to implement custom ops (is it even true? when was that ever a problem?)

## Tier 0 - POC

- Everything is native (no cross-compilation at all).
- Everything is online (nothing is expected to work offline).
- Only torch frontend (no TF).

### Goals

- [ ] Convert all reference models from torch to `.mlir` In a single "click"
  - A python script for the conversion of each of them.
  - Use `pip install iree-turbine`.
- [ ] Compile the runtime and the compiler using cmake to the native architecture.  
- [ ] Compile each of the `.mlir`s to a binary using the compiler^.
- [ ] Run each of them using the runtime.
  - [ ] Profile if possible

### Wrap-up

### Questions

- Are there compatibility issues with the `.mlir` dialect between different versions of the frontend or the compiler backend?
- Gain insight about specific versions of IREE that are good candidates for us.
- How portable is the resulting `.mlir` output from the `iree-turbine`?
-
## Tier 1 - Benchmarking and TFLite comparison
- [ ] Convert each of the reference models also to tflite. Benchmark and compare results. 
- [ ] Also compare to torch.compile()
- [ ] Using tracy, get an op-wise bisection of the runtime. compare the the other tools in tflite/torch.
## Tier 2 - Cross-compilation (armv6)
- [ ] First, compile and run a hello_world C program on the emulated environment. 
- [ ] Be able to compile a runtime and a `.vmfb` to run them in the armv8 in the QEMU. 
- [ ] Gain familiarity with static/dynamic linkage issues. 