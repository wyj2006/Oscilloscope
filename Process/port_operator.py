import threading

from PyQt6.QtCore import QTimer
from PyQt6.QtGui import QTextCursor
from PyQt6.QtWidgets import QWidget
from scope_serial import ScopeSerial
from ui_port_operator import Ui_PortOperator


class PortOperator(QWidget, Ui_PortOperator):
    def __init__(self, serial: ScopeSerial):
        super().__init__()
        self.setupUi(self)
        self.data_buffer = []

        self.serial = serial
        self.serial.data_callback.append(self.data_buffer.append)

        self.clear_button.clicked.connect(self.read_content.clear)
        self.timer = QTimer(self)
        self.timer.timeout.connect(
            lambda: (
                self.insertData(self.data_buffer.pop(0)) if self.data_buffer else None
            )
        )
        self.timer.setInterval(1)
        self.timer.start()

        self.start_button.clicked.connect(self.timer.start)
        self.stop_button.clicked.connect(self.timer.stop)

    def insertData(self, data: int):
        cursor = self.read_content.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.End)
        cursor.insertText(f"{hex(data)[2:].upper():0>2}\t")
        if self.auto_scroll.isChecked():
            bar = self.read_content.verticalScrollBar()
            bar.setValue(bar.maximum())
