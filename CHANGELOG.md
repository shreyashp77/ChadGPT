# v1.3.0 - The "Document Context" Update 📄

Small but impactful improvements to error handling and user experience.

## � New Features

### 📄 Document Context (RAG)
- **Load Documents**: Upload PDF, TXT, or Markdown files to use as context for your entire conversation.
- **Persistent Context**: Document stays loaded throughout the chat session until you remove it.
- **Visual Indicator**: Orange chip shows which document is active, with one-tap removal.

## �🎯 Improvements

### 💬 User-Friendly Error Messages
- **Context Length Errors**: When your conversation or document exceeds the model's context limit, you now get a clear, actionable message with suggestions instead of a cryptic API error.
- **Smarter Error Parsing**: OpenRouter API errors are now parsed and displayed in human-readable format.

---

# v1.2.5 - The "Deep Insights & Polished" Update 🎨

Take your chats further with our new Deep Research mode and a refreshed, cleaner user interface.

## 🌟 New Features

### 🔍 Deep Research Mode
- **Multi-step Agent**: Our new research agent plans queries, searches the web, and reads multiple sources to synthesize a high-quality report.
- **Citation Support**: Reports now include citations from across the web.
- **Quick Access**: Just type `/research <query>` or select it from the attachment menu.
- **Live Status Feed**: See what the agent is doing in real-time (Planning, Searching, Reading URL...).

### 🛠️ Developer Tools (Easter Egg)
- **Settings Backup**: Export all your API keys, model aliases, and app configurations to a JSON file.
- **One-Tap Restore**: Import your settings back to get up and running instantly on any device.
- **How to Enable**: Tap the "Version" tile in About section 7 times to reveal the hidden Developer Settings.

### 📊 Advanced Analytics & Paid Models
- **Paid Model Support**: Full support for paid OpenRouter models with real-time cost tracking.
- **Per-Key Usage**: Analytics now tracks message counts and costs uniquely for *each* API key.
- **Daily Quotas**: Visual tracking for daily free model limits (50/day) per key.
- **Smart Dashboard**: A completely refined analytics UI that adapts to your currently active key.

### ✨ Premium UI Experience
- **Staggered Animations**: All attachment menu options now glide in with a beautiful, staggered animation.
- **Refined Layout**: Re-positioned Deep Research and Web Search options for quick, intuitive access.

## 🎯 UI Refinements
- **Borderless Settings Cards**: A cleaner, more modern look for the settings screen with enhanced shadows.
- **Material Polish**: Fixed splash artifacts and improved tap feedback across the entire app.
- **Themed Research Pill**: The research indicator now perfectly matches your app's accent color.

## 🐛 Bug Fixes
- Fixed a concurrency issue where research status updates would occasionally crash the app.
- Improved immutable state handling for long-running assistant tasks.

---

# v1.2.0 - The "Your Phone, Your AI" Update 📱

Run AI models **directly on your phone** — no internet, no servers, just you and your private AI.

## 🌟 New Features

### 📱 On-Device LLM Support
- **Run Models Locally**: Download and run GGUF models directly on your phone
- **Model Browser**: Browse and download models from Hugging Face
- **Background Downloads**: Models download in the background while you use the app
- **Hot Swap**: Switch between downloaded models instantly
- **Unload**: Free up RAM by unloading models when not in use
- **Persistent Storage**: Downloaded models survive app restarts

### ⚙️ Redesigned Settings
- **New Provider Selection UI**: Beautiful card-based provider selection with icons and descriptions
- **Cleaner Layout**: API key fields hidden when using On-Device provider  
- **Auto-Unload**: Local model automatically unloads when switching to another provider

### 🎯 Model Selector Improvements
- **Local Models in Selector**: Access downloaded models from the chat screen model picker
- **Load/Unload**: Tap to load, tap Unload to free memory
- **Shows Active Model**: Loaded model name displayed in selector button

## 🐛 Bug Fixes
- Fixed stop generation not working for local models
- Fixed "Already generating" error when sending new messages
- Improved local model state management

---

# v1.1.0 - The "Organized & Efficient" Update 🚀

We've packed this release with features to make your experience smoother, faster, and more organized.

## 🌟 New Features

### 📁 Smart Organization
- **Chat Folders**: Finally! You can now organize your chats into custom folders.
- **Tabbed Drawer**: The app drawer now has dedicated tabs for **Chats** (flat history) and **Folders** (organized view).
- **Persistent Folders**: Create empty folders that stick around, ready for your chats.
- **Improved Hierarchy**: Clean indentation and collapsible folder views.

### 🔍 Enhanced Search
- **Deep Search**: Search now looks through the *content* of your messages, not just the titles. Find that one code snippet instantly!

### ⚡ Performance & Background Tasks
- **Background Generation**: App now continues generating responses even if you minimize it (Android foreground service).
- **Notifications**: Get a shy little buzz when your long generation is complete.
- **API Caching**: Model lists are now cached (5 min TTL) to save on API calls and reduce lag.
- **Unload Model (LM Studio)**: Added an "Unload" button to the model selector to free up RAM when testing local models.

### 🎯 UI Refinements
- **Pinned Chats**: Keep your favorite conversations at the top.
- **Cleaner Header**: Removed clutter from the drawer header.
- **Platform-Specific Builds**: Release APKs are now split by architecture (arm64, armeabi, x86_64) for smaller downloads.

## 🐛 Bug Fixes
- Fixed indentation issues in the chat list.
- Fixed an issue where new folders weren't immediately visible.
- Improved error handling for network connections.

---
*Happy Chadding!* 💪
