Let's wipe the slate clean and fix this in one go. Here is the exact, step-by-step recovery plan to nuke the hallucinated files, build the real bridge, and initialize it perfectly without any agent improvisation.

**Step 1: Nuke the fake folder**

Run this in your Voice Bot terminal to delete the physical directory the agent mistakenly created:

`rm -rf .vault_link`

**Step 2: Create the real Symlink**

Run this to build the actual bridge directly to your Obsidian vault:

`ln -s /Users/titane0/Programming/Mission_Control/TiTan .vault_link`

**Step 3: Copy the rules from the PWA project**

Make sure the agent knows how to behave by giving it your established rules. Assuming your PWA folder is right next to your voice bot folder, run:

`cp ../nearest-address-codes/opencode.json .`

`cp ../nearest-address-codes/AGENTS.md .`

_(If your folder structure is different, just copy those two files into your Voice Bot folder manually)._

**Step 4: The Iron-Clad Prompt**

Start OpenCode in your Voice Bot folder and paste this EXACT prompt. It leaves absolutely zero room for the agent to make up its own folders or names:

Plaintext

```
Read this carefully. Initialize the Voice_Cloning_Bot project using STRICTLY the existing vault structure via the .vault_link. Do NOT create new root folders.

1. Create the project passport exactly here: `./.vault_link/01_Projects/Voice_Cloning_Bot.md`.
2. Create a new Kanban board for this project in the root: `./.vault_link/Voice_Bot_Board.md`.
3. Add a project initialization entry to the EXACT existing log file: `./.vault_link/04_Logs/2026-04-18.md`. Do NOT create an '02_Sessions' folder.
4. Base your architecture context strictly on the rules already found in `./.vault_link/03_Brain/Architecture_Notes/Core_Principles.md`.
```