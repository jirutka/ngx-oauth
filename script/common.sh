# vim: set ts=4:
# Note: scripts should change PWD to the project's directory prior to
# sourcing this file.

VENV_DIR="$(pwd)/.env"
PYENV_DIR="$VENV_DIR/python"
TEMP_DIR="$(pwd)/.tmp"

die() {
	echo -e "ERROR: $1" >&2
	exit ${2:-2}
}

exists() {
	command -v "$1" &>/dev/null
}

yesno() {
	[[ "$1" =~ ^(y|yes|Y|YES)$ ]]
}
