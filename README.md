<!-- When you change this file, update .github/README.md the same way (GitHub shows .github/README.md on the repo home page first). -->

<div align="center">

# CmdPal Search Hub

**Multi-engine web search for [PowerToys Command Palette](https://learn.microsoft.com/windows/powertoys/command-palette/)**

[![Releases & MSIX](https://img.shields.io/badge/Releases-MSIX%20%7C%20build-0969DA?logo=github)](https://github.com/zunaidFarouque/search-hub-extension-for-cmd-pal/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](/LICENSE)
[![.NET](https://img.shields.io/badge/.NET-9-512BD4?logo=dotnet)](https://dotnet.microsoft.com/download)

</div>

**CmdPal Search Hub** is a Command Palette extension that puts **many web search engines behind one command**: type a short **abbreviation** and your **query**, pick a result, and open the right site. Add **custom URL templates** next to the built-ins, optionally turn on **query suggestions** and **in-palette previews** (with API keys where rich previews are supported).

> [!NOTE]
> Install the latest **`.msix`** from [**GitHub Releases**](https://github.com/zunaidFarouque/search-hub-extension-for-cmd-pal/releases) when available, or **build from source** (below). After installing or updating, use **Reload Command Palette extensions** in Command Palette so the host picks up the package.

## Features

- **One hub command** — Open the hub from Command Palette; use `prefix query` (e.g. `g cats`, `yt lo-fi`) when you have abbreviations configured.
- **Built-in engines** — Google, YouTube, GitHub, Bing, DuckDuckGo, and many more (see list below); enable/disable and edit abbreviations in the UI.
- **Custom providers** — Add engines with a URL template using `{0}` for the encoded query.
- **Query suggestions** — Optional suggestions for **Google** and **YouTube** (public suggest endpoints; uses the network).
- **Result preview** — Optional **Preview** in the more menu; **rich** YouTube and Google previews when you supply API keys in settings.
- **Settings in two places** (by design):
  - **Command Palette** — **Configure search providers** for the full engine list, add/edit custom providers, and hub key form.
  - **Command Palette Settings 뿯↽ Extensions 뿯↽ this extension** — Toggles (suggestions, preview) and preview API key fields (stored with your hub data).

## Built-in search providers

Abbreviations shown are defaults; you can change them in **Configure search providers**.

| Engine           | Default prefix |
| ---------------- | -------------- |
| Google           | `g`            |
| YouTube          | `yt`           |
| GitHub           | `gh`           |
| Bing             | `b`            |
| DuckDuckGo       | `ddg`          |
| Wikipedia        | `wiki`         |
| Stack Overflow   | `so`           |
| Reddit           | `reddit`       |
| X (Twitter)      | `x`            |
| Amazon           | `amazon`       |
| IMDb             | `imdb`         |
| Google Maps      | `maps`         |
| Netflix          | `nf`           |
| Spotify          | `sp`           |
| MDN Web Docs     | `mdn`          |
| npm              | `npm`          |
| PyPI             | `pypi`         |
| crates.io        | `crates`       |
| Docker Hub       | `dh`           |
| Google Translate | `tr`           |
| Google Scholar   | `scholar`      |
| Google News      | `news`         |
| Brave Search     | `brave`        |
| Wolfram\|Alpha   | `wa`           |
| Internet Archive | `ia`           |

## Optional API keys (rich preview)

Rich previews for **YouTube** and **Google** use official APIs. Keys are **optional**; without them you can still search and use simpler preview behavior where applicable.

- **YouTube** — [YouTube Data API v3](https://developers.google.com/youtube/v3) key.
- **Google** — [Programmable Search Engine](https://developers.google.com/custom-search/v1/overview) API key and **search engine ID (cx)**.

Configure these under **Extension settings** for this extension (and related toggles). Data is stored locally with the hub in `%LocalAppData%\CmdPalSearchHub\providers.json`.

## Requirements

- **Windows** 10 (19041+) / 11
- [PowerToys](https://github.com/microsoft/PowerToys) with **Command Palette** enabled
- **.NET 9 SDK** — to build from source ([download](https://dotnet.microsoft.com/download))
- For scripted local sign/install: **Windows SDK** (`signtool`) — see [docs/Signing.md](/docs/Signing.md)

## Build and install (from source)

From the repository root (folder containing `CmdPal_UniversalSearchHub_Extension.sln`):

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File ./build-install.ps1
```

Approve the **UAC** prompt when it appears, then **Reload Command Palette extensions**.

Quick compile check (no MSIX):

```powershell
dotnet build .\CmdPal_UniversalSearchHub_Extension\CmdPal_UniversalSearchHub_Extension.csproj -c Debug -r win-x64 -p:PublishSingleFile=false
```

More detail: [AGENTS.md](/AGENTS.md), [docs/Install-After-Code-Changes.md](/docs/Install-After-Code-Changes.md), [docs/Signing.md](/docs/Signing.md).

## GitHub Releases

- **Download:** [Releases](https://github.com/zunaidFarouque/search-hub-extension-for-cmd-pal/releases) — install the **`.msix`**. If the package is **self-signed**, import the matching **`CmdPal_CI_Public.cer`** to **Local Machine → Trusted People** first ([docs/Signing.md](/docs/Signing.md)). For **strangers / WinGet**, ship a **publicly trusted** (CA-signed) MSIX ([docs/WinGet-and-distribution.md](/docs/WinGet-and-distribution.md)).
- **Create a release:** [Actions → Release](https://github.com/zunaidFarouque/search-hub-extension-for-cmd-pal/actions/workflows/release.yml) (**workflow_dispatch**). CI artifacts: [`.github/workflows/build.yml`](/.github/workflows/build.yml).
- **WinGet:** Templates in [`winget-submission/`](winget-submission/README.md); submit via [docs/Submit-to-winget-pkgs.md](docs/Submit-to-winget-pkgs.md).

## Demo / screenshots

Add PNGs under [`docs/media/`](/docs/media/):

- **`docs/media/hub.png`** — hub command with prefix + query (suggestions optional).
- **`docs/media/providers.png`** — **Configure search providers**.

Then add images to this section, for example:

```html
<p align="center">
  <img src="/docs/media/hub.png" alt="CmdPal Search Hub" width="720" />
</p>
```

See [docs/media/adding-screenshots.md](/docs/media/adding-screenshots.md) for tips.

## Related

- [PowerToys Command Palette — extensibility overview](https://learn.microsoft.com/windows/powertoys/command-palette/extensibility-overview)
- [LLM extension for Command Palette](https://github.com/LioQing/llm-extension-for-cmd-pal)

## License

[MIT](/LICENSE)
