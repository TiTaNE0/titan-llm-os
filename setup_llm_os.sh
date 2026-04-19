#!/bin/bash

# Путь к твоему "Мозгу" (Obsidian Vault)
VAULT_PATH="/Users/titane0/Programming/Mission_Control/TiTan"
LINK_NAME=".vault_link"

echo "🔍 Проверка подключения к LLM OS..."

# 1. Проверка и создание симлинка
if [ -L "$LINK_NAME" ]; then
    echo "✅ Мост уже установлен. Указывает на: $(readlink $LINK_NAME)"
else
    echo "⚙️ Создаю симлинк к Obsidian Vault..."
    ln -s "$VAULT_PATH" "$LINK_NAME"
    echo "✅ Мост успешно прокинут."
fi

# 2. Безопасность: прячем от Git
echo "🛡 Проверка .gitignore..."

if ! grep -q "$LINK_NAME" .gitignore 2>/dev/null; then
    echo "$LINK_NAME" >> .gitignore
    echo "✅ $LINK_NAME добавлен в .gitignore"
fi

# Прячем локальный загрузчик агента
if ! grep -q "AGENTS.md" .gitignore 2>/dev/null; then
    echo "AGENTS.md" >> .gitignore
    echo "✅ AGENTS.md добавлен в .gitignore"
fi

echo "🚀 Проект успешно подключен к единой базе знаний."
