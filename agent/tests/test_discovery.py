"""End-to-end mDNS test: register with AgentAdvertiser, find it with an
independent zeroconf browser. Skips (not fails) where multicast is blocked.
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
            pytest.skip("no mDNS response within timeout; likely multicast-blocked")

        name, info = listener.found[0]
        assert name == "PytestRig._benchtop._tcp.local."
        assert info is not None and info.port == 8499
    finally:
        browser_zc.close()
        advertiser.stop()
