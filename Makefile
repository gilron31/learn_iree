FP ?= 32
OPT_LEVEL ?= O3

IREE_VANILLA_BUILD_PATH = ./builds/build_compiler_and_runtime_vanilla_v3.8.0
IREE_TRACED_BUILD_PATH = ./builds/build_v3.8.0_tracy

IREE_COMPILE = $(IREE_VANILLA_BUILD_PATH)/tools/iree-compile
IREE_RUN_MODULE_TRACED = $(IREE_TRACED_BUILD_PATH)/tools/iree-run-module
IREE_BENCHMARK_MODULE_TRACED = $(IREE_TRACED_BUILD_PATH)/tools/iree-benchmark-module
IREE_DEFAULT_COMPILE_FLAGS = --iree-hal-target-device=local --iree-hal-local-target-device-backends=llvm-cpu --iree-llvmcpu-target-cpu=host
IREE_DEBUG_COMPILE_FLATS = --iree-hal-executable-debug-level=3

MOBILENETV2_INPUT_SHAPE = 1x3x224x224
QUARTZNET_INPUT_SHAPE = 1x80x128
WHISPER_TINY_INPUT_SHAPE = 1x80x3000

.PHONY: all_mlir_conversions_fp16 all_mlir_conversions_fp32 all_mlir_conversions_impl

./conversions/converted_mlirs/mobilenetv2_fp$(FP).mlir: ./conversions/mobilenetv2_convert.py
	python ./conversions/mobilenetv2_convert.py --output_mlir_path=$@ --input_shape_and_type=$(MOBILENETV2_INPUT_SHAPE)xf$(FP)

./conversions/converted_mlirs/quartznet_fp$(FP).mlir: ./conversions/quartznet_convert.py
	python ./conversions/quartznet_convert.py --output_mlir_path=$@ --input_shape_and_type=$(QUARTZNET_INPUT_SHAPE)xf$(FP)

./conversions/converted_mlirs/whisper_tiny_fp$(FP).mlir: ./conversions/whisper_tiny_convert.py
	python ./conversions/whisper_tiny_convert.py --output_mlir_path=$@ --input_shape_and_type=$(WHISPER_TINY_INPUT_SHAPE)xf$(FP)

all_mlir_conversions_impl: ./conversions/converted_mlirs/mobilenetv2_fp$(FP).mlir ./conversions/converted_mlirs/quartznet_fp$(FP).mlir ./conversions/converted_mlirs/whisper_tiny_fp$(FP).mlir

all_mlir_conversions_fp16: 
	$(MAKE) FP=16 all_mlir_conversions_impl

all_mlir_conversions_fp32: 
	$(MAKE) FP=32 all_mlir_conversions_impl

all_mlir_conversions: all_mlir_conversions_fp16 all_mlir_conversions_fp32

./conversions/compiled_vmfbs/mobilenetv2_fp$(FP)_$(OPT_LEVEL).vmfb: ./conversions/converted_mlirs/mobilenetv2_fp$(FP).mlir
	$(IREE_COMPILE) $(IREE_DEFAULT_COMPILE_FLAGS) --iree-opt-level=$(OPT_LEVEL) $(IREE_DEBUG_COMPILE_FLATS) ./conversions/converted_mlirs/mobilenetv2_fp$(FP).mlir -o $@

