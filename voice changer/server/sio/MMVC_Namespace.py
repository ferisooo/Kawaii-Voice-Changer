import numpy as np
import socketio
from time import time
from voice_changer.VoiceChangerManager import VoiceChangerManager

import asyncio

import logging
logger = logging.getLogger(__name__)

class MMVC_Namespace(socketio.AsyncNamespace):
    sid: str | None = None

    async def emitTo(self, vol, perf, err):
        if err is not None:
            error_code, error_message = err
            await self.emit("error", [error_code, error_message], to=self.sid)
        else:
            await self.emit("server_stats", [vol, perf], to=self.sid)

    def emit_coroutine(self, vol, perf, err):
        # Called from the PortAudio callback thread (server audio mode).
        # Schedule the emit on the server's event loop instead of spinning up
        # a new loop per chunk: AsyncServer internals are not thread-safe and
        # network I/O has no place inside a realtime audio callback.
        if self.sid is None or self.loop is None:
            return
        try:
            asyncio.run_coroutine_threadsafe(self.emitTo(vol, perf, err), self.loop)
        except RuntimeError:
            # Loop already closed (server shutting down) - drop the stats.
            pass

    def __init__(self, namespace: str, voiceChangerManager: VoiceChangerManager):
        super().__init__(namespace)
        self.voiceChangerManager = voiceChangerManager
        self.loop: asyncio.AbstractEventLoop | None = None
        # self.voiceChangerManager.voiceChanger.emitTo = self.emit_coroutine
        self.voiceChangerManager.setEmitTo(self.emit_coroutine)

    @classmethod
    def get_instance(cls, voiceChangerManager: VoiceChangerManager):
        if not hasattr(cls, "_instance"):
            cls._instance = cls("/test", voiceChangerManager)
        return cls._instance

    def on_connect(self, sid, environ, ext):
        self.sid = sid
        self.loop = asyncio.get_running_loop()
        logger.info(f"Connected SID: {sid}")

    async def on_request_message(self, sid, msg):
        recv_timestamp = round(time() * 1000)

        ts, data = msg
        # Receive and send int16 instead of float32 to reduce bandwidth requirement over websocket
        input_audio = np.frombuffer(data, dtype=np.int16).astype(np.float32) / 32768

        out_audio, vol, perf, err = await self.voiceChangerManager.change_voice_async(input_audio)
        if err is not None:
            error_code, error_message = err
            await self.emit("error", [error_code, error_message], to=sid)
        else:
            ping = recv_timestamp - ts
            out_audio = (out_audio * 32767).astype(np.int16).tobytes()
            send_timestamp = round(time() * 1000)
            await self.emit("response", [send_timestamp, out_audio, ping, vol, perf], to=sid)

    def on_disconnect(self, sid):
        # Only forget the client that actually left; a second client
        # disconnecting must not silence stats for the remaining one.
        if self.sid == sid:
            self.sid = None
        logger.info(f"Disconnected SID: {sid}")
