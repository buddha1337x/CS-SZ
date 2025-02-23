# CS-SZ - Safezone System for FiveM

A powerful and efficient Safezone system for FiveM using **oxmysql** for persistent storage.

## 📌 Features
- Create and manage safezones dynamically
- Safezones are stored in **SQL database**
- **Permissions-based access** for administrators
- Safezones persist after a restart
- **Automatic syncing** for all players

---

## 📥 Installation

### 1️⃣ Install **oxmysql**
Ensure that **oxmysql** is installed and running on your server.  
If you haven't installed it yet, download and add it to your server:

1. Download oxmysql from [GitHub](https://github.com/overextended/oxmysql).
2. Place it in your `resources` folder.
3. Add the following to your **server.cfg**:

   ensure oxmysql
   add_ace group.admin CS-SZ allow

4. Run the safezones sql in your fivem database

**commands**
/createsafezone
/deletesafezone
/safezones