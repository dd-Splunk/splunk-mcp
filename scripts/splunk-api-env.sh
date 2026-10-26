#!/bin/sh
# Shared Splunk REST client defaults. Source this file, then call: splunk_api_env
#
# Sets SPLUNK_HOST, SPLUNK_PORT, SPLUNK_REST_USER, SPLUNK_MCP_USER, and the curl
# timeouts SPLUNK_CURL_CONNECT_TIMEOUT / SPLUNK_CURL_MAX_TIME (seconds) when unset.
# A value already in the environment is kept.
#
# Host scripts use the localhost default (published port 127.0.0.1:8089).
# compose.yml sets SPLUNK_HOST=so1 on splunk-init only. localhost inside that
# container is Alpine, not Splunk.

splunk_api_env() {
  SPLUNK_HOST="${SPLUNK_HOST:-localhost}"
  SPLUNK_PORT="${SPLUNK_PORT:-8089}"
  SPLUNK_REST_USER="${SPLUNK_REST_USER:-admin}"
  SPLUNK_MCP_USER="${SPLUNK_MCP_USER:-splunker}"
  # A stalled splunkd must not hang init, mint, or toggle loops forever.
  SPLUNK_CURL_CONNECT_TIMEOUT="${SPLUNK_CURL_CONNECT_TIMEOUT:-10}"
  SPLUNK_CURL_MAX_TIME="${SPLUNK_CURL_MAX_TIME:-60}"
}
