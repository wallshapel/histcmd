Describe 'histcmd history persistence'
  Include lib/histcmd.zsh

  setup_history() {
    PROJECT_ROOT="$PWD"
    TEST_DIRECTORY="$(mktemp -d)"
    TEST_HISTFILE="$TEST_DIRECTORY/Histfile"

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

End
