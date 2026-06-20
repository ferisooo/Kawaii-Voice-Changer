"""
Lightweight output audio effects (DSP) applied to the converted voice:
  * De-esser   - tames harsh sss/shh sibilance.
  * Compressor - evens out loudness (quiet parts louder, peaks tamed) with a
                 makeup gain and a safety limiter.

All effects are fully isolated: any error returns the audio unchanged, and
filter/envelope state is carried across chunks so there are no boundary clicks.
Amounts are 0..100 (0 = off).
"""
import logging
import math
import numpy as np

logger = logging.getLogger(__name__)


class OutputFX:
    def __init__(self):
        self._sr = None
        self._comp_a = 0.0
        self._comp_zi = None
        self._deess_a = 0.0
        self._deess_zi = None
        self._hp_b = None
        self._hp_a = None
        self._hp_zi = None

    def _setup(self, sr: int):
        from scipy.signal import butter
        self._sr = sr
        self._comp_a = math.exp(-1.0 / (sr * 0.030))   # ~30 ms envelope
        self._deess_a = math.exp(-1.0 / (sr * 0.010))  # ~10 ms envelope
        wc = min(5000.0 / (sr / 2.0), 0.99)            # highpass ~5 kHz (sibilance)
        self._hp_b, self._hp_a = butter(2, wc, btype="high")
        self._comp_zi = None
        self._deess_zi = None
        self._hp_zi = None

    def _ensure_setup(self, sr: int):
        if self._sr != sr or self._hp_b is None:
            self._setup(sr)

    def _envelope(self, absx: np.ndarray, a: float, zi):
        from scipy.signal import lfilter
        if zi is None:
            zi = np.array([absx[0] * a], dtype=np.float64)
        env, zi = lfilter([1 - a], [1.0, -a], absx, zi=zi)
        return np.maximum(env, 1e-6), zi

    def _deess(self, x: np.ndarray, amount: float) -> np.ndarray:
        from scipy.signal import lfilter, lfilter_zi
        if self._hp_zi is None:
            self._hp_zi = lfilter_zi(self._hp_b, self._hp_a) * float(x[0])
        hb, self._hp_zi = lfilter(self._hp_b, self._hp_a, x, zi=self._hp_zi)
        env, self._deess_zi = self._envelope(np.abs(hb).astype(np.float64), self._deess_a, self._deess_zi)
        thresh = 0.05
        over = np.maximum(env - thresh, 0.0) / (thresh + 1e-6)
        red = np.minimum(over * (amount / 100.0), amount / 100.0)
        return (x - hb * red.astype(np.float32)).astype(np.float32)

    def _compress(self, x: np.ndarray, amount: float) -> np.ndarray:
        env, self._comp_zi = self._envelope(np.abs(x).astype(np.float64), self._comp_a, self._comp_zi)
        env_db = 20.0 * np.log10(env)
        threshold_db = -24.0
        ratio = 3.0
        makeup_db = amount / 100.0 * 12.0
        over = np.maximum(env_db - threshold_db, 0.0)
        gain_db = -over * (1.0 - 1.0 / ratio) + makeup_db
        gain = np.power(10.0, gain_db / 20.0)
        y = (x * gain.astype(np.float32)).astype(np.float32)
        np.clip(y, -0.99, 0.99, out=y)
        return y

    def process(self, x: np.ndarray, sr: int, deess_amount: float, comp_amount: float) -> np.ndarray:
        if (deess_amount <= 0 and comp_amount <= 0) or x is None or len(x) == 0:
            return x
        try:
            self._ensure_setup(sr)
            if deess_amount > 0:
                x = self._deess(x, deess_amount)
            if comp_amount > 0:
                x = self._compress(x, comp_amount)
            return x
        except Exception as e:
            logger.error("OutputFX error, passing audio through: %s", e)
            return x
