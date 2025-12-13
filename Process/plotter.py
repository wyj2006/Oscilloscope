import matplotlib.pyplot as plt
import numpy as np
from matplotlib.backends.backend_qtagg import FigureCanvasQTAgg as FigureCanvas
from PyQt6.QtCore import QEvent, QObject, QPoint, QTimer
from PyQt6.QtWidgets import QWidget
from scope_serial import SampleData, ScopeSerial
from ui_plotter import Ui_Plotter


class Plotter(QWidget, Ui_Plotter):
    def __init__(self, serial: ScopeSerial):
        super().__init__()
        self.setupUi(self)
        self.serial = serial
        self.last_mouse_pos = None

        self.x_scale.valueChanged.connect(self.sync_spin_to_slider)
        self.y_scale.valueChanged.connect(self.sync_spin_to_slider)
        self.x_offset.valueChanged.connect(self.sync_spin_to_slider)
        self.y_offset.valueChanged.connect(self.sync_spin_to_slider)

        self.x_scale_slider.valueChanged.connect(self.sync_slider_to_spin)
        self.y_scale_slider.valueChanged.connect(self.sync_slider_to_spin)
        self.x_offset_slider.valueChanged.connect(self.sync_slider_to_spin)
        self.y_offset_slider.valueChanged.connect(self.sync_slider_to_spin)

        self.sync_spin_to_slider()

        self.sample_data_buffer: list[SampleData] = []
        self.channel_sample_data: dict[int, SampleData] = {}
        self.serial.sample_callback.append(self.sample_data_buffer.append)

        self.figure = plt.figure()
        self.axes = self.figure.add_subplot(111)
        self.canvas = FigureCanvas(self.figure)
        self.canvas_layout.addWidget(self.canvas)
        self.canvas.installEventFilter(self)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(1)

    def refresh(self):
        if self.sample_data_buffer:
            sample_data = self.sample_data_buffer.pop(0)
            self.channel_sample_data[sample_data.channel] = sample_data.data

        if not self.channel_sample_data:
            return

        self.axes.clear()
        max_y = []
        for channel, data in self.channel_sample_data.items():
            data = self.process(data)
            self.axes.plot(data, label=str(channel))
            self.axes.set_xlim(
                self.x_offset.value(),
                self.x_offset.value() + len(data) / self.x_scale.value(),
            )
            max_y.append(max(data))
        self.axes.set_ylim(
            self.y_offset.value(),
            self.y_offset.value() + max(max_y + [0]) / self.y_scale.value(),
        )
        self.axes.legend()
        self.canvas.draw()

    def process(self, data):
        return data

    def sync_spin_to_slider(self):
        for spin, slider in (
            (self.x_scale, self.x_scale_slider),
            (self.y_scale, self.y_scale_slider),
            (self.x_offset, self.x_offset_slider),
            (self.y_offset, self.y_offset_slider),
        ):
            slider.valueChanged.disconnect(self.sync_slider_to_spin)
            slider.setValue(
                int(
                    slider.minimum()
                    + (spin.value() - spin.minimum())
                    / (spin.maximum() - spin.minimum())
                    * (slider.maximum() - slider.minimum())
                )
            )
            slider.valueChanged.connect(self.sync_slider_to_spin)

    def sync_slider_to_spin(self):
        for spin, slider in (
            (self.x_scale, self.x_scale_slider),
            (self.y_scale, self.y_scale_slider),
            (self.x_offset, self.x_offset_slider),
            (self.y_offset, self.y_offset_slider),
        ):
            spin.valueChanged.disconnect(self.sync_spin_to_slider)
            spin.setValue(
                spin.minimum()
                + (slider.value() - slider.minimum())
                / (slider.maximum() - slider.minimum())
                * (spin.maximum() - spin.minimum())
            )
            spin.valueChanged.connect(self.sync_spin_to_slider)

    def eventFilter(self, a0: QObject, a1: QEvent):
        if a0 != self.canvas:
            return super().eventFilter(a0, a1)
        match a1.type():
            case QEvent.Type.MouseButtonPress:
                self.last_mouse_pos = a1.pos()
            case QEvent.Type.MouseMove:
                if self.last_mouse_pos != None:
                    dpos: QPoint = a1.pos() - self.last_mouse_pos
                    self.x_offset.setValue(
                        self.x_offset.value() - dpos.x() / self.x_scale.value()
                    )
                    self.y_offset.setValue(
                        self.y_offset.value() + dpos.y() / self.y_scale.value() / 100
                    )
                    self.last_mouse_pos = a1.pos()
            case QEvent.Type.MouseButtonRelease:
                self.last_mouse_pos = None
            case QEvent.Type.Wheel:
                dx = a1.angleDelta().y()
                self.x_scale.setValue(self.x_scale.value() + (1 if dx >= 0 else -1))
        return super().eventFilter(a0, a1)


class WavePlotter(Plotter):
    def __init__(self, serial):
        super().__init__(serial)
        self.setObjectName("WavePlotter")
        self.setWindowTitle(self.tr("波形图"))


class FFTPlotter(Plotter):
    def __init__(self, serial):
        super().__init__(serial)
        self.setObjectName("FFTPlotter")
        self.setWindowTitle(self.tr("FFT图像"))

    def process(self, data):
        return np.fft.fft(data)[1:]
