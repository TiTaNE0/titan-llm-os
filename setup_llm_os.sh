# --- MISSION_CONTROL VAULT LINKING ---
# The OS is hosted natively in iCloud for mobile sync
OS_VAULT_PATH="$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Mission_Control"

echo "🔗 Connecting project to Mission_Control Brain..."
if [ -d "$OS_VAULT_PATH" ]; then
    ln -sfn "$OS_VAULT_PATH" .vault_link
    echo "✅ Symlink created successfully: .vault_link -> $OS_VAULT_PATH"
else
    echo "⚠️  WARNING: Mission_Control vault not found at $OS_VAULT_PATH."
    echo "Please ensure iCloud Drive is synced and the folder exists."
    exit 1
fi
