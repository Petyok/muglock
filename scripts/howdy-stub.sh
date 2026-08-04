#!/usr/bin/env bash
# Stands in for `howdy compare` in mock mode. Exit 0 = matched.
# MUGLOCK_MOCK: ok (default) = match, fail = no match, slow = exceeds the 10 s scan timeout.
case "${MUGLOCK_MOCK:-ok}" in
  fail) sleep 1.5; exit 1 ;;
  slow) sleep 15;  exit 0 ;;
  *)    sleep 1.2; exit 0 ;;
esac
