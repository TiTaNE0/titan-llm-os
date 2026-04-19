# 🚀 Welcome to TiTan LLM OS

Your local LLM Operating System. Bootstrapped and ready.

## ⚙️ Task Management
- `/new_task [Title] for [[Project]]` - Create a new task and add it to the project's Todo column
- `/archive_done` - Archive completed tasks to yearly folders and clean up board links
- `/close_day` - Analyze work, update Kanban board, and log daily summary

## 📝 Content Pipeline
- `/capture_idea [Idea]` - Save raw idea to inbox and add to Content Board Ideas column
- `/new_thread [Topic] from [[Source_Project]]` - Generate X thread draft from project context
- `/refactor_thread [[Target_File]]` - Rewrite draft enforcing Israeli dev tone and tight phrasing
- `/process_inbox` - Route inbox insights to projects, brain, or content templates
	  📥 /process_inbox Command Functionality
Purpose: Automatically routes and processes insights stored in your inbox based on their content and context.
Step-by-Step Execution:
1. Collection: Reads all .md files located in ./.vault_link/00_Inbox/
2. Routing Check: Scans each file for project Wiki-Links (e.g., [[Project_Name]])
3. Execution Logic:
   - If project link exists: Extracts insights and saves formatted file into that specific project's context
   - If insight is a global OS rule or prompt template: Moves it to either:
     - 03_Brain/Architecture_Notes/ (for core OS rules/principles)
     - 05_Content/00_Content_Templates/ (for content/prompt templates)
   - If NO project link exists: 
     - Analyzes the text content
     - Compares it against project passports in 01_Projects/
     - Attempts auto-routing based on content matching
     - If unsure about routing: Adds status: review to YAML frontmatter and leaves file in Inbox
4. Cleanup: Deletes the raw processed file from 00_Inbox/ after successful routing
5. Reporting: Outputs a bulleted summary showing what was moved and where it was routed
🔑 Key Features:
- Smart Routing: Uses wiki-links as primary routing signals
- Fallback Analysis: Content-based auto-routing when no explicit links exist
- Review System: Unclear items get flagged for manual review rather than misrouted
- Atomic Processing: Files are deleted from inbox only after successful routing
- Audit Trail: Provides clear summary of all routing actions taken
This command transforms your inbox from a simple holding area into an intelligent routing system that automatically organizes insights based on their semantic content and contextual links.

## 🔧 OS Administration
- `/graduate` - Scan logs for stable patterns and propose new core principles
- `/trace [topic/filename]` - Search project/brain/logs/archive for chronological topic evolution

---
*Tip: Commands update this dashboard automatically. Keep it open as your OS command reference.*