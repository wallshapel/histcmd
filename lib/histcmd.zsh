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

_histcmd_context_flag_enabled() {
    emulate -L zsh

    local context="$1"
    local flag="$2"

    [[ "$flag" == "include-parent" || "$flag" == "include-ancestors" || "$flag" == "include-children" || "$flag" == "include-descendants" ]] || return 1

    local workspace
    workspace="$(_histcmd_find_workspace)" || return 1

    local histmap="$workspace/histmap.toml"

    local header_re='^[[:space:]]*\[\[context\]\][[:space:]]*$'
    local path_re='^[[:space:]]*path[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'
    local flag_re="^[[:space:]]*${flag}[[:space:]]*=[[:space:]]*(true|false)[[:space:]]*$"

    local context_path=""
    local context_flag="false"
    local line
    local candidate

    while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ "$line" =~ "$header_re" ]]; then
            if [[ -n "$context_path" ]]; then
                candidate="${workspace}/${context_path}"
                candidate="${candidate:A}"

                if [[ "$candidate" == "$context" ]]; then
                    [[ "$context_flag" == "true" ]]
                    return
                fi
            fi

            context_path=""
            context_flag="false"

        elif [[ "$line" =~ "$path_re" ]]; then
            context_path="$match[1]"

        elif [[ "$line" =~ "$flag_re" ]]; then
            context_flag="$match[1]"
        fi
    done < "$histmap"

    if [[ -n "$context_path" ]]; then
        candidate="${workspace}/${context_path}"
        candidate="${candidate:A}"

        if [[ "$candidate" == "$context" ]]; then
            [[ "$context_flag" == "true" ]]
            return
        fi
    fi

    return 1
}

_histcmd_context_includes_parent() {
    _histcmd_context_flag_enabled "$1" "include-parent"
}

_histcmd_context_includes_ancestors() {
    _histcmd_context_flag_enabled "$1" "include-ancestors"
}

_histcmd_context_includes_children() {
    _histcmd_context_flag_enabled "$1" "include-children"
}

