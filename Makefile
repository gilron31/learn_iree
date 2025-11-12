FP ?= 32
OPT_LEVEL ?= O3

IREE_VANILLA_BUILD_PATH = ./builds/build_compiler_and_runtime_vanilla_v3.8.0
IREE_TRACED_BUILD_PATH = ./builds/build_v3.8.0_tracy_12.2
TRACY_CAPTURE_EXE = ./builds/tracy_12.2_from_iree_capture/tracy-capture 

IREE_COMPILE = $(IREE_VANILLA_BUILD_PATH)/tools/iree-compile
IREE_RUN_MODULE_TRACED = $(IREE_TRACED_BUILD_PATH)/tools/iree-run-module
IREE_BENCHMARK_MODULE_TRACED = $(IREE_TRACED_BUILD_PATH)/tools/iree-benchmark-module
IREE_DEFAULT_COMPILE_FLAGS = --iree-hal-target-device=local --iree-hal-local-target-device-backends=llvm-cpu --iree-llvmcpu-target-cpu=host
IREE_DEBUG_COMPILE_FLATS = --iree-hal-executable-debug-level=3
IREE_BENCHMARK_FLAGS = --benchmark_min_time=2.0s --task_topology_cpu_ids=0
MOBILENETV2_INPUT_SHAPE = 1x3x224x224
QUARTZNET_INPUT_SHAPE = 1x80x128
WHISPER_TINY_INPUT_SHAPE = 1x80x3000

TIMESTAMP := $(shell date +%Y%m%d_%H%M%S)


ifeq ($(APP_NAME), mobilenetv2)
	INPUT_SHAPE=$(MOBILENETV2_INPUT_SHAPE)
else ifeq ($(APP_NAME), quartznet)
	INPUT_SHAPE=$(QUARTZNET_INPUT_SHAPE)
else ifeq ($(APP_NAME), whisper_tiny)
	INPUT_SHAPE=$(WHISPER_TINY_INPUT_SHAPE)
	IREE_ADDITIONAL_COMPILE_FLAGS=--iree-llvmcpu-stack-allocation-limit=65536
	IREE_BENCHMARK_FLAGS=--benchmark_min_time=20.0s --task_topology_cpu_ids=0
endif


.PHONY: convert_mlir compile_vmfb benchmark_tracy

./conversions/converted_mlirs/$(APP_NAME)_fp$(FP).mlir: ./conversions/$(APP_NAME)_convert.py
	python ./conversions/$(APP_NAME)_convert.py --output_mlir_path=$@ --input_shape_and_type=$(INPUT_SHAPE)xf$(FP)

./conversions/compiled_vmfbs/$(APP_NAME)_fp$(FP)_$(OPT_LEVEL).vmfb: ./conversions/converted_mlirs/$(APP_NAME)_fp$(FP).mlir
	$(IREE_COMPILE) $(IREE_DEFAULT_COMPILE_FLAGS) --iree-opt-level=$(OPT_LEVEL) $(IREE_ADDITIONAL_COMPILE_FLAGS) $(IREE_DEBUG_COMPILE_FLATS) ./conversions/converted_mlirs/$(APP_NAME)_fp$(FP).mlir -o $@

convert_mlir: ./conversions/converted_mlirs/$(APP_NAME)_fp$(FP).mlir

compile_vmfb: ./conversions/compiled_vmfbs/$(APP_NAME)_fp$(FP)_$(OPT_LEVEL).vmfb


BENCHMARK_CMD = $(IREE_TRACED_BUILD_PATH)/tools/iree-benchmark-module --module=./conversions/compiled_vmfbs/$(APP_NAME)_fp$(FP)_$(OPT_LEVEL).vmfb --function=main --input="$(INPUT_SHAPE)xf$(FP)" --device=local-task $(IREE_BENCHMARK_FLAGS)
benchmark: compile_vmfb
	$(BENCHMARK_CMD)

benchmark_tracy: compile_vmfb
	$(TRACY_CAPTURE_EXE) -o ./conversions/tracy_traces/capture_$(APP_NAME)_fp$(FP)_$(OPT_LEVEL)_$(TIMESTAMP).tracy &
	TRACY_NO_EXIT=1 $(BENCHMARK_CMD)


convert_mlir_all:
	$(MAKE) FP=16 APP_NAME=mobilenetv2 convert_mlir
	$(MAKE) FP=32 APP_NAME=mobilenetv2 convert_mlir
	$(MAKE) FP=16 APP_NAME=quartznet convert_mlir
	$(MAKE) FP=32 APP_NAME=quartznet convert_mlir
	$(MAKE) FP=16 APP_NAME=whisper_tiny convert_mlir
	$(MAKE) FP=32 APP_NAME=whisper_tiny convert_mlir


compile_vmfb_all:
	$(MAKE) FP=16 APP_NAME=mobilenetv2 compile_vmfb
	$(MAKE) FP=32 APP_NAME=mobilenetv2 compile_vmfb
	$(MAKE) FP=16 APP_NAME=quartznet compile_vmfb
	$(MAKE) FP=32 APP_NAME=quartznet compile_vmfb
	$(MAKE) FP=16 APP_NAME=whisper_tiny compile_vmfb
	$(MAKE) FP=32 APP_NAME=whisper_tiny compile_vmfb

benchmark_tracy_all:
	$(MAKE) FP=16 APP_NAME=mobilenetv2 benchmark_tracy
	$(MAKE) FP=32 APP_NAME=mobilenetv2 benchmark_tracy
	$(MAKE) FP=16 APP_NAME=quartznet benchmark_tracy
	$(MAKE) FP=32 APP_NAME=quartznet benchmark_tracy
	$(MAKE) FP=16 APP_NAME=whisper_tiny benchmark_tracy
	$(MAKE) FP=32 APP_NAME=whisper_tiny benchmark_tracy


