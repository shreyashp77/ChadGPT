# ChadGPT

A powerful, privacy-focused AI chat client built with Flutter. ChadGPT runs locally on your machine and integrates with various AI providers to offer a complete assistant experience without relying on proprietary cloud ecosystems.

## ✨ Features

### 🤖 Multi-Provider Support
- **LM Studio**: Connect to your local LLMs for complete privacy and offline capability
- **OpenRouter**: Access a wide range of cloud models (filters for free models by default)
- **On-Device**: Run GGUF models directly on your phone – no internet, no server, truly private AI
- Auto-detect functionality for discovering LM Studio instances on your local network

### 🌐 Web Search Integration
Choose from multiple search providers to augment your AI with real-time web context:
- **SearXNG** (recommended, self-hosted, privacy-respecting)
- Brave Search
- Bing Search
- Google Custom Search
- Perplexity AI

### 📂 Smart Organization
- **Chat Folders**: Organize your conversations into custom folders
- **Tabbed Drawer**: Cleanly separate your chat history from your folder structure
- **Pinned Chats**: Keep important conversations at the top for quick access
- **Deep Search**: Search through the actual *content* of your messages, not just titles

### 🎨 Image Generation
Integrated **ComfyUI** support for high-quality local image generation.

> [!IMPORTANT]
> We use the **Z Image Turbo** model for fast, high-quality image generation. See the [ComfyUI Setup](#4-image-generation-comfyui) section for required model files.

### 🎙️ Voice Interaction
- **Speech-to-Text**: Dictate your messages hands-free
- **Text-to-Speech**: Have AI responses read aloud
- Dedicated voice mode overlay for seamless conversation

### 🎭 Personas
Switch between different AI personalities:
- **Default**: Helpful AI assistant
- **Senior Dev**: Expert coder with best practices
- **Bard**: Answers in rhyme and verse
- **Roast Master**: Sarcastic and brutally honest
- **Concise**: Short and to the point
- Create your own custom personas!

### 📎 Media Attachments
- Send images to vision-capable models
- Image preview and gallery support
- Share and save generated images

### 🎨 Theming
- Dark and light mode support
- Customizable theme colors
- Beautiful, modern UI with smooth animations

### ⚡ Performance
- **Smart Caching**: Efficiently manages API requests to minimize latency and cost
- **Background Architecture**: Robustly handles long-running generations without interruption
- **Notifications**: System-level alerts keep you informed when long tasks complete

### 📱 Cross-Platform
- Designed for **Android**, **iOS**, **Linux**, **Windows**, and **macOS**.
- **Background Capable**: Continues generating responses even when minimized (Android) via foreground services.

---

## 🚀 Setup & Dependencies

To get the full experience, you'll need to set up a few backend services.

### 1. The App (Flutter)

Ensure you have the [Flutter SDK](https://docs.flutter.dev/get-started/install) installed (Dart SDK ^3.10.3).

```bash
# Clone the repository
git clone <repository-url>
cd chadgpt

# Get dependencies
flutter pub get

# Run the app
flutter run
```

#### Building Release APKs

```bash
# Build release APKs split by architecture
flutter build apk --split-per-abi
```

---

### 2. Local LLM (LM Studio)

For local text generation with complete privacy:

1. Download and install [LM Studio](https://lmstudio.ai/)
2. Load a model of your choice
3. Start the **Local Inference Server** on port `1234` (default)
4. Ensure CORS is enabled in LM Studio settings if you run into connection issues

> [!TIP]
> Use the **Auto-detect** feature in ChadGPT settings to automatically discover LM Studio servers on your network!

---

### 2.5. On-Device Models (No Server Required)

Run AI models **directly on your phone** with no network connection needed:

1. Go to **Settings** → Select **On-Device** provider
2. Tap **Manage Local Models**
3. Browse and download GGUF models from Hugging Face
4. Models are downloaded once and stored locally
5. Tap a downloaded model to load it into memory

**Features:**
- 📥 **Background Downloads**: Continue using the app while models download
- 💾 **Persistent Storage**: Models survive app restarts
- 🔄 **Hot Swap**: Switch between downloaded models without re-downloading  
- ⏹️ **Unload**: Free up RAM by unloading models when not needed

> [!NOTE]
> Smaller quantized models (Q4_K_M, Q5_K_M) are recommended for mobile devices. A 0.5B-1B parameter model typically works well on most phones.

---

### 3. Web Search (SearXNG)

For privacy-respecting web search integration, we recommend SearXNG.

The easiest way is using Docker:

```bash
# Pull the image
docker pull searxng/searxng

# Run with a persistent configuration
docker run --rm -d -p 8080:8080 -v "${PWD}/searxng:/etc/searxng" searxng/searxng
```

**Configuration:**
- Set the SearXNG URL in app settings to `http://localhost:8080` (or use your custom URL)
- Auto-detect feature available to find SearXNG instances on your network

> [!IMPORTANT]
> To enable JSON format (required by the app), ensure `json` is added to the `search.formats` list in your SearXNG `settings.yml`:
> ```yaml
> search:
>   formats:
>     - html
>     - json
> ```

---

### 4. Image Generation (ComfyUI)

We use [ComfyUI](https://github.com/comfyanonymous/ComfyUI) for image generation.

#### ⚡ Z Image Turbo Configuration

> [!CAUTION]
> The app uses **Z Image Turbo** for fast, high-quality image generation. You **must** place the correct model files in your ComfyUI directories for the workflow to function properly.

**Required Files & Locations:**

| File Name | Description | ComfyUI Location |
|-----------|-------------|------------------|
| `z_image_turbo_bf16.safetensors` | The main UNET model | `ComfyUI/models/unet/` |
| `qwen_3_4b.safetensors` | CLIP/Text Encoder | `ComfyUI/models/clip/` |
| `ae.safetensors` | VAE Model | `ComfyUI/models/vae/` |

**Running ComfyUI:**

```bash
# For localhost access only
python main.py

# To make accessible from other devices (like your phone)
python main.py --listen 0.0.0.0
```

**Default port**: `8188`

> [!TIP]
> Use the **Auto-detect** feature in ChadGPT settings to find ComfyUI servers running on your network!

---

## 📸 Screenshots

*Coming soon*

---

## 🔧 Technology Stack

- **Framework**: Flutter / Dart
- **State Management**: Provider
- **Database**: SQLite (sqflite)
- **Local Storage**: SharedPreferences
- **HTTP Client**: http package
- **Markdown Rendering**: flutter_markdown
- **Syntax Highlighting**: flutter_highlighter
- **TTS/STT**: flutter_tts, speech_to_text
- **Notifications**: flutter_local_notifications
- **Background Tasks**: flutter_foreground_task
- **Wake Lock**: wakelock_plus
- **On-Device LLM**: llama_flutter_android (GGUF inference)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).

---

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
