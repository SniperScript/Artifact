# Artifact

Artifact is a highly aesthetic, minimal, and functional personal management application built with Flutter. Designed as a centralized "Sanctum," it unifies academic tracking, task management, financial logging, and ambient focus environments into a single, cohesive dashboard. Though not finished and furnished yet, it still gets the job done!

## Features

* **Dynamic Dashboard (The Sanctum):** A centralized hub providing an immediate overview of daily tasks, remaining budget, and system alerts.
* **Cloud-Synced Timetable:** A collapsible schedule module that automatically synchronizes with a custom Google Sheets matrix via a live CSV pipeline.
* **Academic Hub:** Integrated tools for tracking attendance and calculating/predicting GPA.
* **Directive Management:** A sleek, priority-based task tracking system that handles deadlines and completion states.
* **Financial Ledger:** A localized budget tracker that monitors monthly expenditures against a predefined primary limit.
* **Zenspace Reactor:** An immersive audio environment designed for deep focus. It features a custom animated UI and supports built-in ambient noises (Rain, Fire, White Noise), direct audio streaming from Google Drive folders.
* **Global Reactive Theming:** A custom state-managed Theme Controller that allows users to rebind the accent colors of individual UI components dynamically without requiring app restarts.
* **Local Persistence:** High-speed data caching, configuration storage, and offline capabilities utilizing SharedPreferences.

## Technical Architecture

* **Framework:** Flutter (Dart)
* **Local Database:** SharedPreferences
* **Networking/Cloud:** HTTP (for Google Sheets CSV parsing and Drive API requests)
* **Media Pipelines:** `just_audio` and `just_audio_background` (for background streaming)
* **State Management:** Stateful UI components and AnimatedBuilders linked to global controllers.

## Installation & Setup

### Prerequisites
* Flutter SDK (stable channel) installed on your system.
* Android Studio or Xcode for compilation.

### Build Instructions

1. Clone the repository:
   ```bash
   git clone [https://github.com/your-username/Artifact.git](https://github.com/your-username/Artifact.git)
   cd Artifact
