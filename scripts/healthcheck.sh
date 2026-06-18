#!/bin/bash

if ! curl --retry 3 -sSLx socks5h://127.0.0.1:40000 https://www.cloudflare.com/cdn-cgi/trace | grep -q "warp=on" &> /dev/null; then
  exit 1
fi