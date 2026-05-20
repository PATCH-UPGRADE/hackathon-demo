#!/bin/sh
set -eu

: "${REPLAY_PCAP:?REPLAY_PCAP is not set}"
REPLAY_RATE="${REPLAY_RATE:-1.0}"
REPLAY_LOOP="${REPLAY_LOOP:-1}"

# tcpreplay --loop=0 means infinite; --loop=N means N passes.
# REPLAY_LOOP=1 (compose default) → infinite; REPLAY_LOOP=0 → one pass.
if [ "${REPLAY_LOOP}" = "0" ]; then
  LOOP_ARG="--loop=1"
else
  LOOP_ARG="--loop=0"
fi

exec tcpreplay --intf1=eth0 "${LOOP_ARG}" --multiplier="${REPLAY_RATE}" "${REPLAY_PCAP}"
