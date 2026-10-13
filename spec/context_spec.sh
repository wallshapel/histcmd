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
      "$TEST_WORKSPACE/histfile" \
      "$TEST_WORKSPACE/backend/histfile" \
      "$TEST_WORKSPACE/frontend/histfile" \
      "$TEST_WORKSPACE/frontend/frontend-1/histfile" \
      "$TEST_WORKSPACE/1. Recorrido intensivo por C++ y su biblioteca estándar/histfile"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
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
include-parent = true

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

  It 'creates a context automatically for an unmanaged directory'
    cd "$TEST_WORKSPACE/docs"

    When call _histcmd_resolve_context

    The output should equal "$TEST_WORKSPACE/docs"
    The path "$TEST_WORKSPACE/docs/histfile" should be file
    The contents of file "$TEST_WORKSPACE/histmap.toml" should include 'path = "docs"'
    The contents of file "$TEST_WORKSPACE/histmap.toml" should include 'recursive = true'
    The status should be success
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

  It 'does not create a child context when a recursive parent already applies'
    cd "$TEST_WORKSPACE/backend/src"

    When call _histcmd_resolve_context

    The output should equal "$TEST_WORKSPACE/backend"
    The path "$TEST_WORKSPACE/backend/src/histfile" should not be exist
    The status should be success
  End

  It 'detects include-parent on a context'
    cd "$TEST_WORKSPACE/frontend/frontend-1/src"

    context="$(_histcmd_resolve_context)"

    When call _histcmd_context_includes_parent "$context"

    The status should be success
  End

  It 'finds the immediate configured parent context'
    cd "$TEST_WORKSPACE/frontend/frontend-1/src"

    context="$(_histcmd_resolve_context)"

    When call _histcmd_find_parent_context "$context"

    The output should equal "$TEST_WORKSPACE/frontend"
    The status should be success
  End

End
