# Mobile Repair POS

A professional, offline-first Point-of-Sale (POS) system built for mobile phone and repair shops in Sri Lanka. It provides inventory management, sales tracking (including IMEI tracking), and repair job management.

## Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **Database**: Drift (SQLite)
- **Architecture**: Feature-first Clean Architecture

## Folder Structure
- `lib/core/`: Application-wide services, database configurations, routing, and theming.
- `lib/features/`: Feature modules (e.g., inventory, billing, settings), each isolated with `data`, `domain`, and `presentation` layers.
- `lib/providers/`: Global Riverpod providers.

## Setup Instructions

1. **Clone the repository**
   ```bash
   git clone https://github.com/kariyawasamnaveen/mobile-repair-pos.git
   cd mobile-repair-pos
   ```

2. **Fetch dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate drift and riverpod files**
   ```bash
   dart run build_runner build --delete-conflicting-outputs
   ```

4. **Environment Variables**
   Create a `.env` file at the root of the project with necessary local configurations (currently used for API keys/secrets if any).

5. **Run the app**
   ```bash
   flutter run
   ```

## Current Status
- Foundation (Core architecture, Drift SQLite, Riverpod, Routing) ✅
- Inventory Module (Items, IMEI tracking, CSV import, Stock adjustment) ✅
- Billing Module 🚧 (In Progress)
