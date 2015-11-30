# vim: set ts=4:
# Note: scripts should change PWD to the project's directory prior to
# sourcing this file.

VENV_DIR="$(pwd)/.env"
TEMP_DIR="$(pwd)/.tmp"

die() {
	echo -e "ERROR: $1" >&2
	exit ${2:-2}
}

exists() {
	command -v "$1" &>/dev/null
}

is-venv-on-path() {
	[[ "$PATH" == "$VENV_DIR/bin":* ]]
}

setup-path() {
	is-venv-on-path || export PATH="$VENV_DIR/bin:$PATH"
}

warn-if-venv-not-on-path() {
	is-venv-on-path || cat <<-EOF

		! You should add ".env/bin" to your PATH. Execute "source .envrc" in your !
		! shell, or install direnv or similar tool that will do it for you.       !

	EOF
}

yesno() {
	[[ "$1" =~ ^(y|yes|Y|YES)$ ]]
}
