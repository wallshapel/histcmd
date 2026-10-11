Describe 'histcmd context resolution'
  Include lib/histcmd.zsh

  setup_workspace() {
    TEST_WORKSPACE="$(mktemp -d)"

    mkdir -p \
      "$TEST_WORKSPACE/backend/src" \
      "$TEST_WORKSPACE/frontend/frontend-1/src" \
      "$TEST_WORKSPACE/docs" \
      "$TEST_WORKSPACE/1. Recorrido intensivo por C++ y su biblioteca estándar/ejercicios"

    touch \
      "$TEST_WORKSPACE/Histfile" \
      "$TEST_WORKSPACE/backend/Histfile" \
      "$TEST_WORKSPACE/frontend/Histfile" \
      "$TEST_WORKSPACE/frontend/frontend-1/Histfile" \
      "$TEST_WORKSPACE/1. Recorrido intensivo por C++ y su biblioteca estándar/Histfile"

    cat > "$TEST_WORKSPACE/Histmap.toml" <<'EOF'
version = 1

[[context]]
path = "."
recursive = false

[[context]]
path = "backend"
recursive = true

[[context]]
path = "frontend"
recursive = true

[[context]]
path = "frontend/frontend-1"
recursive = true

[[context]]
path = "1. Recorrido intensivo por C++ y su biblioteca estándar"
recursive = true
EOF
  }

  cleanup_workspace() {
    cd /
    rm -rf "$TEST_WORKSPACE"
  }

  BeforeEach 'setup_workspace'
  AfterEach 'cleanup_workspace'

  It 'finds the workspace root'
    cd "$TEST_WORKSPACE/backend/src"

    When call _histcmd_find_workspace
    The output should equal "$TEST_WORKSPACE"
    The status should be success
  End

  It 'resolves the exact root context'
    cd "$TEST_WORKSPACE"

    When call _histcmd_resolve_context
    The output should equal "$TEST_WORKSPACE"
    The status should be success
  End

  It 'inherits a recursive context'
    cd "$TEST_WORKSPACE/backend/src"

    When call _histcmd_resolve_context
    The output should equal "$TEST_WORKSPACE/backend"
    The status should be success
  End

  It 'returns no context for an unmanaged directory'
    cd "$TEST_WORKSPACE/docs"

    When call _histcmd_resolve_context
    The output should be blank
    The status should be failure
  End

  It 'prefers the most specific nested context'
    cd "$TEST_WORKSPACE/frontend/frontend-1/src"

    When call _histcmd_resolve_context
    The output should equal "$TEST_WORKSPACE/frontend/frontend-1"
    The status should be success
  End

  It 'supports paths with spaces unicode and symbols'
    cd "$TEST_WORKSPACE/1. Recorrido intensivo por C++ y su biblioteca estándar/ejercicios"

    When call _histcmd_resolve_context
    The output should equal "$TEST_WORKSPACE/1. Recorrido intensivo por C++ y su biblioteca estándar"
    The status should be success
  End
End
