Describe 'histcmd build'

  setup_build() {
    PROJECT_ROOT="$PWD"
    TEST_WORKSPACE="$(mktemp -d)"
  }

  cleanup_build() {
    cd /
    rm -rf "$TEST_WORKSPACE"
  }

  BeforeEach 'setup_build'
  AfterEach 'cleanup_build'

  It 'creates missing histfiles for valid contexts'
    mkdir -p \
      "$TEST_WORKSPACE/backend/src" \
      "$TEST_WORKSPACE/Frontend C++"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "."
recursive = false

[[context]]
path = "backend"
recursive = true

[[context]]
path = "Frontend C++"
recursive = true
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The output should include 'Created histfile'
    The output should include 'Created backend/histfile'
    The output should include 'Created Frontend C++/histfile'

    The path "$TEST_WORKSPACE/histfile" should be file
    The path "$TEST_WORKSPACE/backend/histfile" should be file
    The path "$TEST_WORKSPACE/Frontend C++/histfile" should be file
    The status should be success
  End

  It 'does not create partial histfiles when a context directory is missing'
    mkdir -p "$TEST_WORKSPACE/backend"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "backend"
recursive = true

[[context]]
path = "missing-directory"
recursive = true
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The path "$TEST_WORKSPACE/backend/histfile" should not be exist
    The stderr should include 'context directory does not exist: missing-directory'
    The status should be failure
  End

  It 'rejects invalid histmap syntax without creating histfiles'
    mkdir -p "$TEST_WORKSPACE/backend"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "backend"
recursive = maybe
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The path "$TEST_WORKSPACE/backend/histfile" should not be exist
    The stderr should include 'invalid syntax'
    The status should be failure
  End

  It 'accepts include-parent in a valid context'
    mkdir -p "$TEST_WORKSPACE/parent/child"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "parent"
recursive = true

[[context]]
path = "parent/child"
recursive = true
include-parent = true
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The output should include 'Created parent/histfile'
    The output should include 'Created parent/child/histfile'

    The path "$TEST_WORKSPACE/parent/histfile" should be file
    The path "$TEST_WORKSPACE/parent/child/histfile" should be file
    The status should be success
  End

    It 'accepts include-ancestors in valid contexts'
    mkdir -p "$TEST_WORKSPACE/backend/api"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "."
recursive = false

[[context]]
path = "backend"
recursive = true
include-ancestors = false

[[context]]
path = "backend/api"
recursive = true
include-ancestors = true
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The output should include 'Created histfile'
    The output should include 'Created backend/histfile'
    The output should include 'Created backend/api/histfile'

    The path "$TEST_WORKSPACE/histfile" should be file
    The path "$TEST_WORKSPACE/backend/histfile" should be file
    The path "$TEST_WORKSPACE/backend/api/histfile" should be file
    The status should be success
  End

  It 'rejects invalid include-ancestors values'
    mkdir -p "$TEST_WORKSPACE/backend"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "backend"
recursive = true
include-ancestors = maybe
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The path "$TEST_WORKSPACE/backend/histfile" should not be exist
    The stderr should include 'invalid syntax'
    The status should be failure
  End

  It 'rejects duplicate include-ancestors declarations'
    mkdir -p "$TEST_WORKSPACE/backend"

    cat > "$TEST_WORKSPACE/histmap.toml" <<'EOF'
version = 1

[[context]]
path = "backend"
recursive = true
include-ancestors = true
include-ancestors = false
EOF

    cd "$TEST_WORKSPACE"

    When run command zsh "$PROJECT_ROOT/bin/histcmd" build

    The path "$TEST_WORKSPACE/backend/histfile" should not be exist
    The stderr should include 'duplicate include-ancestors'
    The status should be failure
  End

End
