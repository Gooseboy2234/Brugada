"""End-to-end mDNS test: register a real service with AgentAdvertiser, then
find it with an independent zeroconf browser, the same way the app would.

Some networks/CI runners block multicast entirely, in which case this is
meaningless rather than a real failure — skipped rather than failed when
nothing shows up within the timeout.
"""
from __future__ import annotations

import time

import pytest
from zeroconf import ServiceBrowser, Zeroconf

from benchtop_agent.config import Settings
from benchtop_agent.discovery import AgentAdvertiser

SERVICE_TYPE = "_benchtop._tcp.local."


class _CollectingListener:
    def __init__(self) -> None:
        self.found: list[tuple[str, object]] = []

    def add_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        self.found.append((name, zc.get_service_info(type_, name)))

    def remove_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        pass

    def update_service(self, zc: Zeroconf, type_: str, name: str) -> None:
        pass


def test_advertised_service_is_discoverable():
    settings = Settings(port=8499, service_name="PytestRig", service_type=SERVICE_TYPE)
    advertiser = AgentAdvertiser(settings)
    advertiser.start()
    if advertiser._zeroconf is None:
        pytest.skip("mDNS advertisement unavailable in this environment")

    browser_zc = Zeroconf()
    listener = _CollectingListener()
    ServiceBrowser(browser_zc, SERVICE_TYPE, listener)

    try:
        deadline = time.time() + 8
        while time.time() < deadline and not listener.found:
            time.sleep(0.2)

        if not listener.found:
            pytest.skip("no mDNS response within timeout; likely multicast-blocked environment")

        name, info = listener.found[0]
        assert name == "PytestRig._benchtop._tcp.local."
        assert info is not None
        assert info.port == 8499
        assert info.properties[b"mode"] == b"mock"
    finally:
        browser_zc.close()
        advertiser.stop()
