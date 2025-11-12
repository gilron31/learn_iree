FP ?= 32

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
