# 🌾 AgriConnect - Direct Agricultural Marketplace

AgriConnect is a full-stack mobile application designed to bridge the gap between farmers and consumers/buyers. By cutting out intermediaries, the platform enables farmers to list their agricultural produce directly, manage inventory, and connect transparently with buyers in real-time.

---

## 🚀 Key Features

- **Dual-User Profiles:** Custom interfaces and workflows for both Farmers (Sellers) and Buyers/Consumers.
- **Produce Management:** Farmers can easily list, edit, update, or remove produce items along with pricing, quantities, and high-quality images.
- **Real-Time Marketplace:** Buyers can explore fresh produce, search by categories, and view detailed product information.
- **Secure Authentication:** User sign-up and login powered by Firebase Authentication.
- **Live Database Sync:** Instant updates across product listings and inventory using Cloud Firestore.

---

## 🛠️ Tech Stack & Architecture

- **Frontend / Cross-Platform Mobile:** [Flutter](https://flutter.dev/) (Dart)
- **Backend-as-a-Service (BaaS):** [Firebase](https://firebase.google.com/)
  - **Authentication:** Email/Password & Phone Auth
  - **Database:** Cloud Firestore (NoSQL Real-time Database)
  - **Storage:** Firebase Cloud Storage (Product Images & User Avatars)
- **State Management:** Provider / BLoC *(Specify what you used)*
- **Version Control:** Git & GitHub


## ⚙️ Getting Started & Local Setup

To run this project locally, follow these steps:

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed on your machine.
- An Android Emulator or physical device with Developer Options enabled.
- A Firebase project set up in the [Firebase Console](https://console.firebase.google.com/).

### Installation

1. **Clone the Repository:**
   ```bash
   git clone [https://github.com/yourusername/agriconnect.git](https://github.com/yourusername/agriconnect.git)
   cd agriconnect
