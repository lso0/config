# Copyright © 2012 Christian Persch
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Not bash or zsh?
[ -n "${BASH_VERSION:-}" -o -n "${ZSH_VERSION:-}" ] || return 0

# Not an interactive shell?
[[ $- == *i* ]] || return 0

# Not running under vte?
[ "${VTE_VERSION:-0}" -ge 3405 ] || return 0

# TERM not supported?
case "$TERM" in
    xterm*|vte*|gnome*) :;;
    *) return 0 ;;
esac

__vte_termprop_signal() {
    local errsv="$?"
    printf '\033]666;%s!\033\\' "$1"
    return $errsv
}

__vte_termprop_set() {
    local errsv="$?"
    printf '\033]666;%s=%s\033\\' "$1" "$2"
    return $errsv
}

__vte_termprop_reset() {
    local errsv="$?"
    printf '\033]666;%s\033\\' "$1"
    return $errsv
}

__vte_osc7 () {
    local errsv="$?"
    printf "\033]7;file://%s%s\033\\" "${HOSTNAME}" "$(/usr/libexec/vte-urlencode-cwd)"
    return $errsv
}

__vte_precmd() {
    local errsv="$?"
    __vte_termprop_set "vte.shell.postexec" "$?"
    __vte_termprop_signal "vte.shell.precmd"
    return $errsv;
}

__vte_prompt_command() {
    local errsv="$?"
    __vte_termprop_set "vte.shell.postexec" "$errsv"
    __vte_osc7
    local pwd='~'
    [ "$PWD" != "$HOME" ] && pwd=${PWD/#$HOME\//\~\/}
    pwd="${pwd//[[:cntrl:]]}"
    printf "\033]0;%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${pwd}"
    __vte_termprop_signal "vte.shell.precmd"
    return $errsv
}

if [[ -n "${BASH_VERSION:-}" ]]; then

    # Newer bash versions support PROMPT_COMMAND as an array. In this case
    # only add the __vte_osc7 function to it, and leave setting the terminal
    # title to the outside setup.
    # On older bash, we can only overwrite the whole PROMPT_COMMAND, so must
    # use the __vte_prompt_command function which also sets the title.

    if [[ "$(declare -p PROMPT_COMMAND 2>&1)" =~ "declare -a" ]]; then
        PROMPT_COMMAND+=(__vte_precmd)
        PROMPT_COMMAND+=(__vte_osc7)
    else
        PROMPT_COMMAND="__vte_prompt_command"
    fi
    PS0=$(__vte_termprop_signal "vte.shell.preexec")

    # Shell integration
    if [[ "$PS1" != *\]133\;* ]]; then

        # Enclose the primary prompt between
        # ← OSC 133;D;retval ST (report exit status of previous command)
        # ← OSC 133;A ST (mark beginning of prompt)
        # → OSC 133;B ST (mark end of prompt, beginning of command line)
        PS1='\[\e]133;D;$?\e\\\e]133;A\e\\\]'"$PS1"'\[\e]133;B\e\\\]'

        # Prepend OSC 133;L ST for a conditional newline if the previous
        # command's output didn't end in one.
        # This is not done here by default, in order to provide the default
        # visual behavior of shells. Uncomment if you want this feature.
        #PS1='\[\e]133;L\e\\\]'"$PS1"

        # iTerm2 doesn't touch the secondary prompt.
        # Konsole encloses it between 133;A and 133;B.
        # For efficient jumping between commands, we follow iTerm2 by default
        # and don't mark PS2 as prompt. Uncomment if you want to mark it.
        #PS2='\[\e]133;A\e\\\]'"$PS2"'\[\e]133;B\e\\\]'

        # Mark the beginning of the command's output by OSC 133;C ST.
        # '\r' ensures that the kernel's cooked mode has the right idea of
        # the column, important for handling TAB followed by BS keypresses.
        # Prepend to the user's PS0 to preserve whether it ends in '\r'.
        # Note that bash doesn't support the \[ \] markers here.
        PS0='\e]133;C\e\\\r'"${PS0:-}"
    fi

elif [[ -n "${ZSH_VERSION:-}" ]]; then
    precmd_functions+=(__vte_osc7)
    precmd_functions+=(__vte_precmd)

    # Shell integration (see the bash counterpart for more detailed comments)
    if [[ "$PS1" != *\]133\;* ]]; then

        # Enclose the primary prompt between D;retval, A and B.
        PS1=$'%{\e]133;D;%?\e\\\e]133;A\e\\%}'"$PS1"$'%{\e]133;B\e\\%}'

        # Prepend L for conditional newline (skipped).
        #PS1=$'%{\e]133;L\e\\%}'"$PS1"

        # Secondary prompt (skipped).
        #PS2=$'%{\e]133;A\e\\%}'"$PS2"$'%{\e]133;B\e\\%}'

        # Mark the beginning of output by C.
        # The execution order is: the single function possibly hooked up
        # in $preexec, followed by all the functions hooked up in the
        # $preexec_functions array. Ensure that we are the very first.
        __vte_preexec() {
            local errsv="$?"
            printf '\e]133;C\e\\\r'
            return $errsv
        }
        preexec_functions=(__vte_preexec $preexec $preexec_functions)
        unset preexec
    fi

fi

return 0
