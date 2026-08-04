#!/usr/bin/env bash
# Stands in for howdy's compare.py in mock mode, with ITS exit codes — a stub
# that invents its own would let the real backend's failure classes go untested
# (exit 1 is a fatal backend fault, NOT a failed match; that distinction is the
# difference between "look again" and "your camera is gone").
#   MUGLOCK_MOCK=ok    -> 0  matched
#   MUGLOCK_MOCK=fail  -> 11 no match within howdy's own scan window
#   MUGLOCK_MOCK=busy  -> 1  fatal: camera cannot be opened or read (fast)
#   MUGLOCK_MOCK=dark  -> 13 every frame was too dark
#   MUGLOCK_MOCK=capped-> 124 timeout(1) had to TERM it: our own hard cap fired
#   MUGLOCK_MOCK=slow  -> hangs past the UI cap, to exercise the last-resort path
case "${MUGLOCK_MOCK:-ok}" in
  fail)   sleep 1.5; exit 11 ;;
  busy)   sleep 0.3; exit 1 ;;
  dark)   sleep 1.2; exit 13 ;;
  capped) sleep 1.2; exit 124 ;;
  slow)   sleep 25;  exit 0 ;;
  *)      sleep 1.2; exit 0 ;;
esac
