Describe 'histcmd history persistence'
  Include lib/histcmd.zsh

  setup_history() {
    PROJECT_ROOT="$PWD"
    TEST_DIRECTORY="$(mktemp -d)"
    TEST_HISTFILE="$TEST_DIRECTORY/histfile"

    touch "$TEST_HISTFILE"
  }

  cleanup_history() {
    rm -rf "$TEST_DIRECTORY"
  }

  BeforeEach 'setup_history'
  AfterEach 'cleanup_history'

  It 'writes the active contextual history when the shell exits'
    command="
      HISTFILE='$TEST_DIRECTORY/global-history'
      HISTSIZE=100
      SAVEHIST=100

      source '$PROJECT_ROOT/lib/histcmd.zsh'

      fc -p '$TEST_HISTFILE'

      _HISTCMD_HISTORY_PUSHED=1
      _HISTCMD_MODE='context'
      _HISTCMD_ACTIVE_CONTEXT='$TEST_DIRECTORY'

      print -s -- 'echo persisted-context-command'

      _histcmd_on_exit

      cat '$TEST_HISTFILE'
    "

    When run command zsh -f -i -c "$command"

    The output should include 'echo persisted-context-command'
    The status should be success
  End

  It 'loads existing history when activating a context'
    FC_LOG="$TEST_DIRECTORY/fc.log"

    fc() {
      print -r -- "$*" >> "$FC_LOG"
    }

    When call _histcmd_activate_context "$TEST_DIRECTORY"

    The contents of file "$FC_LOG" should include "-p $TEST_HISTFILE"
    The contents of file "$FC_LOG" should include "-RI $TEST_HISTFILE"
    The status should be success
  End

  It 'applies and restores contextual history options'
    check_history_options() {
      setopt SHARE_HISTORY
      unsetopt HIST_SAVE_NO_DUPS
      unsetopt HIST_FCNTL_LOCK

      _histcmd_apply_history_options || return 1

      [[ ! -o SHARE_HISTORY ]] || return 2
      [[ -o HIST_SAVE_NO_DUPS ]] || return 3
      [[ -o HIST_FCNTL_LOCK ]] || return 4

      _histcmd_restore_history_options || return 5

      [[ -o SHARE_HISTORY ]] || return 6
      [[ ! -o HIST_SAVE_NO_DUPS ]] || return 7
      [[ ! -o HIST_FCNTL_LOCK ]] || return 8
    }

    When call check_history_options

    The status should be success
  End

  It 'routes merged history writes to the child histfile'
    CHILD_DIRECTORY="$TEST_DIRECTORY/child"
    CHILD_HISTFILE="$CHILD_DIRECTORY/histfile"
    FC_LOG="$TEST_DIRECTORY/fc.log"

    mkdir -p "$CHILD_DIRECTORY"
    touch "$CHILD_HISTFILE"

    fc() {
      print -r -- "$*" >> "$FC_LOG"
    }

    _HISTCMD_MERGED_HISTORY=1
    _HISTCMD_WRITE_HISTFILE="$CHILD_HISTFILE"

    When call _histcmd_route_merged_history $'echo CHILD-NEW\n'

    The contents of file "$FC_LOG" should include "-p $CHILD_HISTFILE"
    The contents of file "$FC_LOG" should include "-RI $CHILD_HISTFILE"
    The contents of file "$FC_LOG" should not include "$TEST_HISTFILE"
    The status should be success
  End  

  It 'loads parent history before child history'
    CHILD_DIRECTORY="$TEST_DIRECTORY/child"
    CHILD_HISTFILE="$CHILD_DIRECTORY/histfile"
    FC_LOG="$TEST_DIRECTORY/fc.log"

    mkdir -p "$CHILD_DIRECTORY"
    touch "$CHILD_HISTFILE"

    fc() {
      print -r -- "$*" >> "$FC_LOG"
    }

    check_parent_load_order() {
      _HISTCMD_HISTORY_PUSHED=0
      _HISTCMD_MERGED_HISTORY=0
      _HISTCMD_WRITE_HISTFILE=""
      _HISTCMD_MODE="global"
      _HISTCMD_ACTIVE_CONTEXT=""

      _histcmd_activate_context_with_parent \
        "$CHILD_DIRECTORY" \
        "$TEST_DIRECTORY" || return 1

      local parent_line
      local child_line

      parent_line="$(
        grep -nF -- "-RI $TEST_HISTFILE" "$FC_LOG" |
          head -n 1 |
          cut -d: -f1
      )"

      child_line="$(
        grep -nF -- "-RI $CHILD_HISTFILE" "$FC_LOG" |
          head -n 1 |
          cut -d: -f1
      )"

      [[ -n "$parent_line" && -n "$child_line" ]] || return 2
      (( parent_line < child_line )) || return 3

      [[ "$_HISTCMD_WRITE_HISTFILE" == "$CHILD_HISTFILE" ]] || return 4
      (( _HISTCMD_MERGED_HISTORY == 1 )) || return 5
    }

    When call check_parent_load_order

    The status should be success
  End    

End
