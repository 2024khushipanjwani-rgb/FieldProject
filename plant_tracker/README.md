# Workforce Management System

A comprehensive, role-based Flutter + Firebase application designed to streamline daily workforce operations. It bridges communication, attendance, and operational tracking between Workers, Managers, and Owners into a single, cohesive dashboard experience.

---

## 🌟 Key Features

- **Role-Based Access Control (RBAC)**: Secure access gating for three explicit roles—Worker, Manager, and Owner.
- **Smart Attendance System**: Daily tracking with granular timestamps (Check-In / Check-Out) calculating exact operational hours.
- **Automated Wage Calculation**: Dynamically computes gross pay based on individual hourly wages and daily shift durations natively inside Firestore.
- **Team Reporting Dashboard**: Graphical and data-rich overviews charting daily, weekly, and custom-range team performance.
- **Inventory & Order Management**: Monitor stock levels and trace active orders across the entire team.
- **Funding Request Pipeline**: A robust approval system allowing Managers to lodge requests (Cash/Materials) for rapid approvals or denials by the Owner.
- **Multi-Tier Notification Engine**: Firebase Cloud Messaging tied natively to business functions, keeping the Owner alerted to critical manager interactions and requests.

---

## 🛠️ Technology Stack

- **Frontend**: [Flutter](https://flutter.dev/) & Dart (Provider / StreamBuilder Architecture)
- **Backend**: [Firebase](https://firebase.google.com/)
  - **Firebase Authentication**: Seamless and secure role-based login.
  - **Cloud Firestore**: Real-time NoSQL database equipped with strict hierarchical Security Rules.
  - **Firebase Cloud Messaging (FCM)**: Remote notifications ecosystem.
- **Design UI**: Vanilla Flutter Widgets integrated directly with modern `fl_chart` analytics.

---

## 📂 Project Structure Overview

```
lib/
├── core/                  # Constants, AppRoles, Design Tokens
├── screens/               # Screen UI and layout architecture
│   ├── auth/              # Registration, Login, and Role-Gating logic
│   ├── worker/            # View-level modules for Workers (Salary, Shift logging)
│   ├── manager/           # Operational hub (Attendance marking, Inventory overrides)
│   └── owner/             # Executive views (Funding approval, Admin notifications)
├── main.dart              # Entry-point and Firebase configuration
└── firestore.rules        # Live structural Database permissions 
```

---

## 🚀 Setup & Installation

Follow these steps to safely compile and run the project locally.

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable version)
- Firebase CLI configurations (`firebase-tools`)

### 1. Clone the Repository
```bash
git clone https://github.com/2024khushipanjwani-rgb/FieldProject.git
cd FieldProject
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Connect to Firebase
 Ensure you have placed the generated `google-services.json` inside your `android/app` directory and `GoogleService-Info.plist` inside `ios/Runner`. 

### 4. Deploy Security Rules
To ensure the NoSQL constraints operate correctly regarding cross-role reads and deletions:
```bash
firebase deploy --only firestore:rules
```

### 5. Run the Application
```bash
flutter run
```

---

## 📱 Screenshots

> *Add application screenshots here to demonstrate the Worker Dashboard, Management Matrix, and the analytical Team Report graph screens.*

| Manager Dashboard | Attendance Tracker | Financial Report |
| :---: | :---: | :---: |
| *(manager-dash.png)* | *(attendance.png)* | *(report.png)* |

---

## 🔮 Future Improvements

- [ ] Connect the Notifications engine directly to native Push Notification integrations via FCM setup.
- [ ] Implement Offline Mode syncing logic for Managers working in low-connectivity areas.
- [ ] Export custom weekly team reports explicitly as PDF logic via backend Cloud Functions.

---

## 👤 Author

Developed globally maintaining scale and seamless architecture limits.  
**Khushi Hemant Panjwani**  
[GitHub Profile](https://github.com/2024khushipanjwani-rgb)
