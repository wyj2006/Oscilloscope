import struct
import threading
from dataclasses import dataclass
from typing import Callable

import serial

ESACPE_CHAR = ord("\\")


@dataclass
class Start:
    pass


@dataclass
class SampleData:
    channel: int
    data: list[int]
    high_bits: int  # 当前数据的高位
    escape: bool  # 是否转义当前字符


@dataclass
class BeginConfirming:
    sample_data: SampleData


@dataclass
class EndConfirming:
    sample_data: SampleData


class ScopeSerial(serial.Serial):
    def __init__(self, sample_frequent=None, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.state = Start()
        self.data_callback: list[Callable[[int], None]] = []
        self.sample_callback: list[Callable[[SampleData], None]] = []
        self.sample_frequent = sample_frequent or dict()

    def sync_sample_frequent(self):
        for channel, frequent in self.sample_frequent.items():
            # stm32为小端
            self.write(struct.pack("<I", (frequent & 0xFFFFFFF) | (channel << 28)))
            self.flush()

    def open(self):
        super().open()
        threading.Thread(target=self.reading, daemon=True).start()
        self.sync_sample_frequent()

    def reading(self):
        while True:
            if not self.is_open:
                continue
            for byte in self.read_all():
                match self.state:
                    case Start():
                        if byte in (0, 1):
                            self.state = BeginConfirming(
                                SampleData(byte, [], -1, False)
                            )
                    case BeginConfirming(sample_data):
                        if byte == sample_data.channel:
                            self.state = sample_data
                        else:
                            self.state = Start()
                    case EndConfirming(sample_data):
                        if byte == 0xFF:
                            sample_data.data = list(
                                map(lambda x: x * 3.3 / 65535, sample_data.data)
                            )
                            for callback in self.sample_callback:
                                callback(sample_data)
                            self.state = Start()
                        else:
                            if sample_data.high_bits == -1:
                                sample_data.data.append(
                                    sample_data.channel * 0xFF + byte
                                )
                            else:
                                sample_data.data.append(
                                    sample_data.high_bits * 0xFF + channel
                                )
                                sample_data.high_bits = byte
                            self.state = sample_data
                    case SampleData(channel, data, high_bits, escape):
                        if byte == ESACPE_CHAR:
                            self.state.escape = True
                        elif not escape and byte == channel:
                            self.state = EndConfirming(self.state)
                        elif high_bits == -1:
                            self.state.high_bits = byte
                            self.state.escape = False
                        else:
                            data.append(high_bits * 0xFF + byte)
                            self.state.high_bits = -1
                            self.state.escape = False
                for callback in self.data_callback:
                    callback(byte)
