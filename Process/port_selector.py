from PyQt6.QtCore import pyqtSignal, pyqtSlot
from PyQt6.QtWidgets import QTableWidgetItem, QWidget
from serial.tools.list_ports import comports
from ui_port_selector import Ui_PortSelector


class PortSelector(QWidget, Ui_PortSelector):
    portSelected = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.setupUi(self)

        self.ok_button.setEnabled(False)
        self.refresh_button.clicked.connect(self.refresh)

        self.refresh()

    def refresh(self):
        for i, port in enumerate(comports()):
            self.port_list.setRowCount(i + 1)
            self.port_list.setItem(i, 0, QTableWidgetItem(port.name))
            self.port_list.setItem(i, 1, QTableWidgetItem(port.description))
            self.port_list.setItem(i, 1, QTableWidgetItem(port.description))

    @pyqtSlot(bool)
    def on_ok_button_clicked(self, _):
        row = self.port_list.currentRow()
        name = self.port_list.itemAt(row, 0).text()
        self.portSelected.emit(name)

    @pyqtSlot(QTableWidgetItem, QTableWidgetItem)
    def on_port_list_currentItemChanged(self, current, _):
        self.ok_button.setEnabled(current != None)
