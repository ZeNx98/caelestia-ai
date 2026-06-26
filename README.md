# Caelestia AI Launcher Module

This repository contains the AI assistant chat launcher module for  **Caelestia** Shell.



## Repository Structure

```
caelestia-ai/
├── components/
│   └── controls/
│       └── StyledScrollBar.qml -> Custom scrollbar fix for scroll glitches and smooth transitions
├── modules/
│   └── launcher/
│       ├── ChatList.qml        -> Main chat UI view, LLM queries, and message delegate rendering
│       ├── Content.qml         -> Text input field wrappers and Up/Down keybind traversal handlers
│       ├── ContentList.qml     -> Loader for ChatList.qml and window state/sizing controller
│       ├── Wrapper.qml         -> Drawer visibility and initialization wrapper fix
│       └── system_prompt.txt   -> Starting system instructions loaded by the chat model
├── utils/
│   └── scripts/
│       ├── render_math.py      -> Python utility using Matplotlib to render LaTeX to PNG images
│       ├── web_search.py       -> DuckDuckGo/Yahoo/Wikipedia web search script (no dependencies)
│       ├── fetch_url.py        -> Web page content extractor (no dependencies)
│       └── fzf.js              -> FZF library compatibility fix replacing deprecated JS trim methods
└── README.md                   -> This installation guide
```

---

## Dependencies

Before installing, ensure the following tools and packages are installed and configured:

1. **Ollama**: Local AI model inference runner.
   - Install Ollama 
   - Pull at least one model, e.g., `ollama pull llama3`.

2. **Python & dependencies**:
   - Install Python 3.
   - Install `matplotlib` for LaTeX math rendering (the search and URL fetching scripts use only the standard library and require no external dependencies):
     ```bash
     pip install matplotlib
     # Or using uv:
     uv pip install matplotlib
     ```

---

## Arch Linux Tutorial

On Arch Linux, you can install the dependencies and package/install the launcher integration in two ways:

### Manual installation

1. **Install dependencies**:
   Install Python and Matplotlib using `pacman`:
   ```bash
   sudo pacman -S python-matplotlib
   ```



## Installation & Setup

0. **Localize the configuration (If needed)**:
   If you are running the system-wide default configuration from `/etc/xdg/quickshell/caelestia`, you must copy it to your user directory first so Quickshell works correctly with local modifications (otherwise Quickshell will ignore the `/etc/xdg` directory when a local directory exists):
   ```bash
   mkdir -p ~/.config/quickshell/
   cp -r /etc/xdg/quickshell/caelestia ~/.config/quickshell/
   ```

### Automated Patching

This is the safest method. It copies the completely new standalone files, then applies a unified diff patch to modify the existing Caelestia vanilla files (`Content.qml`, `ContentList.qml`, `Wrapper.qml`, `StyledScrollBar.qml`, and `fzf.js`), preserving any other updates or customizations you have made.

1. **Copy the new standalone files**:
   ```bash
   cp modules/launcher/ChatList.qml modules/launcher/system_prompt.txt ~/.config/quickshell/caelestia/modules/launcher/

   mkdir -p ~/.config/quickshell/caelestia/utils/scripts/
   cp utils/scripts/render_math.py utils/scripts/web_search.py utils/scripts/fetch_url.py ~/.config/quickshell/caelestia/utils/scripts/
   ```

2. **Apply the integration patch**:
   Apply the unified patch to the existing files:
   ```bash
   patch -Np1 -d ~/.config/quickshell/caelestia < caelestia-ai-integration.patch
   ```

3. **Make the scripts executable**:
   ```bash
   chmod +x ~/.config/quickshell/caelestia/utils/scripts/*.py
   ```

4. **Restart Caelestia**:
   ```bash
   quickshell -c caelestia kill; sleep 0.2; caelestia shell -d
   ```


## Keybinds & Controls

- **Activate Launcher**: Press your designated hotkey (e.g., `SUPER`).
- **Enter Chat Mode**: Type `?` followed by space to switch search focus to the AI assistant.
- **Cycle Message History**: While focusing on the chat input, press **Up** or **Down** arrows to traverse through your previously sent prompts.
