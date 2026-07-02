"""mDNS/Bonjour advertisement so the BenchTop app can find this agent on the
LAN without the user typing in an IP.

Best-effort by design: some networks (corporate Wi-Fi, some cloud/sandboxed
environments) block multicast, and `zeroconf` itself is an optional
dependency. Either failure mode degrades to "advertisement doesn't happen",
never to "the agent fails to start" — manual host:port entry in the app's
Settings always works as a fallback.
"""
from __future__ import annotations

import logging
import socket

from .config import Settings

logger = logging.getLogger("benchtop_agent.discovery")

try:
    from zeroconf import ServiceInfo, Zeroconf
except ImportError:  # zeroconf is an optional dependency
    ServiceInfo = None  # type: ignore[assignment, misc]
    Zeroconf = None  # type: ignore[assignment, misc]


def _local_ip() -> str | None:
    """Best-effort local LAN IP: open a UDP socket to a public address
    (no packets actually sent for a UDP connect) and read the address the
    OS would have used as the source.
    """
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
        sock.connect(("8.8.8.8", 80))
        return sock.getsockname()[0]
    except OSError:
        return None
    finally:
        sock.close()


class AgentAdvertiser:
    """Wraps a Zeroconf registration; safe to call start()/stop() even if
    zeroconf isn't installed or registration fails at runtime.
    """

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._zeroconf: "Zeroconf | None" = None
        self._info: "ServiceInfo | None" = None

    def start(self) -> None:
        if not self._settings.advertise:
            return
        if Zeroconf is None:
            logger.warning("zeroconf not installed; skipping LAN advertisement (manual host entry still works)")
            return

        ip = _local_ip()
        if ip is None:
            logger.warning("couldn't determine a local IP; skipping LAN advertisement")
            return

        full_name = f"{self._settings.service_name}.{self._settings.service_type}"
        try:
            self._info = ServiceInfo(
                type_=self._settings.service_type,
                name=full_name,
                addresses=[socket.inet_aton(ip)],
                port=self._settings.port,
                properties={"mode": "mock" if self._settings.mock else "live"},
            )
            self._zeroconf = Zeroconf()
            self._zeroconf.register_service(self._info)
            logger.info("advertising as %s at %s:%d", full_name, ip, self._settings.port)
        except Exception:
            logger.warning("failed to advertise on LAN; manual host entry still works", exc_info=True)
            self._zeroconf = None
            self._info = None

    def stop(self) -> None:
        if self._zeroconf is not None and self._info is not None:
            try:
                self._zeroconf.unregister_service(self._info)
            except Exception:
                pass
            self._zeroconf.close()
        self._zeroconf = None
        self._info = None
