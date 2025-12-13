import sys

from port_selector import PortSelector
from PyQt6.QtWidgets import QApplication
from scope_serial import ScopeSerial
from panel import Panel

app = QApplication(sys.argv)

scope_serial = ScopeSerial(baudrate=115200, sample_frequent={0: 1000000, 1: 1000000})
panel = Panel(scope_serial)

port_selector = PortSelector()
port_selector.portSelected.connect(
    lambda port_name: (
        port_selector.close(),
        setattr(scope_serial, "port", port_name),
        scope_serial.open(),
        panel.show(),
    )
)
port_selector.show()

sys.exit(app.exec())
