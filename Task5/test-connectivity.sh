#!/bin/sh
check() {
  desc="$1"
  url="$2"
  want="$3"
  printf "%s: " "$desc"
  if wget -qO- --timeout=2 "$url" >/dev/null 2>&1; then
    got="OK"
  else
    got="FAIL"
  fi
  if [ "$got" = "$want" ]; then
    echo "PASS ($got)"
  else
    echo "UNEXPECTED ($got, wanted $want)"
  fi
}

echo "----- ----- Testing from role=$ROLE ----- -----"
if [ "$ROLE" = "front-end" ]; then
  check "front-end -> back-end-api"     "http://back-end-api-app"         "OK"
  check "front-end -> admin-back-end"   "http://admin-back-end-api-app"   "FAIL"
  check "front-end -> admin-front-end"  "http://admin-front-end-app"      "FAIL"
elif [ "$ROLE" = "admin-front-end" ]; then
  check "admin-front-end -> admin-back-end-api" "http://admin-back-end-api-app" "OK"
  check "admin-front-end -> back-end-api"       "http://back-end-api-app"       "FAIL"
  check "admin-front-end -> front-end"          "http://front-end-app"          "FAIL"
fi
echo "••••• ••••• DONE ••••• ••••• "