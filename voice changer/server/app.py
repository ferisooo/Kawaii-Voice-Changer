import os
import sys
from const import ROOT_PATH
# NOTE: This is required to fix current working directory on macOS
os.chdir(ROOT_PATH)
if sys.platform == 'darwin':
    # Enable fallback to CPU since some operations may be not supported by MPS.
    os.environ['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'
# Reset CUDA_PATH since all libraries are already bundled.
# Existing CUDA installations may be incompatible with PyTorch or ONNX runtime
os.environ['CUDA_PATH'] = ''
os.environ['CUDNN_PATH'] = ''
# Fix high CPU usage caused by faiss-cpu for AMD CPUs.
# https://github.com/facebookresearch/faiss/issues/53#issuecomment-288351188
os.environ['OMP_WAIT_POLICY'] = 'PASSIVE'

import torch
# Enable NVIDIA GPU performance optimizations to reduce inference latency.
# These are no-ops on CPU/Mac (MPS) and on non-Ampere GPUs, and do not affect
# the converted voice's timbre.
if torch.cuda.is_available():
    # TF32 speeds up matmul/conv on Ampere+ GPUs (RTX 30xx/40xx, A100, ...)
    # with negligible numerical impact for inference.
    torch.backends.cuda.matmul.allow_tf32 = True
    torch.backends.cudnn.allow_tf32 = True
    # Autotune cuDNN kernels. Beneficial here because realtime audio is processed
    # in fixed-size chunks, so the autotuned kernels are reused every frame.
    torch.backends.cudnn.benchmark = True

from voice_changer.VoiceChangerManager import VoiceChangerManager
from sio.MMVC_SocketIOApp import MMVC_SocketIOApp
from restapi.MMVC_Rest import MMVC_Rest

voice_changer_manager = VoiceChangerManager()
fastapi = MMVC_Rest.get_instance(voice_changer_manager)
socketio = MMVC_SocketIOApp.get_instance(fastapi, voice_changer_manager)

# NOTE: Bundled executable overrides excepthook to pause on exception during startup.
# Here we revert to original excepthook once all initialization is done.
sys.excepthook = sys.__excepthook__
