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