_histcmd_context_includes_descendants() {
    _histcmd_context_flag_enabled "$1" "include-descendants"
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

_histcmd_find_ancestor_contexts() {
    emulate -L zsh

    local context="$1"
    local current="$context"
    local parent
    local -a ancestors

    while parent="$(_histcmd_find_parent_context "$current")"; do
        ancestors=("$parent" "${ancestors[@]}")
        current="$parent"
    done

    (( ${#ancestors[@]} > 0 )) || return 1

    printf '%s\n' "${ancestors[@]}"
}

_histcmd_find_child_contexts() {
    emulate -L zsh

    local context="$1"
    local workspace
    workspace="$(_histcmd_find_workspace)" || return 1

    local histmap="$workspace/histmap.toml"
    local path_re='^[[:space:]]*path[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'

    local line
    local candidate
    local parent
    local -a children

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ "$path_re" ]] || continue

        candidate="${workspace}/${match[1]}"
        candidate="${candidate:A}"

        if [[ "$candidate" != "$workspace" && "$candidate" != "$workspace"/* ]]; then
            continue
        fi

        [[ "$candidate" == "$context"/* ]] || continue

        parent="$(_histcmd_find_parent_context "$candidate")" || continue

        if [[ "$parent" == "$context" ]]; then
            children+=("$candidate")
        fi
    done < "$histmap"

    (( ${#children[@]} > 0 )) || return 1

    printf '%s\n' "${children[@]}"
}

_histcmd_find_descendant_contexts() {
    emulate -L zsh

    local context="$1"
    local workspace
    workspace="$(_histcmd_find_workspace)" || return 1

    local histmap="$workspace/histmap.toml"
    local path_re='^[[:space:]]*path[[:space:]]*=[[:space:]]*"([^"]*)"[[:space:]]*$'

    local line
    local candidate
    local -a descendants
    local -A seen

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ "$path_re" ]] || continue

        candidate="${workspace}/${match[1]}"
        candidate="${candidate:A}"

        if [[ "$candidate" != "$workspace" && "$candidate" != "$workspace"/* ]]; then
            continue
        fi

        [[ "$candidate" == "$context"/* ]] || continue

        if [[ -n "${seen[$candidate]:-}" ]]; then
            continue
        fi

        seen[$candidate]=1
        descendants+=("$candidate")
    done < "$histmap"

    (( ${#descendants[@]} > 0 )) || return 1

    printf '%s\n' "${descendants[@]}"
}

typeset -g _HISTCMD_MODE="global"
typeset -g _HISTCMD_ACTIVE_CONTEXT=""
typeset -gi _HISTCMD_HISTORY_PUSHED=0
typeset -gi _HISTCMD_HISTSIZE=10000
typeset -gi _HISTCMD_SAVEHIST=10000
typeset -gi _HISTCMD_MERGED_HISTORY=0
typeset -g _HISTCMD_WRITE_HISTFILE=""

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

_histcmd_apply_merged_history_options() {
    _histcmd_apply_history_options

    setopt INC_APPEND_HISTORY
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

_histcmd_compact_histfile() {
    local histfile="$1"

    [[ -f "$histfile" ]] || return 0

    fc -p "$histfile" "$_HISTCMD_HISTSIZE" "$_HISTCMD_SAVEHIST"
    fc -RI "$histfile"
    fc -P
}

_histcmd_pop_history() {
    (( _HISTCMD_HISTORY_PUSHED )) || return 0

    if (( _HISTCMD_MERGED_HISTORY )) && [[ -n "$_HISTCMD_WRITE_HISTFILE" ]]; then
        _histcmd_compact_histfile "$_HISTCMD_WRITE_HISTFILE"
    fi

    fc -P

    _HISTCMD_HISTORY_PUSHED=0
    _HISTCMD_MERGED_HISTORY=0
    _HISTCMD_WRITE_HISTFILE=""
}

_histcmd_restore_global() {
    _histcmd_pop_history
    _histcmd_restore_history_options

    _HISTCMD_MODE="global"
    _HISTCMD_ACTIVE_CONTEXT=""
}

_histcmd_activate_context() {
    local context="$1"
    local histfile="$context/histfile"

    [[ -f "$histfile" ]] || return 1

    if [[
        "$_HISTCMD_MODE" == "context"
        && "$_HISTCMD_ACTIVE_CONTEXT" == "$context"
        && ! _HISTCMD_MERGED_HISTORY
    ]]; then
        return 0
    fi

    _histcmd_pop_history

    _histcmd_apply_history_options

    fc -p "$histfile" "$_HISTCMD_HISTSIZE" "$_HISTCMD_SAVEHIST"
    fc -RI "$histfile"

    _HISTCMD_HISTORY_PUSHED=1
    _HISTCMD_MODE="context"
    _HISTCMD_ACTIVE_CONTEXT="$context"
}

_histcmd_activate_context_with_sources() {
    local context="$1"
    shift

    local -a source_contexts=("$@")
    local histfile="$context/histfile"
    local source_context
    local source_histfile

    [[ -f "$histfile" ]] || return 1
    (( ${#source_contexts[@]} > 0 )) || return 1

    for source_context in "${source_contexts[@]}"; do
        [[ "$source_context" == "$context" ]] && continue

        source_histfile="$source_context/histfile"

        if [[ ! -e "$source_histfile" ]]; then
            : > "$source_histfile" || return 1
        elif [[ ! -f "$source_histfile" ]]; then
            print -u2 -r -- "histcmd: source histfile is not a regular file: $source_histfile"
            return 1
        fi
    done

    if [[
        "$_HISTCMD_MODE" == "context"
        && "$_HISTCMD_ACTIVE_CONTEXT" == "$context"
        && _HISTCMD_MERGED_HISTORY -eq 1
    ]]; then
        return 0
    fi

    _histcmd_pop_history
    _histcmd_apply_merged_history_options

    fc -p

    HISTSIZE="$_HISTCMD_HISTSIZE"
    SAVEHIST="$_HISTCMD_SAVEHIST"

    for source_context in "${source_contexts[@]}"; do
        [[ "$source_context" == "$context" ]] && continue

        fc -RI "$source_context/histfile"
    done

    fc -RI "$histfile"

    _HISTCMD_HISTORY_PUSHED=1
    _HISTCMD_MERGED_HISTORY=1
    _HISTCMD_WRITE_HISTFILE="$histfile"
    _HISTCMD_MODE="context"
    _HISTCMD_ACTIVE_CONTEXT="$context"
}

_histcmd_activate_context_with_parent() {
    _histcmd_activate_context_with_sources "$1" "$2"
}

_histcmd_activate_empty() {
    if [[ "$_HISTCMD_MODE" == "empty" ]]; then
        return 0
    fi

    _histcmd_pop_history
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

_histcmd_route_merged_history() {
    (( _HISTCMD_MERGED_HISTORY )) || return 0
    [[ -n "$_HISTCMD_WRITE_HISTFILE" ]] || return 0

    print -sr -- "${1%%$'\n'}"

    fc -p \
        "$_HISTCMD_WRITE_HISTFILE" \
        "$_HISTCMD_HISTSIZE" \
        "$_HISTCMD_SAVEHIST"

    fc -RI "$_HISTCMD_WRITE_HISTFILE"
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

    local -a sources
    local source_output
    local parent

    if _histcmd_context_includes_ancestors "$context"; then
        source_output="$(_histcmd_find_ancestor_contexts "$context")" || source_output=""

        if [[ -n "$source_output" ]]; then
            sources+=("${(@f)source_output}")
        fi

    elif _histcmd_context_includes_parent "$context"; then
        parent="$(_histcmd_find_parent_context "$context")" && sources+=("$parent")
    fi

    if _histcmd_context_includes_descendants "$context"; then
        source_output="$(_histcmd_find_descendant_contexts "$context")" || source_output=""

        if [[ -n "$source_output" ]]; then
            sources+=("${(@f)source_output}")
        fi

    elif _histcmd_context_includes_children "$context"; then
        source_output="$(_histcmd_find_child_contexts "$context")" || source_output=""

        if [[ -n "$source_output" ]]; then
            sources+=("${(@f)source_output}")
        fi
    fi

    if (( ${#sources[@]} > 0 )); then
        _histcmd_activate_context_with_sources "$context" "${sources[@]}"
    else
        _histcmd_activate_context "$context"
    fi
}

_histcmd_on_exit() {
    _histcmd_restore_global
}

autoload -U add-zsh-hook

add-zsh-hook chpwd _histcmd_update_history_context
add-zsh-hook precmd _histcmd_update_history_context
add-zsh-hook zshaddhistory _histcmd_route_merged_history
add-zsh-hook zshexit _histcmd_on_exit
