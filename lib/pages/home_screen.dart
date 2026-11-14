
import 'package:flutter/material.dart';
import 'facilities_screen.dart';
import 'active_queues_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: SingleChildScrollView(
          child: Container(
            margin: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ------- Welcome card -------
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          "C",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Welcome back,",
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const Text(
                              "Good morning, Citizen",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.star,
                                color: Colors.orange, size: 16),
                            SizedBox(width: 4),
                            Text("1,250 Pts"),
                          ],
                        ),
                      ),

                      const SizedBox(width: 10),

                      Stack(
                        children: [
                          const Icon(
                            Icons.notifications,
                            color: Colors.blue,
                          ),
                          Positioned(
                            right: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // ------- Search bar -------
                TextField(
                  readOnly: true,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FacilitiesScreen(),
                      ),
                    );
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: "Search",
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ------- Facilities header -------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Facilities",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[300],
                      ),
                    ),

                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const FacilitiesScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "View all",
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 15),

                // ------- Facility icons row -------
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    facilityIcon(
                      Icons.business,
                      "Al-Nasr",
                      "Food & Bread",
                      selected: true,
                    ),
                    facilityIcon(
                      Icons.favorite_border,
                      "Relief Hub",
                      "Medical",
                    ),
                    facilityIcon(
                      Icons.home_outlined,
                      "Cent. Bakery",
                      "Flour Rations",
                    ),
                    facilityIcon(
                      Icons.inventory_2_outlined,
                      "Hope Depot",
                      "Emerg. Kits",
                    ),
                  ],
                ),

                const SizedBox(height: 25),

                // ------- Active reservation card -------
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white24,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "ACTIVE RESERVATION",
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                              ),
                            ),
                          ),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text("10:15 AM"),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      const Text(
                        "Bread & Ration Supply",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const Text(
                        "Ticket #DK-8492 • Family Bakery",
                        style: TextStyle(color: Colors.white),
                      ),

                      const SizedBox(height: 15),

                      const Divider(color: Colors.white38),

                      const SizedBox(height: 10),

                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.circle,
                                color: Colors.greenAccent,
                                size: 10,
                              ),
                              SizedBox(width: 6),
                              Text(
                                "2 citizens ahead • Ready",
                                style: TextStyle(color: Colors.white),
                              ),
                            ],
                          ),

                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ActiveQueuesScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "View",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                // ------- Available facilities header -------
                const Text(
                  "Facility Available in Your Area",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),

                const SizedBox(height: 15),

                // ------- Facility card 1 -------
                facilityCard(
                  openNow: true,
                  title: "Family Bakery - Daily Bread Dispensing",
                  description:
                      "Subsidized wheat pita quotas for registered households. Please present digital QR at entry...",
                  wait: "~15 mins",
                ),

                const SizedBox(height: 15),

                // ------- Facility card 2 -------
                facilityCard(
                  openNow: false,
                  title: "North Community - Baby Care Kits",
                  description:
                      "Infant milk formulas, sanitizers, and newborn diapers for registered mothers and guardians.",
                  wait: "~10 mins",
                ),
              ],
            ),
          ),
        ),
      ),

     
bottomNavigationBar: SafeArea(
  top: false,
  child: Container(
    height: 65,
    padding: const EdgeInsets.symmetric(horizontal: 15),
    decoration: const BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(18),
      ),
      border: Border(
        top: BorderSide(
          color: Color(0xFFE9EEF4),
          width: 0.8,
        ),
      ),
      boxShadow: [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 9,
          offset: Offset(0, -3),
        ),
      ],
    ),
    child: Row(
      children: [

        // Home - Selected
        Expanded(
          child: Center(
            child: Container(
              height: 40,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFE5F5FE),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home_outlined,
                    color: Color(0xFF159FE8),
                    size: 23,
                  ),
                  SizedBox(width: 7),
                  Text(
                    'Home',
                    style: TextStyle(
                      color: Color(0xFF00A5EA),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // My Queue
        Expanded(
          child: Center(
            child: IconButton(
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  'active_queues_screen',
                );
              },
              icon: const Icon(
                Icons.tune_rounded,
                color: Color(0xFF159FE8),
                size: 29,
              ),
            ),
          ),
        ),

        // Profile
        Expanded(
          child: Center(
            child: IconButton(
              onPressed: () {
                Navigator.pushReplacementNamed(
                  context,
                  'profile_screen',
                );
              },
              icon: const Icon(
                Icons.person_outline,
                color: Color(0xFF159FE8),
                size: 29,
              ),
            ),
          ),
        ),
      ],
    ),
  ),
),
    );}

  // ---------- Facility icon widget ----------
  Widget facilityIcon(
    IconData icon,
    String title,
    String subtitle, {
    bool selected = false,
  }) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
                border: selected
                    ? Border.all(color: Colors.blue, width: 2)
                    : null,
              ),
              child: Icon(icon, color: Colors.grey[700]),
            ),

            if (selected)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    color: Colors.blue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 10,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 6),

        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),

        Text(
          subtitle,
          style: TextStyle(
            fontSize: 10,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // ---------- Facility card widget ----------
  Widget facilityCard({
    required bool openNow,
    required String title,
    required String description,
    required String wait,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (openNow)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "Open Now",
                style: TextStyle(color: Colors.green),
              ),
            ),

          const SizedBox(height: 10),

          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            description,
            style: TextStyle(color: Colors.grey[600]),
          ),

          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.access_time,
                  color: Colors.blue,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text("Wait: $wait"),
              ],
            ),
          ),

          const SizedBox(height: 12),

          MaterialButton(
            minWidth: double.infinity,
            height: 48,
            color: Colors.blue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const FacilitiesScreen(),
                ),
              );
            },
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Join Queue Now",
                  style: TextStyle(color: Colors.white),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward,
                  color: Colors.white,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
