import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UserPage extends StatefulWidget {
  const UserPage({super.key});

  @override
  State<UserPage> createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  String _username = 'Guest'; // Default value jika data tidak ditemukan
  String _email = 'guest@example.com'; // Default email
  String _appVersion = ''; // Variabel untuk menyimpan versi aplikasi

  @override
  void initState() {
    super.initState();
    _loadUserData(); // Memuat data pengguna saat halaman dimuat
    _loadAppInfo(); // Memuat informasi aplikasi
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    String? storedName = prefs.getString('name');
    String? storedEmail = prefs.getString('email'); // Pastikan key-nya 'email'

    print("Stored name: $storedName"); // Debugging
    print("Stored email: $storedEmail"); // Debugging

    setState(() {
      _username = storedName ?? 'Guest';
      _email = storedEmail ?? 'guest@example.com'; // Default jika email null
    });
  }

  // Fungsi untuk mendapatkan informasi versi aplikasi
  Future<void> _loadAppInfo() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      _appVersion = '${packageInfo.version} (${packageInfo.buildNumber})';
    });
  }

  Future<void> _handleLogout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('username');
    if (context.mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/signin', (route) => false);
    }
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      barrierDismissible: false, // Dialog tidak hilang saat klik area bebas
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
                16), // Tambahkan border radius untuk desain modern
          ),
          title: Row(
            children: [
              Icon(Icons.notifications,
                  color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Text(
                'Notification',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to logout?',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(
                  context), // Tutup dialog saat tombol Cancel ditekan
              icon: Icon(Icons.close, size: 16, color: theme.colorScheme.error),
              label: Text(
                'Cancel',
                style: TextStyle(color: theme.colorScheme.error),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: theme.colorScheme.error), // Tambahkan border merah
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: () => _handleLogout(context), // Panggil fungsi logout
              icon: Icon(Icons.logout,
                  size: 16, color: Colors.white), // Ikon putih
              label: Text(
                'Logout',
                style: TextStyle(color: Colors.white), // Teks putih
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color.fromARGB(255, 179, 4, 4), // Background merah
                foregroundColor: Colors.white, // Warna teks dan ikon putih
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: const Text('User Profile'),
      //   titleTextStyle: const TextStyle(
      //       color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
      //   centerTitle: true,
      //   backgroundColor: Colors.blueAccent,
      // ),
      appBar: AppBar(
        title: Row(
          children: const [
            Icon(Icons.person), // Icon for fan device
            SizedBox(width: 8), // Spacing between icon and text
            Text(
              'User Profile',
              style: TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color.fromARGB(255, 179, 4, 4),
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      body: SingleChildScrollView(
        // Tambahkan SingleChildScrollView di sini
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Foto Profil
              const CircleAvatar(
                radius: 50,
                backgroundColor: Colors.transparent,
                backgroundImage: AssetImage('assets/images/profile.png'),
              ),
              const SizedBox(height: 10),
              // Nama User
              Text(
                _username,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              // Email User
              Text(
                _email,
                style: const TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              // Card dengan daftar menu
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person, color: Colors.blue),
                      title: const Text('Edit Profile'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Tambahkan navigasi ke halaman edit profil
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.settings, color: Colors.blue),
                      title: const Text('Settings'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () {
                        // Tambahkan navigasi ke halaman pengaturan
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.logout,
                          color: Color.fromARGB(255, 179, 4, 4)),
                      title: const Text('Logout'),
                      onTap: () {
                        _showLogoutDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              // SizedBox dengan height tertentu sebagai pengganti Spacer
              SizedBox(height: MediaQuery.of(context).size.height * 0.15),
              // Tampilan versi aplikasi
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Column(
                  children: [
                    const Text(
                      'App Version',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                    Text(
                      _appVersion,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // @override
  // Widget build(BuildContext context) {
  //   return Scaffold(
  //     appBar: AppBar(
  //       title: const Text('User Profile'),
  //       titleTextStyle: const TextStyle(
  //           color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
  //       centerTitle: true,
  //       backgroundColor: Colors.blueAccent,
  //     ),
  //     body: Padding(
  //       padding: const EdgeInsets.all(16.0),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.center,
  //         children: [
  //           // Foto Profil
  //           const CircleAvatar(
  //             radius: 50,
  //             backgroundColor: Colors.transparent,
  //             backgroundImage: AssetImage(
  //                 'assets/images/profile.png'), // Ganti dengan path gambar profil
  //           ),
  //           const SizedBox(height: 10),
  //           // Nama User
  //           Text(
  //             _username, // Dinamis berdasarkan data dari SharedPreferences
  //             style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
  //           ),
  //           const SizedBox(height: 5),
  //           // Email User
  //           Text(
  //             _email, // Dinamis berdasarkan data dari SharedPreferences
  //             style: const TextStyle(fontSize: 16, color: Colors.grey),
  //           ),
  //           const SizedBox(height: 20),
  //           // Card dengan daftar menu
  //           Card(
  //             shape: RoundedRectangleBorder(
  //                 borderRadius: BorderRadius.circular(10)),
  //             elevation: 4,
  //             child: Column(
  //               children: [
  //                 ListTile(
  //                   leading: const Icon(Icons.person, color: Colors.blue),
  //                   title: const Text('Edit Profile'),
  //                   trailing: const Icon(Icons.arrow_forward_ios),
  //                   onTap: () {
  //                     // Tambahkan navigasi ke halaman edit profil
  //                   },
  //                 ),
  //                 const Divider(),
  //                 ListTile(
  //                   leading: const Icon(Icons.settings, color: Colors.blue),
  //                   title: const Text('Settings'),
  //                   trailing: const Icon(Icons.arrow_forward_ios),
  //                   onTap: () {
  //                     // Tambahkan navigasi ke halaman pengaturan
  //                   },
  //                 ),
  //                 const Divider(),
  //                 ListTile(
  //                   leading: const Icon(Icons.logout, color: Colors.red),
  //                   title: const Text('Logout'),
  //                   onTap: () {
  //                     _showLogoutDialog(context);
  //                   },
  //                 ),
  //               ],
  //             ),
  //           ),
  //           // Spacer untuk mendorong elemen versi ke bawah
  //           const Spacer(),
  //           // Tampilan versi aplikasi
  //           Padding(
  //             padding: const EdgeInsets.only(bottom: 16.0),
  //             child: Column(
  //               children: [
  //                 const Text(
  //                   'App Version',
  //                   style: TextStyle(
  //                     fontSize: 14,
  //                     color: Colors.grey,
  //                   ),
  //                 ),
  //                 Text(
  //                   _appVersion,
  //                   style: const TextStyle(
  //                     fontSize: 14,
  //                     fontWeight: FontWeight.bold,
  //                     color: Colors.grey,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }
}
