#!/bin/bash

set -e

INSTALL_DIR="/usr/local/bin"
RELEASE="latest"

# Parse Flags
parse_args() {
  while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -r | --release)
      RELEASE="$2"
      shift # past release argument
      shift # past release value
      ;;
    *)
      echo "Unrecognized argument $key"
      exit 1
      ;;
    esac
  done
}

set_filename() {
  local OS

  OS=$(uname -s)

  if [ "$OS" == "Linux" ]; then
    FILENAME="query-json-linux-x64"
  elif [ "$OS" == "Darwin" ]; then
    FILENAME="query-json-darwin-x64"
  else
    echo "OS $OS is not supported."
    echo "If you think that's a bug - please file an issue to https://github.com/davesnx/query-json/issues"
    exit 1
  fi
}

download() {
  if [ "$RELEASE" == "latest" ]; then
    URL=https://github.com/davesnx/query-json/releases/latest/download/$FILENAME.zip
  else
    URL=https://github.com/davesnx/query-json/releases/download/$RELEASE/$FILENAME.zip
  fi

  DOWNLOAD_DIR=$(mktemp -d)

  echo "Downloading $URL..."

  mkdir -p "$INSTALL_DIR" &>/dev/null
  curl --progress-bar -L "$URL" -o "$DOWNLOAD_DIR/$FILENAME.zip"

  if [ 0 -ne "$?" ]; then
    echo "Download failed. Check that the release/filename are correct."
    exit 1
  fi

  unzip -q "$DOWNLOAD_DIR/$FILENAME.zip" -d "$DOWNLOAD_DIR"
  mv "$DOWNLOAD_DIR/query-json" "$INSTALL_DIR/query-json"
  chmod u+x "$INSTALL_DIR/query-json"
}

check_dependencies() {
  echo "Checking dependencies for the installation script..."

  echo -n "Checking availability of curl... "
  if hash curl 2>/dev/null; then
    echo "OK!"
  else
    echo "Missing!"
    SHOULD_EXIT="true"
  fi

  echo -n "Checking availability of unzip... "
  if hash unzip 2>/dev/null; then
    echo "OK!"
  else
    echo "Missing!"
    SHOULD_EXIT="true"
  fi

  if [ "$SHOULD_EXIT" = "true" ]; then
    exit 1
  fi
}

parse_args "$@"
set_filename
check_dependencies
download
