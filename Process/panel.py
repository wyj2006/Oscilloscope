import numpy as np
from plotter import FFTPlotter, WavePlotter
from PyQt6.QtCore import QTimer
from PyQt6.QtWidgets import QMainWindow
from scope_serial import SampleData, ScopeSerial
from ui_panel import Ui_Panel


class Panel(QMainWindow, Ui_Panel):
    def __init__(self, serial: ScopeSerial):
        super().__init__()
        self.setupUi(self)
        self.serial = serial

        self.sample_frequent0.valueChanged.connect(self.sync_sample_frequent)
        self.sample_frequent1.valueChanged.connect(self.sync_sample_frequent)

        self.sample_data_buffer: list[SampleData] = []
        self.channel_sample_data: dict[int, SampleData] = {}
        self.serial.sample_callback.append(self.sample_data_buffer.append)

        self.wave_plotter = WavePlotter(serial)
        self.wave_layout.addWidget(self.wave_plotter)

        self.fft_plotter = FFTPlotter(serial)
        self.fft_layout.addWidget(self.fft_plotter)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(1)

    def refresh(self):
        for channel, frequent in self.serial.sample_frequent.items():
            getattr(self, f"sample_frequent{channel}").setValue(frequent)

        if self.sample_data_buffer:
            sample_data = self.sample_data_buffer.pop(0)
            self.channel_sample_data[sample_data.channel] = sample_data.data

        if not self.channel_sample_data:
            return

        for channel, data in self.channel_sample_data.items():
            max_value = np.max(data)
            min_value = np.min(data)
            getattr(self, f"max_value{channel}").setValue(max_value)
            getattr(self, f"min_value{channel}").setValue(min_value)
            getattr(self, f"pp_value{channel}").setValue(max_value - min_value)
            getattr(self, f"average{channel}").setValue(np.sum(data) / len(data))

            n = len(data)
            index, _ = max(enumerate(np.fft.fft(data)[1:]), key=lambda x: x[1])
            getattr(self, f"frequent{channel}").setValue(
                self.serial.sample_frequent[channel] / n * index
            )

    def sync_sample_frequent(self):
        if not self.serial.is_open:
            return
        for channel, frequent in self.serial.sample_frequent.items():
            sample_frequent = getattr(self, f"sample_frequent{channel}")
            if sample_frequent.value() == frequent:
                continue
            self.serial.sample_frequent[channel] = sample_frequent.value()
        self.serial.sync_sample_frequent()
