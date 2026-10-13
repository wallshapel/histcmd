_histcmd_find_workspace() {
    emulate -L zsh

    local directory="${PWD:A}"

    while true; do
        if [[ -f "$directory/histmap.toml" ]]; then
            print -r -- "$directory"
            return 0
        fi

        [[ "$directory" == "/" ]] && break
        directory="${directory:h}"
    done

    return 1
}

_histcmd_resolve_context() {
    emulate -L zsh

    local workspace
    workspace="$(_histcmd_find_workspace)" || return 1

    local histmap="$workspace/histmap.toml"
    local current_directory="${PWD:A}"

    local header_re='^[[:space:]]*\[\[context\]\][[:space:]]*$'
    local path_re='^[[:space:]]*path[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'
    local recursive_re='^[[:space:]]*recursive[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$'
    local include_parent_re='^[[:space:]]*include-parent[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$'

    local -a paths
    local -a recursive_flags
    local -a include_parent_flags

    local context_path=""
    local context_recursive="false"
    local context_include_parent="false"
    local line

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ "$header_re" ]]; then
            if [[ -n "$context_path" ]]; then
                paths+=("$context_path")
                recursive_flags+=("$context_recursive")
                include_parent_flags+=("$context_include_parent")
            fi

            context_path=""
            context_recursive="false"
            context_include_parent="false"

        elif [[ "$line" =~ "$path_re" ]]; then
            context_path="$match[1]"

        elif [[ "$line" =~ "$recursive_re" ]]; then
            context_recursive="$match[1]"

        elif [[ "$line" =~ "$include_parent_re" ]]; then
            context_include_parent="$match[1]"
        fi
    done < "$histmap"

    if [[ -n "$context_path" ]]; then
        paths+=("$context_path")
        recursive_flags+=("$context_recursive")
        include_parent_flags+=("$context_include_parent")
    fi

    local best_context=""
    local best_length=-1
    local candidate
    local i

    for (( i = 1; i <= ${#paths[@]}; i++ )); do
        candidate="${workspace}/${paths[$i]}"
        candidate="${candidate:A}"

        if [[ "$candidate" != "$workspace" && "$candidate" != "$workspace"/* ]]; then
            continue
        fi

        if [[ "$current_directory" == "$candidate" ]]; then
            if (( ${#candidate} > best_length )); then
                best_context="$candidate"
                best_length=${#candidate}
            fi

        elif [[ "${recursive_flags[$i]}" == "true" && "$current_directory" == "$candidate"/* ]]; then
            if (( ${#candidate} > best_length )); then
                best_context="$candidate"
                best_length=${#candidate}
            fi
        fi
    done

    [[ -n "$best_context" ]] || return 1

    print -r -- "$best_context"
}

_histcmd_context_includes_parent() {
    emulate -L zsh

    local context="$1"
    local workspace
    workspace="$(_histcmd_find_workspace)" || return 1

    local histmap="$workspace/histmap.toml"

    local header_re='^[[:space:]]*\[\[context\]\][[:space:]]*$'
    local path_re='^[[:space:]]*path[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'
    local include_parent_re='^[[:space:]]*include-parent[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$'

    local context_path=""
    local context_include_parent="false"
    local line
    local candidate

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ "$header_re" ]]; then
            if [[ -n "$context_path" ]]; then
                candidate="${workspace}/${context_path}"
                candidate="${candidate:A}"

                if [[ "$candidate" == "$context" ]]; then
                    [[ "$context_include_parent" == "true" ]]
                    return
                fi
            fi

            context_path=""
            context_include_parent="false"

        elif [[ "$line" =~ "$path_re" ]]; then
            context_path="$match[1]"

        elif [[ "$line" =~ "$include_parent_re" ]]; then
            context_include_parent="$match[1]"
        fi
    done < "$histmap"

    if [[ -n "$context_path" ]]; then
        candidate="${workspace}/${context_path}"
        candidate="${candidate:A}"

        if [[ "$candidate" == "$context" ]]; then
            [[ "$context_include_parent" == "true" ]]
            return
        fi
    fi

    return 1
}

_histcmd_find_parent_context() {
    emulate -L zsh

    local context="$1"
    local workspace
    workspace="$(_histcmd_find_workspace)" || return 1

    local histmap="$workspace/histmap.toml"

    local path_re='^[[:space:]]*path[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'

    local best_parent=""
    local best_length=-1
    local line
    local candidate

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ "$path_re" ]]; then
            candidate="${workspace}/${match[1]}"
            candidate="${candidate:A}"

            if [[ "$candidate" == "$context" ]]; then
                continue
            fi

            if [[ "$context" == "$candidate"/* ]]; then
                if (( ${#candidate} > best_length )); then
                    best_parent="$candidate"
                    best_length=${#candidate}
                fi
            fi
        fi
    done < "$histmap"

    [[ -n "$best_parent" ]] || return 1

    print -r -- "$best_parent"
}

typeset -g _HISTCMD_MODE="global"
typeset -g _HISTCMD_ACTIVE_CONTEXT=""
typeset -gi _HISTCMD_HISTORY_PUSHED=0
typeset -gi _HISTCMD_HISTSIZE=10000
typeset -gi _HISTCMD_SAVEHIST=10000

typeset -gA _HISTCMD_SAVED_HISTORY_OPTIONS
typeset -gi _HISTCMD_HISTORY_OPTIONS_SAVED=0

_histcmd_save_history_options() {
    (( _HISTCMD_HISTORY_OPTIONS_SAVED )) && return 0

    local option

    for option in \
        APPEND_HISTORY \
        SHARE_HISTORY \
        INC_APPEND_HISTORY \
        INC_APPEND_HISTORY_TIME \
        HIST_IGNORE_ALL_DUPS \
        HIST_SAVE_NO_DUPS \
        HIST_EXPIRE_DUPS_FIRST \
        HIST_REDUCE_BLANKS \
        HIST_FIND_NO_DUPS \
        HIST_FCNTL_LOCK
    do
        _HISTCMD_SAVED_HISTORY_OPTIONS[$option]="${options[$option]}"
    done

    _HISTCMD_HISTORY_OPTIONS_SAVED=1
}

_histcmd_apply_history_options() {
    _histcmd_save_history_options

    setopt APPEND_HISTORY
    unsetopt SHARE_HISTORY
    unsetopt INC_APPEND_HISTORY
    unsetopt INC_APPEND_HISTORY_TIME

    setopt HIST_IGNORE_ALL_DUPS
    setopt HIST_SAVE_NO_DUPS
    setopt HIST_EXPIRE_DUPS_FIRST
    setopt HIST_REDUCE_BLANKS
    setopt HIST_FIND_NO_DUPS
    setopt HIST_FCNTL_LOCK
}

_histcmd_restore_history_options() {
    (( _HISTCMD_HISTORY_OPTIONS_SAVED )) || return 0

    local option

    for option in ${(k)_HISTCMD_SAVED_HISTORY_OPTIONS}; do
        if [[ "${_HISTCMD_SAVED_HISTORY_OPTIONS[$option]}" == "on" ]]; then
            setopt "$option"
        else
            unsetopt "$option"
        fi
    done

    _HISTCMD_SAVED_HISTORY_OPTIONS=()
    _HISTCMD_HISTORY_OPTIONS_SAVED=0
}

_histcmd_restore_global() {
    if (( _HISTCMD_HISTORY_PUSHED )); then
        fc -P
        _HISTCMD_HISTORY_PUSHED=0
    fi

    _histcmd_restore_history_options

    _HISTCMD_MODE="global"
    _HISTCMD_ACTIVE_CONTEXT=""
}

_histcmd_activate_context() {
    local context="$1"
    local histfile="$context/histfile"

    [[ -f "$histfile" ]] || return 1

    if [[ "$_HISTCMD_MODE" == "context" && "$_HISTCMD_ACTIVE_CONTEXT" == "$context" ]]; then
        return 0
    fi

    if (( _HISTCMD_HISTORY_PUSHED )); then
        fc -P
    fi

    _histcmd_apply_history_options

    fc -p "$histfile" "$_HISTCMD_HISTSIZE" "$_HISTCMD_SAVEHIST"
    fc -RI "$histfile"

    _HISTCMD_HISTORY_PUSHED=1
    _HISTCMD_MODE="context"
    _HISTCMD_ACTIVE_CONTEXT="$context"
}

_histcmd_activate_empty() {
    if [[ "$_HISTCMD_MODE" == "empty" ]]; then
        return 0
    fi

    if (( _HISTCMD_HISTORY_PUSHED )); then
        fc -P
    fi

    _histcmd_restore_history_options

    fc -p

    _HISTCMD_HISTORY_PUSHED=1
    _HISTCMD_MODE="empty"
    _HISTCMD_ACTIVE_CONTEXT=""
}

_histcmd_create_context() {
    local workspace="$1"
    local current_directory="${PWD:A}"
    local relative_path
    local histmap="$workspace/histmap.toml"
    local histfile="$current_directory/histfile"

    if [[ "$current_directory" == "$workspace" ]]; then
        relative_path="."
    else
        relative_path="${current_directory#$workspace/}"
    fi

    if [[ "$relative_path" == *\"* || "$relative_path" == *$'\n'* ]]; then
        print -u2 -r -- "histcmd: unsupported context path: $relative_path"
        return 1
    fi

    cat >> "$histmap" <<EOF

[[context]]
path = "$relative_path"
recursive = true
EOF

    : > "$histfile"

    _histcmd_activate_context "$current_directory"
}

_histcmd_update_history_context() {
    local workspace
    local context

    workspace="$(_histcmd_find_workspace)" || {
        _histcmd_restore_global
        return 0
    }

    context="$(_histcmd_resolve_context)" || {
        _histcmd_create_context "$workspace"
        return $?
    }

    if [[ ! -e "$context/histfile" ]]; then
        : > "$context/histfile"
    elif [[ ! -f "$context/histfile" ]]; then
        print -u2 -r -- "histcmd: context histfile is not a regular file: $context/histfile"
        return 1
    fi

    _histcmd_activate_context "$context"
}

_histcmd_on_exit() {
    _histcmd_restore_global
}

autoload -U add-zsh-hook

add-zsh-hook chpwd _histcmd_update_history_context
add-zsh-hook precmd _histcmd_update_history_context
add-zsh-hook zshexit _histcmd_on_exit
