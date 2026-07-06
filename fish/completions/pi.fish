# Fish completion for pi coding agent
# Auto-generated

# Main options
complete -c pi -f -n "__fish_use_subcommand" -s h -l help -d "Show help"
complete -c pi -f -n "__fish_use_subcommand" -s v -l version -d "Show version"

# Provider & Model
complete -c pi -f -n "__fish_use_subcommand" -l provider -x -d "Provider name (anthropic, openai, google, deepseek, etc.)"
complete -c pi -f -n "__fish_use_subcommand" -l model -x -d "Model pattern or ID (e.g. sonnet, gpt-4o)"
complete -c pi -f -n "__fish_use_subcommand" -l api-key -x -d "API key (overrides env vars)"
complete -c pi -f -n "__fish_use_subcommand" -l models -x -d "Comma-separated model patterns for Ctrl+P cycling"
complete -c pi -f -n "__fish_use_subcommand" -l list-models -x -d "List available models (with optional search)"

# Thinking level
complete -c pi -f -n "__fish_use_subcommand" -l thinking -x -a "off minimal low medium high xhigh" -d "Set thinking level"

# Mode
complete -c pi -f -n "__fish_use_subcommand" -s p -l print -d "Non-interactive mode: process prompt and exit"
complete -c pi -f -n "__fish_use_subcommand" -l mode -x -a "text json rpc" -d "Output mode"

# Session
complete -c pi -f -n "__fish_use_subcommand" -s c -l continue -d "Continue previous session"
complete -c pi -f -n "__fish_use_subcommand" -s r -l resume -d "Select a session to resume"
complete -c pi -f -n "__fish_use_subcommand" -l session -x -d "Use specific session file or partial UUID"
complete -c pi -f -n "__fish_use_subcommand" -l session-id -x -d "Use exact project session ID"
complete -c pi -f -n "__fish_use_subcommand" -l fork -x -d "Fork specific session into a new session"
complete -c pi -f -n "__fish_use_subcommand" -l session-dir -x -d "Directory for session storage"
complete -c pi -f -n "__fish_use_subcommand" -l no-session -d "Ephemeral mode (don't save session)"
complete -c pi -f -n "__fish_use_subcommand" -s n -l name -x -d "Set session display name"

# Tools
complete -c pi -f -n "__fish_use_subcommand" -l no-tools -d "Disable all tools by default"
complete -c pi -f -n "__fish_use_subcommand" -l no-builtin-tools -d "Disable built-in tools by default"
complete -c pi -f -n "__fish_use_subcommand" -s t -l tools -x -d "Comma-separated allowlist of tool names"
complete -c pi -f -n "__fish_use_subcommand" -l exclude-tools -x -d "Comma-separated denylist of tool names"

# Extensions & Skills
complete -c pi -f -n "__fish_use_subcommand" -s e -l extension -x -d "Load an extension file (repeatable)"
complete -c pi -f -n "__fish_use_subcommand" -l no-extensions -d "Disable extension discovery"
complete -c pi -f -n "__fish_use_subcommand" -l skill -x -d "Load a skill file or directory"
complete -c pi -f -n "__fish_use_subcommand" -l no-skills -d "Disable skills discovery"
complete -c pi -f -n "__fish_use_subcommand" -l prompt-template -x -d "Load a prompt template"
complete -c pi -f -n "__fish_use_subcommand" -l no-prompt-templates -d "Disable prompt template discovery"
complete -c pi -f -n "__fish_use_subcommand" -l theme -x -d "Load a theme"
complete -c pi -f -n "__fish_use_subcommand" -l no-themes -d "Disable theme discovery"
complete -c pi -f -n "__fish_use_subcommand" -l no-context-files -d "Disable AGENTS.md discovery"

# Other
complete -c pi -f -n "__fish_use_subcommand" -l system-prompt -x -d "Replace default system prompt"
complete -c pi -f -n "__fish_use_subcommand" -l append-system-prompt -x -d "Append to system prompt"
complete -c pi -f -n "__fish_use_subcommand" -l export -r -d "Export session file to HTML"
complete -c pi -f -n "__fish_use_subcommand" -l verbose -d "Force verbose startup"
complete -c pi -f -n "__fish_use_subcommand" -l offline -d "Disable startup network operations"

# Extension CLI flags
complete -c pi -f -n "__fish_use_subcommand" -l mcp-config -r -d "Path to MCP config file"

# Subcommands (only show when no subcommand is used yet)
complete -c pi -f -n "__fish_use_subcommand" -a install -d "Install an extension package"
complete -c pi -f -n "__fish_use_subcommand" -a remove -d "Remove an extension package"
complete -c pi -f -n "__fish_use_subcommand" -a uninstall -d "Alias for remove"
complete -c pi -f -n "__fish_use_subcommand" -a update -d "Update pi and installed extensions"
complete -c pi -f -n "__fish_use_subcommand" -a list -d "List installed extensions"
complete -c pi -f -n "__fish_use_subcommand" -a config -d "Enable/disable package resources"

# Subcommand options
# install
complete -c pi -f -n "__fish_seen_subcommand_from install" -s l -d "Install locally (project scope)"
complete -c pi -f -n "__fish_seen_subcommand_from install" -a "npm: npm:@scope/pkg git:https://github.com/" -d "Package source prefix"

# remove/uninstall
complete -c pi -f -n "__fish_seen_subcommand_from remove uninstall" -s l -d "Remove from project scope"
complete -c pi -f -n "__fish_seen_subcommand_from remove uninstall" -a "(pi list 2>/dev/null | string trim | string split '\n')" -d "Installed package"

# update
complete -c pi -f -n "__fish_seen_subcommand_from update" -l extensions -d "Update packages only"
complete -c pi -f -n "__fish_seen_subcommand_from update" -l self -d "Update pi only"
complete -c pi -f -n "__fish_seen_subcommand_from update" -l force -d "Force reinstall"
