import torch
import iree.turbine.aot as aot
import argparse
from loguru import logger
import os
import sys

sys.path.append("clean_clones/Automatic-Speech-Recognition")

from asr.models.quartznet import QuartzNet

TYPE_MAPPING = {
    "f32": torch.float32,
    "f16": torch.float16,
}


def parse_input_shape_and_type(txt):
    fields = txt.split("x")
    return tuple(int(x) for x in fields[:-1]), TYPE_MAPPING[fields[-1]]


DEFAULT_APP_NAME = "quartznet"
DEFALUT_INPUT_SHAPE = "1x300x128xf32"


class Wrapper(torch.nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, x):
        return self.model(x)["logits"]


def convert_model(args):
    logger.info(f"Creating {DEFAULT_APP_NAME}")
    model = QuartzNet()

    input_shape, input_type = parse_input_shape_and_type(args.input_shape_and_type)
    sample_inputs = torch.randn(input_shape, dtype=input_type)
    logger.info(f"{input_shape=}, {input_type=}")

    model_ = Wrapper(model).cpu().eval().to(input_type)
    total_num_parameters = sum([p.numel() for p in model.parameters()])
    logger.info(f"{total_num_parameters=}")
    logger.info("Test run on inputs...")
    model_(sample_inputs)
    logger.info("Starting conversion...")
    export_output = aot.export(model_, sample_inputs)
    logger.info(f"Conversion done. Saving to {args.output_mlir_path}")
    dirpath = (
        args.output_mlir_path
        if os.path.splitext(args.output_mlir_path)[1] == ""
        else os.path.dirname(args.output_mlir_path)
    )
    os.makedirs(dirpath, exist_ok=True)
    export_output.save_mlir(args.output_mlir_path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--output_mlir_path", type=str, default=f"./{DEFAULT_APP_NAME}.mlir"
    )
    parser.add_argument("--input_shape_and_type", type=str, default=DEFALUT_INPUT_SHAPE)
    convert_model(parser.parse_args())
