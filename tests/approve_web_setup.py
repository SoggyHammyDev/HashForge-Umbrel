#!/usr/bin/env python3
"""Submit the real static SSR form with its issued antiforgery cookie and fields."""
import http.cookiejar
from html.parser import HTMLParser
import sys
from urllib.parse import urlencode, urljoin
from urllib.request import build_opener, HTTPCookieProcessor, Request

class SetupParser(HTMLParser):
    def __init__(self):
        super().__init__()
        self.inside = False
        self.fields = {}
        self.action = ""
        self.token = None
        self.confirmed = None
        self.mode = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "form":
            self.inside = True
            self.action = attrs.get("action", "")
        if tag == "select" and self.inside:
            self.mode = attrs.get("name")
        if tag == "input" and self.inside and "name" in attrs:
            name = attrs["name"]
            kind = attrs.get("type", "")
            if kind == "hidden":
                self.fields[name] = attrs.get("value", "")
            elif kind == "password":
                self.token = name
            elif kind == "checkbox":
                self.confirmed = name
                self.confirmed_value = attrs.get("value", "on")

    def handle_endtag(self, tag):
        if tag == "form":
            self.inside = False

def submit(opener, url, token, mode=None):
    with opener.open(url, timeout=20) as response:
        page = response.read().decode()
    parser = SetupParser()
    parser.feed(page)
    assert parser.token and parser.confirmed, "Setup form not rendered"
    assert any("RequestVerificationToken" in key for key in parser.fields), "Missing antiforgery field"
    fields = dict(parser.fields)
    fields[parser.token] = token
    fields[parser.confirmed] = parser.confirmed_value
    if mode is not None:
        assert parser.mode, "Setup mode selector not rendered"
        fields[parser.mode] = mode
    request = Request(urljoin(url, parser.action), data=urlencode(fields).encode(), headers={"Content-Type": "application/x-www-form-urlencoded"})
    with opener.open(request, timeout=20) as response:
        return response.read().decode()

if __name__ == "__main__":
    url, token = sys.argv[1:3]
    mode = sys.argv[3] if len(sys.argv) > 3 else None
    opener = build_opener(HTTPCookieProcessor(http.cookiejar.CookieJar()))
    assert "authorization or confirmation failed" in submit(opener, url, "incorrect-code", mode)
    result = submit(opener, url, token, mode)
    assert "setup decision already exists" in result or "Fresh synchronization approved" in result or "Setup request submitted" in result
    print("Invalid authorization rejected; valid approval accepted")
