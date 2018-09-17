# vim: set ts=4:
# Note: scripts should change PWD to the project's directory prior to
# sourcing this file.

VENV_DIR="$(pwd)/.env"
TEMP_DIR="$(pwd)/.tmp"

# Set pipefail if supported.
if ( set -o pipefail 2>/dev/null ); then
	set -o pipefail
fi

die() {
	printf 'ERROR: %s\n' "$1" >&2
	exit ${2:-2}
}

einfo() {
	printf '\n%s\n' "$@"
}

exists() {
	command -v "$1" >/dev/null 2>&1
}

is_venv_on_path() {
	case "$PATH" in
		"$VENV_DIR/bin":*) return 0;;
		*) return 1;;
	esac
}

setup_path() {
	is_venv_on_path || export PATH="$VENV_DIR/bin:$PATH"
}

warn_if_venv_not_on_path() {
	is_venv_on_path || cat <<-EOF

		! You should add ".env/bin" to your PATH. Execute ". ./.envrc" in your !
		! shell, or install direnv or similar tool that will do it for you.    !

	EOF
}

yesno() {
	case "$1" in
		y | yes | Y | YES) return 0;;
		*) return 1;;
	esac
}
