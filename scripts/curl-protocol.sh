#!/usr/bin/env sh
set -eu

curl_json() {
  title="$1"
  url="$2"
  shift 2

  printf '\n### %s\n' "$title"
  printf '$ curl -s'
  for arg in "$@"; do
    case "$arg" in
      *[!\ A-Za-z0-9_./:=@%-]*)
        escaped=$(printf '%s' "$arg" | sed "s/'/'\\\\''/g")
        printf " '%s'" "$escaped"
        ;;
      *)
        printf ' %s' "$arg"
        ;;
    esac
  done
  printf ' %s\n' "$url"
  curl -s "$@" "$url"
  printf '\n'
}

curl_json "nginx1 -> app" "http://localhost:8081/app"
curl_json "nginx2 -> app" "http://localhost:8082/app"
curl_json "nginx3 -> app" "http://localhost:8083/app"
curl_json "nginx1 -> nginx2 -> nginx3 -> app" "http://localhost:8081/via/nginx2/via/nginx3/app"
curl_json "nginx2 -> nginx3 -> app" "http://localhost:8082/via/nginx3/app"
curl_json "spoofed X-Forwarded-For is discarded" "http://localhost:8081/via/nginx2/via/nginx3/app" -H "X-Forwarded-For: 1.2.3.4, 5.6.7.8"
