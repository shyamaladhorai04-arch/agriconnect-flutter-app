import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'firebase_options.dart';
import 'services/firebase_service.dart';
import 'services/crop_service.dart';
import 'services/storage_service.dart';
import 'screens/messaging_screen.dart';

// Firebase instances
late FirebaseApp _firebaseApp;
late FirebaseDatabase _realtimeDatabase;

FirebaseApp get firebaseApp => _firebaseApp;
FirebaseDatabase get realtimeDatabase => _realtimeDatabase;

void openPublicProfile(
  BuildContext context, {
  required String userId,
  String? fallbackRole,
}) {
  if (userId.isEmpty) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PublicProfileScreen(
        userId: userId,
        fallbackRole: fallbackRole,
      ),
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  _firebaseApp = await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Initialize Firebase Realtime Database
  _realtimeDatabase = FirebaseDatabase.instanceFor(
    app: _firebaseApp,
    databaseURL: "https://agriconnect-1fdd3-default-rtdb.firebaseio.com/",
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FarmConnect',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E7D32)),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserLoggedIn();
  }

  Future<void> _checkUserLoggedIn() async {
    // Give splash screen a moment to display
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      // User is logged in - check their role from Firestore
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (userDoc.exists) {
          final role = userDoc.data()?['role'] ?? 'Farmer';

          // Navigate to appropriate dashboard
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => role.toString().contains('Buyer')
                    ? const BuyerDashboardScreen()
                    : const FarmerDashboardScreen(),
              ),
            );
          }
        }
      } catch (e) {
        print('Error checking user role: $e');
        // If there's an error, just show the welcome screen
      }
    }
    // If no user is logged in, just show the welcome screen (stay on SplashScreen)
  }

  @override
  Widget build(BuildContext context) {
    const primaryGreen = Color(0xFF2E7D32); // Deep green
    const gradientStart = Color(0xFFE8F5E9); // Very light green
    const gradientEnd = Color(0xFFC8E6C9); // Light green

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [gradientStart, gradientEnd],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 56),

              // Circular farm image — uses asset at assets/images/farm_field.jpg
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromRGBO(0, 0, 0, 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 56,
                  backgroundColor: Colors.white,
                  // backgroundImage: const AssetImage(
                  //   'assets/images/farm_field.jpg',
                  // ),
                  // fallback icon while asset not available
                  child: Icon(
                    Icons.agriculture,
                    size: 56,
                    color: const Color(0xFF16A34A),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'FarmConnect',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: primaryGreen,
                  letterSpacing: 0.4,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                'Direct from Farmer to Buyer',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.green.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const Spacer(),

              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      elevation: 2,
                    ),
                    child: const Text('Get Started'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _rememberMe = false;
  Role _role = Role.farmer;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final input = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (input.isEmpty || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Please enter email/mobile and password')),
        );
      }
      return;
    }

    // Check if input is mobile number (10 digits) or email
    final mobileRegex = RegExp(r'^\d{10}$');
    String authEmail;

    if (mobileRegex.hasMatch(input)) {
      // Mobile number - convert to auth email
      authEmail = 'user$input@agri.local';
    } else {
      // Email - use as-is
      authEmail = input;
    }

    setState(() => _isLoading = true);

    try {
      // Try to sign in with email and password
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      if (mounted) {
        // Check if user has a profile in Firestore
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get();

        String targetRole = 'farmer'; // default role

        if (userDoc.exists) {
          // User has profile - get their role from Firestore
          final roleData = userDoc.data()?['role'];
          if (roleData != null) {
            targetRole = roleData.toString().toLowerCase().trim();
            print('✓ Login: Found role in users collection: $targetRole');
          } else {
            print('⚠ Login: No role field in users doc, using default');
          }
        } else {
          print('⚠ Login: No users doc found');
        }

        if (mounted) {
          // If profile exists, go to dashboard; otherwise go to profile details screen
          print(
              'Debug: userDoc.exists=${userDoc.exists}, targetRole=$targetRole');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => userDoc.exists
                  ? (targetRole == 'buyer'
                      ? const BuyerDashboardScreen()
                      : const FarmerDashboardScreen())
                  : (_role == Role.farmer
                      ? const FarmerProfileDetailsScreen()
                      : const BuyerProfileDetailsScreen()),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        String errorMessage = 'Login failed';
        if (e.code == 'user-not-found') {
          errorMessage =
              'No account found with this email. Please register first.';
        } else if (e.code == 'wrong-password') {
          errorMessage = 'Incorrect password. Please try again.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email address.';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This account has been disabled.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    const lightGrey = Color(0xFFF5F5F5);
    const blue = Color(0xFF1D4ED8);

    final labelStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Colors.black87,
    );

    InputDecoration inputDecoration(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 16),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          filled: true,
          fillColor: lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: green, width: 2),
          ),
        );

    Widget roleCard({
      required String label,
      required IconData icon,
      required bool selected,
      required Color selectedBorder,
      required Color selectedBg,
      required Color unselectedBorder,
      required Color unselectedBg,
      required VoidCallback onTap,
    }) {
      final Color borderColor = selected ? selectedBorder : unselectedBorder;
      final Color bgColor = selected ? selectedBg : unselectedBg;
      final Color textColor = selected ? selectedBorder : Colors.black87;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with rounded bottom
              Stack(
                children: [
                  Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Login',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48), // balance for centered title
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'I am a:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        roleCard(
                          label: 'Farmer',
                          icon: Icons.agriculture,
                          selected: _role == Role.farmer,
                          selectedBorder: green,
                          selectedBg: Color(0xFFE9F8EF),
                          unselectedBorder: Colors.grey.shade300,
                          unselectedBg: Colors.white,
                          onTap: () => setState(() => _role = Role.farmer),
                        ),
                        const SizedBox(width: 12),
                        roleCard(
                          label: 'Buyer',
                          icon: Icons.shopping_cart,
                          selected: _role == Role.buyer,
                          selectedBorder: blue,
                          selectedBg: Color(0xFFEFF4FF),
                          unselectedBorder: Colors.grey.shade300,
                          unselectedBg: Colors.white,
                          onTap: () => setState(() => _role = Role.buyer),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text('Email / Mobile', style: labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(fontSize: 18),
                      decoration: inputDecoration(
                        'Enter your email or mobile number',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Password', style: labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 18),
                      decoration: inputDecoration('Enter your password'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 1.2,
                          child: Checkbox(
                            value: _rememberMe,
                            onChanged: (v) =>
                                setState(() => _rememberMe = v ?? false),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _rememberMe = !_rememberMe),
                          child: const Text(
                            'Remember me',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleLogin,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'New user? ',
                            style: TextStyle(fontSize: 14),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Register',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: green,
                              ),
                            ),
                          ),
                        ],
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
}

enum Role { farmer, buyer }

class FarmerProfileDetailsScreen extends StatefulWidget {
  const FarmerProfileDetailsScreen({super.key});

  @override
  State<FarmerProfileDetailsScreen> createState() =>
      _FarmerProfileDetailsScreenState();
}

class _FarmerProfileDetailsScreenState
    extends State<FarmerProfileDetailsScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  final _cropsController = TextEditingController();
  final _landAreaController = TextEditingController();
  File? _idProofImage;
  String? _idProofUrl;
  bool _uploadingIdProof = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _cropsController.dispose();
    _landAreaController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadIdProof() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);

      if (pickedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected')),
        );
        return;
      }

      setState(() => _uploadingIdProof = true);

      final imageFile = File(pickedFile.path);
      final url = await StorageService.uploadIdProof(imageFile);

      if (url != null) {
        setState(() {
          _idProofImage = imageFile;
          _idProofUrl = url;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('ID proof uploaded successfully!')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading ID proof: $e')),
        );
      }
    } finally {
      setState(() => _uploadingIdProof = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    const lightGrey = Color(0xFFF5F5F5);

    InputDecoration deco({required String hint, required IconData icon}) =>
        InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: Colors.black54),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          filled: true,
          fillColor: lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: green, width: 2),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Stack(
                children: [
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: BackButton(color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Farmer Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Complete your profile to start selling',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Farmer Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: deco(
                        hint: 'Enter your full name',
                        icon: Icons.person,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mobile Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: deco(
                        hint: 'Enter your mobile number',
                        icon: Icons.phone,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Farm Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: deco(
                        hint: 'Village / District',
                        icon: Icons.location_on,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Type of Crops Grown',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cropsController,
                      decoration: deco(
                        hint: 'e.g. Wheat, Rice, Sugarcane',
                        icon: Icons.spa,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Land Area (optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _landAreaController,
                      keyboardType: TextInputType.text,
                      decoration: deco(
                        hint: 'e.g. 2 acres (optional)',
                        icon: Icons.open_in_full,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE9F8EF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBEECD3)),
                        boxShadow: [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.description, color: Colors.black54),
                              SizedBox(width: 8),
                              Text(
                                'Upload ID Proof',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: lightGrey,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade300),
                            ),
                            child: _idProofImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      _idProofImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.image_not_supported,
                                          size: 48,
                                          color: Colors.grey.shade400,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No document selected',
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'For verification purpose',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 10),
                          OutlinedButton.icon(
                            onPressed: _uploadingIdProof
                                ? null
                                : _pickAndUploadIdProof,
                            icon: _uploadingIdProof
                                ? SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        green,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.upload),
                            label: Text(
                              _uploadingIdProof ? 'Uploading...' : 'Upload ID',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: green,
                              side: const BorderSide(color: green),
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          final mobile = _mobileController.text.trim();
                          final location = _locationController.text.trim();
                          final crops = _cropsController.text.trim();
                          final landArea = _landAreaController.text.trim();

                          if (name.isEmpty ||
                              mobile.isEmpty ||
                              location.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill name, mobile, and location',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            final profileData = {
                              'name': name,
                              'mobile': mobile,
                              'location': location,
                              'crops': crops,
                              'landArea': landArea,
                              'role': 'farmer',
                              'idProofUrl': _idProofUrl ?? '',
                              'idVerified': _idProofUrl != null,
                              'savedAt': ServerValue.timestamp,
                            };

                            await FirebaseService.writeData(
                              'farmers/${FirebaseAuth.instance.currentUser?.uid ?? "unknown"}',
                              profileData,
                            );

                            // Also save to Firestore for better integration
                            await FirebaseFirestore.instance
                                .collection('farmers')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .set(profileData, SetOptions(merge: true));

                            // Save role to users collection for login routing
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .set({
                              'role': 'farmer',
                              'profileCompleted': true,
                              'name': name,
                              'mobile': mobile,
                              'location': location,
                            }, SetOptions(merge: true));
                            print('✓ Farmer profile saved with role: farmer');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile saved successfully!'),
                                ),
                              );

                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const FarmerDashboardScreen(),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save profile: $e'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Save & Continue'),
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
}

// BuyerProfileDetailsScreen: collect buyer info
class BuyerProfileDetailsScreen extends StatefulWidget {
  const BuyerProfileDetailsScreen({super.key});

  @override
  State<BuyerProfileDetailsScreen> createState() =>
      _BuyerProfileDetailsScreenState();
}

class _BuyerProfileDetailsScreenState extends State<BuyerProfileDetailsScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  final _companyController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const blue = Color(0xFF1D4ED8);
    const lightGrey = Color(0xFFF5F5F5);

    InputDecoration deco({required String hint, required IconData icon}) =>
        InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: Colors.black54),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          filled: true,
          fillColor: lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: blue, width: 2),
          ),
        );

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Stack(
                children: [
                  Container(
                    height: 140,
                    decoration: const BoxDecoration(
                      color: blue,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: BackButton(color: Colors.white),
                          ),
                          SizedBox(height: 8),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Buyer Details',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          SizedBox(height: 6),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'Complete your profile to start ordering',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    const Text(
                      'Buyer Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: deco(
                        hint: 'Enter your full name',
                        icon: Icons.person,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Mobile Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: deco(
                        hint: 'Enter your mobile number',
                        icon: Icons.phone,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: deco(
                        hint: 'City / District',
                        icon: Icons.location_on,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Company/Organization (optional)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _companyController,
                      decoration: deco(
                        hint: 'Company name or "Retail Buyer"',
                        icon: Icons.business,
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          final mobile = _mobileController.text.trim();
                          final location = _locationController.text.trim();
                          final company = _companyController.text.trim();

                          if (name.isEmpty ||
                              mobile.isEmpty ||
                              location.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill name, mobile, and location',
                                ),
                              ),
                            );
                            return;
                          }

                          try {
                            await FirebaseService.writeData(
                              'buyers/${FirebaseAuth.instance.currentUser?.uid ?? "unknown"}',
                              {
                                'name': name,
                                'mobile': mobile,
                                'location': location,
                                'company': company,
                                'role': 'buyer',
                                'savedAt': ServerValue.timestamp,
                              },
                            );

                            // Also save to Firestore users collection for login routing
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(FirebaseAuth.instance.currentUser?.uid)
                                .set({
                              'role': 'buyer',
                              'profileCompleted': true,
                              'name': name,
                              'mobile': mobile,
                              'location': location,
                            }, SetOptions(merge: true));
                            print('✓ Buyer profile saved with role: buyer');

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Profile saved to Firebase!'),
                                ),
                              );

                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => const BuyerDashboardScreen(),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to save profile: $e'),
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blue,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: const Text('Save & Continue'),
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
}

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({super.key});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class PublicProfileScreen extends StatelessWidget {
  final String userId;
  final String? fallbackRole;

  const PublicProfileScreen({
    super.key,
    required this.userId,
    this.fallbackRole,
  });

  Future<Map<String, dynamic>> _loadProfile() async {
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();
    final userData = userDoc.data() ?? <String, dynamic>{};
    final role = (userData['role'] ?? fallbackRole ?? 'buyer')
        .toString()
        .toLowerCase();
    final profileCollection = role == 'farmer' ? 'farmers' : 'buyers';
    final profileDoc = await FirebaseFirestore.instance
        .collection(profileCollection)
        .doc(userId)
        .get();

    return {
      'role': role,
      ...userData,
      ...?profileDoc.data(),
    };
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);

    Widget infoTile({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0F2E9)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F8EF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(title: const Text('Profile')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadProfile(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final profileData = snapshot.data ?? <String, dynamic>{};
          final role = (profileData['role'] ?? fallbackRole ?? 'buyer')
              .toString()
              .toLowerCase();
          final isFarmer = role == 'farmer';

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: green,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white,
                        child: Icon(Icons.person, size: 34, color: green),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        (profileData['name'] ?? 'User').toString(),
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isFarmer ? 'Farmer Profile' : 'Buyer Profile',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (isFarmer) ...[
                  FarmerReviewSummaryCard(farmerId: userId),
                  const SizedBox(height: 12),
                ],
                infoTile(
                  icon: Icons.person_outline,
                  label: 'Full Name',
                  value: (profileData['name'] ?? '').toString(),
                ),
                infoTile(
                  icon: Icons.phone_outlined,
                  label: 'Mobile Number',
                  value: (profileData['mobile'] ?? '').toString(),
                ),
                infoTile(
                  icon: Icons.location_on_outlined,
                  label: 'Location',
                  value: (profileData['location'] ?? '').toString(),
                ),
                if ((profileData['email'] ?? '').toString().isNotEmpty)
                  infoTile(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: (profileData['email'] ?? '').toString(),
                  ),
                if (isFarmer) ...[
                  infoTile(
                    icon: Icons.grass_outlined,
                    label: 'Crops',
                    value: (profileData['crops'] ?? '').toString(),
                  ),
                  infoTile(
                    icon: Icons.landscape_outlined,
                    label: 'Land Area',
                    value: (profileData['landArea'] ?? '').toString(),
                  ),
                  infoTile(
                    icon: Icons.verified_user_outlined,
                    label: 'ID Verification',
                    value: profileData['idVerified'] == true
                        ? 'Verified'
                        : 'Not verified',
                  ),
                  FarmerFeedbackList(
                    farmerId: userId,
                    emptyLabel: 'No reviews yet.',
                  ),
                ] else
                  infoTile(
                    icon: Icons.business_outlined,
                    label: 'Company',
                    value: (profileData['company'] ?? '').toString(),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _locationController = TextEditingController();
  final _emailController = TextEditingController();
  final _cropsController = TextEditingController();
  final _landAreaController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isEditing = false;
  Map<String, dynamic> _profileData = {};
  String _role = 'buyer';
  String _email = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _locationController.dispose();
    _emailController.dispose();
    _cropsController.dispose();
    _landAreaController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        throw Exception('No user is currently signed in.');
      }

      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final role = (userData['role'] ?? 'buyer').toString().toLowerCase();
      final profileCollection = role == 'farmer' ? 'farmers' : 'buyers';

      final profileDoc = await FirebaseFirestore.instance
          .collection(profileCollection)
          .doc(uid)
          .get();
      final profileData = profileDoc.data() ?? <String, dynamic>{};

      final mergedData = {...userData, ...profileData};

      if (!mounted) return;

      setState(() {
        _role = role;
        _email = FirebaseAuth.instance.currentUser?.email ?? '';
        _profileData = mergedData;
        _nameController.text = (mergedData['name'] ?? '').toString();
        _mobileController.text = (mergedData['mobile'] ?? '').toString();
        _locationController.text = (mergedData['location'] ?? '').toString();
        _emailController.text = _email;
        _cropsController.text = (mergedData['crops'] ?? '').toString();
        _landAreaController.text = (mergedData['landArea'] ?? '').toString();
        _companyController.text = (mergedData['company'] ?? '').toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to load profile: $e')),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final name = _nameController.text.trim();
    final mobile = _mobileController.text.trim();
    final location = _locationController.text.trim();
    final crops = _cropsController.text.trim();
    final landArea = _landAreaController.text.trim();
    final company = _companyController.text.trim();

    if (name.isEmpty || mobile.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill name, mobile, and location'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final commonData = {
        'name': name,
        'mobile': mobile,
        'location': location,
        'role': _role,
        'profileCompleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(commonData, SetOptions(merge: true));

      if (_role == 'farmer') {
        final farmerData = {
          'name': name,
          'mobile': mobile,
          'location': location,
          'crops': crops,
          'landArea': landArea,
          'role': 'farmer',
          'savedAt': ServerValue.timestamp,
          'idProofUrl': (_profileData['idProofUrl'] ?? '').toString(),
          'idVerified': _profileData['idVerified'] == true,
        };

        await FirebaseService.writeData('farmers/$uid', farmerData);
        await FirebaseFirestore.instance
            .collection('farmers')
            .doc(uid)
            .set(farmerData, SetOptions(merge: true));

        _profileData = {
          ..._profileData,
          ...farmerData,
        };
      } else {
        final buyerData = {
          'name': name,
          'mobile': mobile,
          'location': location,
          'company': company,
          'role': 'buyer',
          'savedAt': ServerValue.timestamp,
        };

        await FirebaseService.writeData('buyers/$uid', buyerData);
        await FirebaseFirestore.instance
            .collection('buyers')
            .doc(uid)
            .set(buyerData, SetOptions(merge: true));

        _profileData = {
          ..._profileData,
          ...buyerData,
        };
      }

      _profileData = {
        ..._profileData,
        ...commonData,
      };

      if (!mounted) return;

      setState(() {
        _isEditing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _cancelEdit() {
    setState(() {
      _isEditing = false;
      _nameController.text = (_profileData['name'] ?? '').toString();
      _mobileController.text = (_profileData['mobile'] ?? '').toString();
      _locationController.text = (_profileData['location'] ?? '').toString();
      _cropsController.text = (_profileData['crops'] ?? '').toString();
      _landAreaController.text = (_profileData['landArea'] ?? '').toString();
      _companyController.text = (_profileData['company'] ?? '').toString();
    });
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    final isFarmer = _role == 'farmer';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    InputDecoration inputDecoration(String label, IconData icon) =>
        InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0F2E9)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFE0F2E9)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: green, width: 1.5),
          ),
        );

    Widget infoTile({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0F2E9)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFFE9F8EF),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.black54,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.isEmpty ? '-' : value,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Widget buildEditableFields() {
      return Column(
        children: [
          TextField(
            controller: _nameController,
            decoration: inputDecoration('Full Name', Icons.person_outline),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _mobileController,
            keyboardType: TextInputType.phone,
            decoration: inputDecoration('Mobile Number', Icons.phone_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: inputDecoration('Location', Icons.location_on_outlined),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            enabled: false,
            decoration: inputDecoration('Email', Icons.email_outlined),
          ),
          const SizedBox(height: 12),
          if (isFarmer) ...[
            TextField(
              controller: _cropsController,
              decoration: inputDecoration('Crops', Icons.grass_outlined),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _landAreaController,
              decoration:
                  inputDecoration('Land Area', Icons.landscape_outlined),
            ),
          ] else
            TextField(
              controller: _companyController,
              decoration: inputDecoration('Company', Icons.business_outlined),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save Changes'),
            ),
          ),
        ],
      );
    }

    Widget buildReadOnlyDetails() {
      return Column(
        children: [
          infoTile(
            icon: Icons.person_outline,
            label: 'Full Name',
            value: (_profileData['name'] ?? '').toString(),
          ),
          infoTile(
            icon: Icons.phone_outlined,
            label: 'Mobile Number',
            value: (_profileData['mobile'] ?? '').toString(),
          ),
          infoTile(
            icon: Icons.location_on_outlined,
            label: 'Location',
            value: (_profileData['location'] ?? '').toString(),
          ),
          if (_email.isNotEmpty)
            infoTile(
              icon: Icons.email_outlined,
              label: 'Email',
              value: _email,
            ),
          if (isFarmer) ...[
            infoTile(
              icon: Icons.grass_outlined,
              label: 'Crops',
              value: (_profileData['crops'] ?? '').toString(),
            ),
            infoTile(
              icon: Icons.landscape_outlined,
              label: 'Land Area',
              value: (_profileData['landArea'] ?? '').toString(),
            ),
            infoTile(
              icon: Icons.verified_user_outlined,
              label: 'ID Verification',
              value: _profileData['idVerified'] == true
                  ? 'Verified'
                  : 'Not verified',
            ),
          ] else
            infoTile(
              icon: Icons.business_outlined,
              label: 'Company',
              value: (_profileData['company'] ?? '').toString(),
            ),
        ],
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: green,
        foregroundColor: Colors.white,
        actions: [
          if (_isEditing)
            TextButton(
              onPressed: _isSaving ? null : _cancelEdit,
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white),
              ),
            )
          else
            IconButton(
              onPressed: _isLoading
                  ? null
                  : () {
                      setState(() => _isEditing = true);
                    },
              icon: const Icon(Icons.edit),
              tooltip: 'Edit Profile',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const CircleAvatar(
                          radius: 34,
                          backgroundColor: Colors.white,
                          child: Icon(Icons.person, size: 34, color: green),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          (_profileData['name'] ?? 'User').toString(),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isFarmer ? 'Farmer Profile' : 'Buyer Profile',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isEditing
                              ? 'Update your registration details and save them here'
                              : 'Your saved registration details',
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (isFarmer && currentUserId.isNotEmpty) ...[
                    FarmerReviewSummaryCard(farmerId: currentUserId),
                    const SizedBox(height: 12),
                    FarmerFeedbackList(farmerId: currentUserId, emptyLabel: 'No ratings yet.'),
                    const SizedBox(height: 20),
                  ],
                  _isEditing ? buildEditableFields() : buildReadOnlyDetails(),
                ],
              ),
            ),
    );
  }
}

class FarmerDashboardScreen extends StatefulWidget {
  const FarmerDashboardScreen({super.key});

  @override
  State<FarmerDashboardScreen> createState() => _FarmerDashboardScreenState();
}

class _FarmerDashboardScreenState extends State<FarmerDashboardScreen> {
  // Stream to get active crop count
  Stream<int> _getCropCountStream() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return Stream.value(0);

    return FirebaseFirestore.instance
        .collection('crops')
        .where('farmerId', isEqualTo: uid)
        .where('status', isEqualTo: 'Available')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Stream to get pending pre-order count
  Stream<int> _getPreOrderCountStream() {
    return FirebaseFirestore.instance
        .collection('pre_orders')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    const blue = Color(0xFF1D4ED8);

    Widget header() => Stack(
          children: [
            Container(
              height: 160,
              decoration: const BoxDecoration(
                color: green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Welcome Farmer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Manage your crops and orders',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

    Widget iconCircle({
      required List<Color> colors,
      required IconData icon,
      Color iconColor = green,
    }) {
      return Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.06),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor),
      );
    }

    Widget actionCard({
      required Widget leading,
      required String title,
      required String subtitle,
    }) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE0F2E9)),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      );
    }

    Widget statCard({
      required String label,
      required String value,
      required Color bg,
      required Color fg,
    }) {
      return Expanded(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  color: fg,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: fg.withAlpha((0.9 * 255).round()),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        child: Column(
          children: [
            header(),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyProfileScreen(),
                          ),
                        );
                      },
                      child: actionCard(
                        leading: iconCircle(
                          colors: const [Color(0xFFE6F3FF), Color(0xFFD7E9FF)],
                          icon: Icons.person,
                          iconColor: blue,
                        ),
                        title: 'My Profile',
                        subtitle: 'View and edit your saved details',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddCropScreen(),
                          ),
                        );
                      },
                      child: actionCard(
                        leading: iconCircle(
                          colors: const [Color(0xFFE9F8EF), Color(0xFFD1F1DE)],
                          icon: Icons.add,
                        ),
                        title: 'Add Crop',
                        subtitle: 'List a new product to sell',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MyCropsScreen(),
                          ),
                        );
                      },
                      child: actionCard(
                        leading: iconCircle(
                          colors: const [Color(0xFFFFF7CC), Color(0xFFFFF0A3)],
                          icon: Icons.grass,
                          iconColor: const Color(0xFF8B8000),
                        ),
                        title: 'My Crops',
                        subtitle: 'View and manage your listings',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const OrdersScreen(),
                          ),
                        );
                      },
                      child: actionCard(
                        leading: iconCircle(
                          colors: const [Color(0xFFE6F0FF), Color(0xFFCFE3FF)],
                          icon: Icons.inventory_2,
                          iconColor: blue,
                        ),
                        title: 'Orders',
                        subtitle: 'Check your order requests',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const FarmerPreOrdersScreen(),
                          ),
                        );
                      },
                      child: actionCard(
                        leading: iconCircle(
                          colors: const [Color(0xFFFFE6E6), Color(0xFFFFCCCC)],
                          icon: Icons.list_alt,
                          iconColor: const Color(0xFFDC2626),
                        ),
                        title: 'Pre-orders',
                        subtitle: 'View pre-order requests',
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const MessagesScreen(),
                          ),
                        );
                      },
                      child: actionCard(
                        leading: iconCircle(
                          colors: const [Color(0xFFE6F3FF), Color(0xFFCCE5FF)],
                          icon: Icons.message,
                          iconColor: const Color(0xFF1D4ED8),
                        ),
                        title: 'Messages',
                        subtitle: 'Chat with buyers',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Row(
                        children: [
                          // Active Crops Count
                          Expanded(
                            child: StreamBuilder<int>(
                              stream: _getCropCountStream(),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return statCard(
                                  label: 'Active Crops',
                                  value: count.toString(),
                                  bg: const Color(0xFFE9F8EF),
                                  fg: green,
                                );
                              },
                            ),
                          ),
                          // Pending Orders Count
                          Expanded(
                            child: StreamBuilder<int>(
                              stream: _getPreOrderCountStream(),
                              builder: (context, snapshot) {
                                final count = snapshot.data ?? 0;
                                return statCard(
                                  label: 'Pending Orders',
                                  value: count.toString(),
                                  bg: const Color(0xFFE6F0FF),
                                  fg: blue,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// AddCropScreen: accepts initial values and optional index to edit the shared cropsData or cropId for Firestore edit
class AddCropScreen extends StatefulWidget {
  final String? initialName;
  final String? initialQty;
  final String? initialPrice;
  final String? initialLocation;
  final int? index; // index in cropsData when editing (legacy)
  final String? cropId; // Firestore crop ID when editing

  const AddCropScreen({
    super.key,
    this.initialName,
    this.initialQty,
    this.initialPrice,
    this.initialLocation,
    this.index,
    this.cropId,
  });

  @override
  State<AddCropScreen> createState() => _AddCropScreenState();
}

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _formatDisplayDate(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split(' ').first;
    }
    if (value is DateTime) {
      return value.toLocal().toString().split(' ').first;
    }
    return value.toString();
  }

  Future<void> _updateOrderStatus({
    required String orderId,
    required String status,
    String? preOrderId,
  }) async {
    await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (preOrderId != null && preOrderId.isNotEmpty) {
      await FirebaseFirestore.instance
          .collection('pre_orders')
          .doc(preOrderId)
          .update({
            'status': status,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    }
  }

  Widget orderTile({
    required String title,
    required String subtitle,
    required String status,
    Widget? profileInfo,
    VoidCallback? onAccept,
    VoidCallback? onReject,
  }) {
    const green = Color(0xFF16A34A);
    final normalizedStatus = status.toLowerCase();
    final canRespond = normalizedStatus == 'ordered';
    final statusColor = normalizedStatus == 'accepted'
        ? Colors.blue
        : normalizedStatus == 'rejected'
            ? Colors.redAccent
            : green;
    final statusLabel = normalizedStatus.isEmpty
        ? 'Ordered'
        : normalizedStatus[0].toUpperCase() + normalizedStatus.substring(1);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54)),
          if (profileInfo != null) ...[
            const SizedBox(height: 12),
            profileInfo,
          ],
          const SizedBox(height: 12),
          if (canRespond)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onAccept,
                    child: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: green),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onReject,
                    child: Text('Reject', style: TextStyle(color: green)),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Orders')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
      backgroundColor: const Color(0xFFF8FAF8),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('farmerId', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = [...?snapshot.data?.docs]
            ..sort((a, b) {
              final aCreatedAt = a.data()['createdAt'];
              final bCreatedAt = b.data()['createdAt'];
              final aMillis = aCreatedAt is Timestamp
                  ? aCreatedAt.millisecondsSinceEpoch
                  : 0;
              final bMillis = bCreatedAt is Timestamp
                  ? bCreatedAt.millisecondsSinceEpoch
                  : 0;
              return bMillis.compareTo(aMillis);
            });
          if (orders.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }
          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 12),
                ...orders.map((doc) {
                  final data = doc.data();
                  final rawCropDetails = data['cropDetails'];
                  final cropDetails = rawCropDetails is Map
                      ? Map<String, dynamic>.from(rawCropDetails)
                      : <String, dynamic>{};
                  final cropName =
                      (cropDetails['cropName'] ?? data['cropName'] ?? 'Unknown crop')
                          .toString();
                  final orderedQty =
                      cropDetails['orderedQuantityKg'] ??
                      data['orderedQuantityKg'] ??
                      data['quantityKg'] ??
                      '-';
                  final location =
                      (cropDetails['location'] ?? data['location'] ?? '-')
                          .toString();
                  final price =
                      cropDetails['pricePerKg'] ??
                      data['pricePerKg'] ??
                      data['targetPrice'] ??
                      '-';
                  final buyerContact =
                      (data['buyerMobile'] ?? data['mobile'] ?? '-').toString();
                  final deliveryDate =
                      cropDetails['deliveryDate'] ??
                      data['deliveryDate'] ??
                      data['targetDate'];
                  final status = (data['status'] ?? 'ordered').toString();
                  final transportOption =
                      (cropDetails['transportOption'] ??
                              data['transportOption'] ??
                              'own_transport')
                          .toString();
                  final transportLabel = transportOption == 'need_transportation'
                      ? 'Need Transportation'
                      : 'Own Transport';
                  final deliveryLocation =
                      (cropDetails['deliveryLocation'] ??
                              data['deliveryLocation'] ??
                              '-')
                          .toString();
                  final transportCharges =
                      cropDetails['transportCharges'] ??
                      data['transportCharges'] ??
                      '-';
                  final buyerId =
                      (data['buyerId'] ?? data['uid'] ?? '').toString();

                  return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                    future: buyerId.isEmpty
                        ? null
                        : FirebaseFirestore.instance
                            .collection('buyers')
                            .doc(buyerId)
                            .get(),
                    builder: (context, buyerSnapshot) {
                      final buyerData = buyerSnapshot.data?.data();
                      final buyerName =
                          (buyerData?['name'] ?? 'Buyer').toString();
                      final buyerMobile =
                          (buyerData?['mobile'] ?? buyerContact).toString();

                      return orderTile(
                        title: '$cropName - $orderedQty kg',
                        subtitle:
                            'Location: $location\nPrice: $price\nDelivery: ${_formatDisplayDate(deliveryDate)}\nTransport: $transportLabel\nDelivery Location: $deliveryLocation\nCharges: $transportCharges',
                        profileInfo: buyerId.isEmpty
                            ? null
                            : Wrap(
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  InkWell(
                                    onTap: () => openPublicProfile(
                                      context,
                                      userId: buyerId,
                                      fallbackRole: 'buyer',
                                    ),
                                    child: Text(
                                      'Buyer Name: $buyerName',
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => openPublicProfile(
                                      context,
                                      userId: buyerId,
                                      fallbackRole: 'buyer',
                                    ),
                                    child: Text(
                                      'Buyer Mobile: $buyerMobile',
                                      style: const TextStyle(
                                        color: Color(0xFF1D4ED8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                        status: status,
                        onAccept: status.toLowerCase() == 'ordered'
                            ? () async {
                                await _updateOrderStatus(
                                  orderId: doc.id,
                                  status: 'accepted',
                                  preOrderId: data['preOrderId']?.toString(),
                                );
                                if (mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const OrderAcceptedScreen(),
                                    ),
                                  );
                                }
                              }
                            : null,
                        onReject: status.toLowerCase() == 'ordered'
                            ? () async {
                                await _updateOrderStatus(
                                  orderId: doc.id,
                                  status: 'rejected',
                                  preOrderId: data['preOrderId']?.toString(),
                                );
                                if (mounted) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => const OrderRejectedScreen(),
                                    ),
                                  );
                                }
                              }
                            : null,
                      );
                    },
                  );
                }),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}

class OrderAcceptedScreen extends StatelessWidget {
  const OrderAcceptedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F9EE),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.check_circle, size: 64, color: green),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Accepted!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The buyer has been notified about your acceptance.',
                style: TextStyle(fontSize: 16, color: Color(0xFF4B5563)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  border: Border.all(color: Color(0xFFDCFCE7)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '💚 Next Steps: The buyer will contact you shortly to arrange delivery and payment details.',
                  style: TextStyle(color: Color(0xFF065F46)),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Back to My Orders',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: green),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const FarmerDashboardScreen(),
                        ),
                        (route) => false,
                      ),
                      child: const Text(
                        'Go to Dashboard',
                        style: TextStyle(color: green),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderRejectedScreen extends StatelessWidget {
  const OrderRejectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 128,
                height: 128,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.cancel, size: 64, color: Color(0xFF4B5563)),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Order Rejected',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'The buyer has been notified about your decision.',
                style: TextStyle(fontSize: 16, color: Color(0xFF4B5563)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  border: Border.all(color: Color(0xFFF3F4F6)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ℹ️ Note: This order has been declined and removed from your pending orders list.',
                  style: TextStyle(color: Color(0xFF374151)),
                ),
              ),
              const SizedBox(height: 20),
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text(
                        'Back to My Orders',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: green),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst),
                      child: const Text(
                        'Go to Dashboard',
                        style: TextStyle(color: green),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddCropScreenState extends State<AddCropScreen> {
  final _nameController = TextEditingController();
  final _qtyController = TextEditingController();
  final _priceController = TextEditingController();
  final _locationController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _imageConfirmed = false;

  @override
  void initState() {
    super.initState();
    // Prefill controllers if initial values provided (edit mode)
    if (widget.initialName != null) _nameController.text = widget.initialName!;
    if (widget.initialQty != null) _qtyController.text = widget.initialQty!;
    if (widget.initialPrice != null) {
      _priceController.text = widget.initialPrice!;
    }
    if (widget.initialLocation != null) {
      _locationController.text = widget.initialLocation!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _qtyController.dispose();
    _priceController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _showImageSourceOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from gallery'),
              subtitle: const Text('Select an existing photo from your device'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take a photo'),
              subtitle: const Text('Open the camera to capture a new photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) return;
      setState(() {
        _selectedImage = File(picked.path);
        _imageConfirmed = true; // Auto-confirm image when selected
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    const lightGrey = Color(0xFFF5F5F5);

    InputDecoration deco({required String hint, required IconData icon}) =>
        InputDecoration(
          labelText: hint,
          prefixIcon: Icon(icon, color: Colors.black54),
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          filled: true,
          fillColor: lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: green, width: 2),
          ),
        );

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Stack(
                children: [
                  Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              widget.initialName == null
                                  ? 'Add Crop'
                                  : 'Edit Crop',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      '🌱 Crop Name',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: deco(
                        hint: 'e.g. Fresh Organic Tomatoes',
                        icon: Icons.eco,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      '📦 Quantity (kg)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: deco(hint: 'e.g. 50', icon: Icons.scale),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      '💰 Price per kg',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: deco(
                        hint: 'e.g. 30',
                        icon: Icons.currency_rupee,
                      ),
                    ),

                    const SizedBox(height: 16),
                    const Text(
                      '📍 Location',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _locationController,
                      decoration: deco(
                        hint: 'e.g. Village Name, District',
                        icon: Icons.place,
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Image preview / picker area
                    Container(
                      width: double.infinity,
                      height: 160,
                      decoration: BoxDecoration(
                        color: lightGrey,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade300),
                        boxShadow: [
                          const BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.04),
                            blurRadius: 8,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: _selectedImage == null
                          ? const Center(
                              child: Text(
                                'No image selected',
                                style: TextStyle(color: Colors.black45),
                              ),
                            )
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _selectedImage!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _showImageSourceOptions(context),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Choose image'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          foregroundColor: Colors.black87,
                        ),
                      ),
                    ),

                    // Image is now optional - no confirmation needed
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final name = _nameController.text.trim();
                          final qty = _qtyController.text.trim();
                          final price = _priceController.text.trim();
                          final location = _locationController.text.trim();

                          if (name.isEmpty || qty.isEmpty || price.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Please fill name, qty and price',
                                ),
                              ),
                            );
                            return;
                          }

                          if (widget.index == null) {
                            try {
                              await CropService.addCrop(
                                title: name,
                                status: 'Available',
                                quantity: qty,
                                price: price,
                                location: location.isEmpty ? '-' : location,
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Crop submitted!')),
                                );

                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const FarmerDashboardScreen(),
                                  ),
                                  (route) => route.isFirst,
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to save crop: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                            return;
                          }

                          // Edit mode: delete old crop and add new one
                          if (widget.cropId != null) {
                            try {
                              // Delete the old crop first
                              await CropService.deleteCrop(widget.cropId!);

                              // Add the updated crop as a new entry
                              await CropService.addCrop(
                                title: name,
                                status: 'Available',
                                quantity: qty,
                                price: price,
                                location: location.isEmpty ? '-' : location,
                              );

                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content:
                                          Text('Crop updated successfully!')),
                                );
                                Navigator.of(context).pop();
                                Navigator.of(context).pop();
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update crop: $e',
                                    ),
                                  ),
                                );
                              }
                            }
                            return;
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(
                          widget.index == null ? 'Submit' : 'Save Changes',
                        ),
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
}

class MyCropsScreen extends StatefulWidget {
  const MyCropsScreen({super.key});

  @override
  State<MyCropsScreen> createState() => _MyCropsScreenState();
}

class _MyCropsScreenState extends State<MyCropsScreen> {
  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    const soldGrey = Color(0xFF9E9E9E);

    Widget header() => Stack(
          children: [
            Container(
              height: 140,
              decoration: const BoxDecoration(
                color: green,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: BackButton(color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'My Crops',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(height: 6),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'Manage inventory and view details',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );

    Widget statusChip(String status) {
      final bool available = status.toLowerCase() == 'available';
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: available ? const Color(0xFFE9F8EF) : const Color(0xFFEDEDED),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                available ? const Color(0xFFBEECD3) : const Color(0xFFDADADA),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              available ? Icons.check_circle : Icons.remove_circle,
              size: 16,
              color: available ? green : soldGrey,
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: available ? green : soldGrey,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    Widget cropCard(Map<String, dynamic> crop, int index) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: const Color.fromRGBO(0, 0, 0, 0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    crop['title'] ?? '',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                statusChip(crop['status'] ?? 'Available'),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Qty: ${crop['quantity'] ?? '0'} kg'),
                      Text('Price: ₹ ${crop['price'] ?? '-'}/kg'),
                      Text('Location: ${crop['location'] ?? '-'}'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () async {
                    final farmerId = (crop['farmerId'] ?? '').toString();
                    String farmerMobile = '-';
                    if (farmerId.isNotEmpty) {
                      final farmerDoc = await FirebaseFirestore.instance
                          .collection('farmers')
                          .doc(farmerId)
                          .get();
                      farmerMobile =
                          (farmerDoc.data()?['mobile'] ?? '-').toString();
                    }
                    if (!mounted) return;
                    Navigator.of(context)
                        .push(
                          MaterialPageRoute(
                            builder: (_) => ViewCropDetailsScreen(
                              name: crop['title'] ?? '-',
                              status: crop['status'] ?? 'Available',
                              qtyKg: '${crop['quantity'] ?? '0'} kg',
                              pricePerKg: '₹ ${crop['price'] ?? '-'} / kg',
                              location: crop['location'] ?? '-',
                              mobile: farmerMobile,
                              farmerId: farmerId,
                              cropId: crop['id'],
                              isBuyer: false,
                            ),
                          ),
                        )
                        .then((_) => setState(() {}));
                  },
                  icon: const Icon(Icons.remove_red_eye, size: 18),
                  label: const Text('View Details'),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF8),
      body: SafeArea(
        child: Column(
          children: [
            header(),
            const SizedBox(height: 12),
            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: CropService.getFarmerCrops(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Text(
                          'Error: ${snapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  }

                  final crops = snapshot.data ?? [];
                  if (crops.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.agriculture,
                                size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            const Text(
                              'No crops added yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Add your first crop to get started',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(top: 12, bottom: 24),
                    itemCount: crops.length + 1,
                    itemBuilder: (context, index) {
                      if (index == crops.length) return tipBanner();
                      final crop = crops[index];
                      return cropCard(crop, index);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget tipBanner() => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7CC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: const [
            Icon(Icons.info_outline, color: Color(0xFF8B8000)),
            SizedBox(width: 8),
            Expanded(
                child: Text('Tip: Tap a crop to view details and edit them.')),
          ],
        ),
      );
}

// Buyer dashboard (new)
class BuyerDashboardScreen extends StatefulWidget {
  const BuyerDashboardScreen({super.key});

  @override
  State<BuyerDashboardScreen> createState() => _BuyerDashboardScreenState();
}

class _BuyerDashboardScreenState extends State<BuyerDashboardScreen> {
  final TextEditingController _detailedCropController = TextEditingController();
  final TextEditingController _detailedQuantityController =
      TextEditingController();
  final TextEditingController _detailedBudgetController =
      TextEditingController();
  String? _selectedFarmer;

  String _searchTerm = '';
  final Set<String> _activeFilters = {};
  List<Map<String, dynamic>> _farmers = [];
  bool _isBottomSheetOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchFarmers();
  }

  Future<void> _fetchFarmers() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('farmers').get();
    setState(() {
      _farmers =
          snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  // Stream to get all available crops with real-time updates
  Stream<List<Map<String, dynamic>>> _getAvailableCrops() {
    return FirebaseFirestore.instance
        .collection('crops')
        .where('status', isEqualTo: 'Available')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }

  List<Map<String, String>> _filteredCrops() {
    // This method is deprecated - crops are now filtered in StreamBuilder
    return [];
  }

  Widget _filterChip(String label) {
    final selected = _activeFilters.contains(label);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) {
        setState(() {
          if (value) {
            _activeFilters.add(label);
          } else {
            _activeFilters.remove(label);
          }
        });
      },
      selectedColor: const Color(0xFF16A34A),
      checkmarkColor: Colors.white,
      backgroundColor: const Color(0xFFE8F5E9),
      labelStyle: TextStyle(color: selected ? Colors.white : Colors.black87),
    );
  }

  Future<void> _showDetailedPreorderRequestSheet() async {
    _selectedFarmer = null;
    _detailedCropController.clear();
    _detailedQuantityController.clear();
    _detailedBudgetController.clear();

    setState(() => _isBottomSheetOpen = true);
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 16,
              right: 16,
              top: 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Preorder Request',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _detailedCropController,
                    decoration: const InputDecoration(labelText: 'Crop Name'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedFarmer,
                    decoration: const InputDecoration(
                      labelText: 'Select Farmer (Optional)',
                    ),
                    items: _farmers.map((farmer) {
                      return DropdownMenuItem<String>(
                        value: farmer['id'],
                        child: Text(farmer['name'] ?? 'Unknown Farmer'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedFarmer = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _detailedQuantityController,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Quantity (KG)'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _detailedBudgetController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Budget (per KG)',
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final crop = _detailedCropController.text.trim();
                      final quantity = double.tryParse(
                        _detailedQuantityController.text.trim(),
                      );
                      final budget = double.tryParse(
                        _detailedBudgetController.text.trim(),
                      );

                      if (crop.isEmpty || quantity == null || budget == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                                'Please complete all fields with valid values'),
                          ),
                        );
                        return;
                      }

                      final uid =
                          FirebaseAuth.instance.currentUser?.uid ?? 'unknown';

                      try {
                        final preorderData = {
                          'cropName': crop,
                          'selectedFarmer': _selectedFarmer,
                          'quantityKg': quantity,
                          'targetPrice': budget,
                          'status': 'pending',
                          'visibleToAllFarmers': true,
                          'uid': uid,
                          'createdAt': FieldValue.serverTimestamp(),
                        };

                        await FirebaseFirestore.instance
                            .collection('pre_orders')
                            .add(preorderData);

                        // Also save to Realtime Database
                        await FirebaseService.pushData(
                          'pre_orders',
                          {
                            'cropName': crop,
                            'selectedFarmer': _selectedFarmer,
                            'quantityKg': quantity,
                            'targetPrice': budget,
                            'status': 'pending',
                            'visibleToAllFarmers': true,
                            'uid': uid,
                            'createdAt': ServerValue.timestamp,
                          },
                        );

                        if (mounted) {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Preorder request posted'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to post request: $e')),
                          );
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF16A34A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Submit Request'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      setState(() => _isBottomSheetOpen = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    return Scaffold(
      appBar: AppBar(title: const Text('Buyer Dashboard')),
      body: SafeArea(
        child: Column(
          children: [
            // Top option row
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Marketplace',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _showDetailedPreorderRequestSheet,
                          icon: const Icon(Icons.add_circle),
                          label: const Text('Preorder'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MyProfileScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person),
                          label: const Text('My Profile'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const BuyerOrdersScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.shopping_bag),
                          label: const Text('My Orders'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MyPreOrdersScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.list),
                          label: const Text('My Pre-orders'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MessagesScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.message),
                          label: const Text('Messages'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search crops...',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchTerm = value.trim().toLowerCase();
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [_filterChip('Price'), _filterChip('Location')],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: _getAvailableCrops(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }

                  var crops = snapshot.data ?? [];

                  // Apply filters
                  var filtered = crops.where((crop) {
                    final title =
                        (crop['title'] ?? '').toString().toLowerCase();
                    return _searchTerm.isEmpty || title.contains(_searchTerm);
                  }).toList();

                  if (_activeFilters.contains('Price')) {
                    filtered.sort((a, b) {
                      final pa =
                          int.tryParse((a['price'] ?? '0').toString()) ?? 0;
                      final pb =
                          int.tryParse((b['price'] ?? '0').toString()) ?? 0;
                      return pa.compareTo(pb);
                    });
                  }

                  if (_activeFilters.contains('Location')) {
                    filtered.sort((a, b) {
                      final la = (a['location'] ?? '').toString();
                      final lb = (b['location'] ?? '').toString();
                      return la.compareTo(lb);
                    });
                  }

                  if (filtered.isEmpty) {
                    return const Center(child: Text('No crops available'));
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final crop = filtered[index];
                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8FDF1),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child:
                                  Icon(Icons.grass, color: Color(0xFF16A34A)),
                            ),
                          ),
                          title: Text(crop['title'] ?? ''),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Farmer ${crop['location'] ?? '-'}'),
                              Text(
                                '${crop['quantity'] ?? '0'} kg • ₹${crop['price']}/kg',
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final farmerId =
                                      (crop['farmerId'] ?? '').toString();
                                  String farmerMobile = '-';
                                  if (farmerId.isNotEmpty) {
                                    final farmerDoc = await FirebaseFirestore
                                        .instance
                                        .collection('farmers')
                                        .doc(farmerId)
                                        .get();
                                    farmerMobile =
                                        (farmerDoc.data()?['mobile'] ?? '-')
                                            .toString();
                                  }
                                  if (!mounted) return;
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) => ViewCropDetailsScreen(
                                            name: crop['title'] ?? '-',
                                            status:
                                                crop['status'] ?? 'Available',
                                            qtyKg:
                                                '${crop['quantity'] ?? '0'} kg',
                                            pricePerKg:
                                                '₹ ${crop['price'] ?? '-'} / kg',
                                            location: crop['location'] ?? '-',
                                            mobile: farmerMobile,
                                            farmerId: farmerId,
                                            cropId: crop['id'],
                                            isBuyer: true,
                                          ),
                                        ),
                                      )
                                      .then((_) => setState(() {}));
                                },
                                icon: const Icon(Icons.remove_red_eye),
                                label: const Text('View Details'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 4),
                                  textStyle: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ConfirmOrderScreen extends StatefulWidget {
  final String cropName;
  final String pricePerKg;
  final String location;
  final String farmerMobile;
  final String farmerId;
  final String? cropId;
  final String availableQuantityKg;

  const ConfirmOrderScreen({
    super.key,
    required this.cropName,
    required this.pricePerKg,
    required this.location,
    required this.farmerMobile,
    required this.farmerId,
    this.cropId,
    required this.availableQuantityKg,
  });

  @override
  State<ConfirmOrderScreen> createState() => _ConfirmOrderScreenState();
}

class _ConfirmOrderScreenState extends State<ConfirmOrderScreen> {
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _deliveryLocationController =
      TextEditingController();
  final TextEditingController _transportChargesController =
      TextEditingController();
  String _transportOption = 'own_transport';
  DateTime? _deliveryDate;

  @override
  void dispose() {
    _quantityController.dispose();
    _deliveryLocationController.dispose();
    _transportChargesController.dispose();
    super.dispose();
  }

  double get _pricePerKg {
    return double.tryParse(
            widget.pricePerKg.replaceAll(RegExp(r'[^0-9.]'), '')) ??
        0.0;
  }

  Future<void> _submitOrder() async {
    final qty = int.tryParse(_quantityController.text.trim());
    final deliveryLocation = _deliveryLocationController.text.trim();
    final transportCharges =
        double.tryParse(_transportChargesController.text.trim()) ?? 0.0;
    if (qty == null || qty <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid quantity')),
      );
      return;
    }
    if (deliveryLocation.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a delivery location')),
      );
      return;
    }
    if (transportCharges < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transport charges cannot be negative')),
      );
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
    final deliveryDate =
        _deliveryDate ?? DateTime.now().add(const Duration(days: 7));
    final orderRef = FirebaseFirestore.instance.collection('orders').doc();
    final preOrderRef =
        FirebaseFirestore.instance.collection('pre_orders').doc();
    final orderData = {
      'buyerId': uid,
      'cropName': widget.cropName,
      'cropId': widget.cropId,
      'farmerId': widget.farmerId,
      'location': widget.location,
      'quantityKg': qty,
      'orderedQuantityKg': qty,
      'availableQuantityKg': widget.availableQuantityKg,
      'targetPrice': _pricePerKg,
      'pricePerKg': _pricePerKg,
      'farmerMobile': widget.farmerMobile,
      'transportOption': _transportOption,
      'deliveryLocation': deliveryLocation,
      'transportCharges': transportCharges,
      'targetDate': deliveryDate,
      'deliveryDate': deliveryDate,
      'status': 'ordered',
      'orderSource': 'marketplace',
      'orderId': orderRef.id,
      'preOrderId': preOrderRef.id,
      'cropDetails': {
        'cropName': widget.cropName,
        'cropId': widget.cropId,
        'farmerId': widget.farmerId,
        'location': widget.location,
        'farmerMobile': widget.farmerMobile,
        'pricePerKg': _pricePerKg,
        'transportOption': _transportOption,
        'deliveryLocation': deliveryLocation,
        'transportCharges': transportCharges,
        'availableQuantityKg': widget.availableQuantityKg,
        'orderedQuantityKg': qty,
        'deliveryDate': deliveryDate,
      },
      'uid': uid,
      'createdAt': FieldValue.serverTimestamp(),
    };

    // Save the marketplace order so it appears in buyer My Orders and My Pre-orders.
    await orderRef.set(orderData);
    await preOrderRef.set(orderData);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => BuyerOrdersScreen(initialOrder: orderData),
      ),
      (route) => route.isFirst,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order confirmed and updated in My Orders')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Confirm Order')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Crop: ${widget.cropName}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Farmer location: ${widget.location}'),
              const SizedBox(height: 8),
              Text('Price: ₹${_pricePerKg.toStringAsFixed(2)} / kg'),
              const SizedBox(height: 8),
              Text('Farmer mobile: ${widget.farmerMobile}'),
              const SizedBox(height: 16),
              TextField(
                controller: _quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity (KG)'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: _transportOption,
                decoration:
                    const InputDecoration(labelText: 'Transportation Option'),
                items: const [
                  DropdownMenuItem(
                    value: 'own_transport',
                    child: Text('Own Transport'),
                  ),
                  DropdownMenuItem(
                    value: 'need_transportation',
                    child: Text('Need Transportation'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _transportOption = value);
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _deliveryLocationController,
                decoration:
                    const InputDecoration(labelText: 'Delivery Location'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _transportChargesController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: 'Transport Charges'),
              ),
              const SizedBox(height: 10),
              TextField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Delivery Date',
                  hintText: _deliveryDate != null
                      ? '${_deliveryDate!.toLocal()}'.split(' ')[0]
                      : 'Select date',
                  suffixIcon: const Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) {
                    setState(() => _deliveryDate = picked);
                  }
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text('Confirm Order'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MyPreOrdersScreen extends StatelessWidget {
  const MyPreOrdersScreen({super.key});

  String _formatDisplayDate(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split(' ').first;
    }
    if (value is DateTime) {
      return value.toLocal().toString().split(' ').first;
    }
    return value.toString();
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Pending';
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'ordered':
        return const Color(0xFF16A34A);
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.redAccent;
      case 'expired':
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Pre-orders')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Pre-orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('pre_orders')
            .where('uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = [...?snapshot.data?.docs];
          orders.sort((a, b) {
            final aCreatedAt = a.data()['createdAt'];
            final bCreatedAt = b.data()['createdAt'];
            final aMillis = aCreatedAt is Timestamp
                ? aCreatedAt.millisecondsSinceEpoch
                : 0;
            final bMillis = bCreatedAt is Timestamp
                ? bCreatedAt.millisecondsSinceEpoch
                : 0;
            return bMillis.compareTo(aMillis);
          });
          if (orders.isEmpty) {
            return const Center(child: Text('No pre-orders found.'));
          }
          return ListView.builder(
            itemCount: orders.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = orders[index].data();
              final rawCropDetails = data['cropDetails'];
              final cropDetails = rawCropDetails is Map
                  ? Map<String, dynamic>.from(rawCropDetails)
                  : <String, dynamic>{};
              final cropName = (cropDetails['cropName'] ?? data['cropName'] ?? '')
                  .toString();
              final orderedQty =
                  cropDetails['orderedQuantityKg'] ??
                  data['orderedQuantityKg'] ??
                  data['quantityKg'] ??
                  '-';
              final availableQty =
                  cropDetails['availableQuantityKg'] ?? data['availableQuantityKg'];
              final price =
                  cropDetails['pricePerKg'] ??
                  data['pricePerKg'] ??
                  data['targetPrice'] ??
                  '-';
              final location =
                  (cropDetails['location'] ?? data['location'] ?? '-').toString();
              final farmerMobile =
                  (cropDetails['farmerMobile'] ?? data['farmerMobile'] ?? '-')
                      .toString();
              final farmerId = (data['farmerId'] ??
                      cropDetails['farmerId'] ??
                      '')
                  .toString();
              final deliveryDate =
                  cropDetails['deliveryDate'] ??
                  data['deliveryDate'] ??
                  data['targetDate'];
              final status = (data['status'] ?? 'pending').toString();
              final transportOption =
                  (cropDetails['transportOption'] ??
                          data['transportOption'] ??
                          'own_transport')
                      .toString();
              final transportLabel = transportOption == 'need_transportation'
                  ? 'Need Transportation'
                  : 'Own Transport';
              final dropLocation =
                  (cropDetails['deliveryLocation'] ??
                          data['deliveryLocation'] ??
                          '-')
                      .toString();
              final transportCharges =
                  cropDetails['transportCharges'] ??
                  data['transportCharges'] ??
                  '-';

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: farmerId.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                        .collection('farmers')
                        .doc(farmerId)
                        .get(),
                builder: (context, farmerSnapshot) {
                  final farmerData = farmerSnapshot.data?.data();
                  final farmerName =
                      (farmerData?['name'] ?? 'Farmer').toString();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(cropName.isEmpty ? 'Unknown crop' : cropName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ordered Qty: $orderedQty kg\n'
                            'Available Crop Qty: ${availableQty ?? '-'}\n'
                            'Location: $location\n'
                            'Delivery: ${_formatDisplayDate(deliveryDate)}\n'
                            'Price: $price\n'
                            'Transport: $transportLabel\n'
                            'Delivery Location: $dropLocation\n'
                            'Charges: $transportCharges',
                          ),
                          if (farmerId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => openPublicProfile(
                                context,
                                userId: farmerId,
                                fallbackRole: 'farmer',
                              ),
                              child: Text(
                                'Farmer Name: $farmerName',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => openPublicProfile(
                                context,
                                userId: farmerId,
                                fallbackRole: 'farmer',
                              ),
                              child: Text(
                                'Farmer Contact: $farmerMobile',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: false,
                      trailing: Text(
                        _formatStatus(status),
                        style: TextStyle(color: _statusColor(status)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class BuyerOrdersScreen extends StatelessWidget {
  final Map<String, dynamic>? initialOrder;

  const BuyerOrdersScreen({super.key, this.initialOrder});

  String _formatDisplayDate(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split(' ').first;
    }
    if (value is DateTime) {
      return value.toLocal().toString().split(' ').first;
    }
    return value.toString();
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Ordered';
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.redAccent;
      default:
        return const Color(0xFF16A34A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Orders')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('uid', isEqualTo: uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = [...?snapshot.data?.docs]..sort((a, b) {
              final aCreatedAt = a.data()['createdAt'];
              final bCreatedAt = b.data()['createdAt'];
              final aMillis = aCreatedAt is Timestamp
                  ? aCreatedAt.millisecondsSinceEpoch
                  : 0;
              final bMillis = bCreatedAt is Timestamp
                  ? bCreatedAt.millisecondsSinceEpoch
                  : 0;
              return bMillis.compareTo(aMillis);
            });
          final hasInitialOrder = initialOrder != null;
          if (orders.isEmpty && !hasInitialOrder) {
            return const Center(child: Text('No orders found.'));
          }

          final displayOrders = <Map<String, dynamic>>[
            if (hasInitialOrder) initialOrder!,
            ...orders.map((doc) => doc.data()),
          ];

          return ListView.builder(
            itemCount: displayOrders.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final data = displayOrders[index];
              final rawCropDetails = data['cropDetails'];
              final cropDetails = rawCropDetails is Map
                  ? Map<String, dynamic>.from(rawCropDetails)
                  : <String, dynamic>{};
              final cropName =
                  (cropDetails['cropName'] ?? data['cropName'] ?? 'Unknown crop')
                      .toString();
              final orderedQty =
                  cropDetails['orderedQuantityKg'] ??
                  data['orderedQuantityKg'] ??
                  data['quantityKg'] ??
                  '-';
              final location =
                  (cropDetails['location'] ?? data['location'] ?? '-').toString();
              final farmerMobile =
                  (cropDetails['farmerMobile'] ?? data['farmerMobile'] ?? '-')
                      .toString();
              final farmerId = (data['farmerId'] ??
                      cropDetails['farmerId'] ??
                      '')
                  .toString();
              final deliveryDate =
                  cropDetails['deliveryDate'] ??
                  data['deliveryDate'] ??
                  data['targetDate'];
              final availableQty =
                  cropDetails['availableQuantityKg'] ?? data['availableQuantityKg'];
              final price =
                  cropDetails['pricePerKg'] ??
                  data['pricePerKg'] ??
                  data['targetPrice'] ??
                  '-';
              final status = (data['status'] ?? 'ordered').toString();
              final transportOption =
                  (cropDetails['transportOption'] ??
                          data['transportOption'] ??
                          'own_transport')
                      .toString();
              final transportLabel = transportOption == 'need_transportation'
                  ? 'Need Transportation'
                  : 'Own Transport';
              final dropLocation =
                  (cropDetails['deliveryLocation'] ??
                          data['deliveryLocation'] ??
                          '-')
                      .toString();
              final transportCharges =
                  cropDetails['transportCharges'] ??
                  data['transportCharges'] ??
                  '-';

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: farmerId.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                        .collection('farmers')
                        .doc(farmerId)
                        .get(),
                builder: (context, farmerSnapshot) {
                  final farmerData = farmerSnapshot.data?.data();
                  final farmerName =
                      (farmerData?['name'] ?? 'Farmer').toString();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      title: Text(cropName),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ordered Qty: $orderedQty kg\n'
                            'Available Crop Qty: ${availableQty ?? '-'}\n'
                            'Location: $location\n'
                            'Delivery: ${_formatDisplayDate(deliveryDate)}\n'
                            'Price: $price\n'
                            'Transport: $transportLabel\n'
                            'Delivery Location: $dropLocation\n'
                            'Charges: $transportCharges',
                          ),
                          if (farmerId.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () => openPublicProfile(
                                context,
                                userId: farmerId,
                                fallbackRole: 'farmer',
                              ),
                              child: Text(
                                'Farmer Name: $farmerName',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => openPublicProfile(
                                context,
                                userId: farmerId,
                                fallbackRole: 'farmer',
                              ),
                              child: Text(
                                'Farmer Contact: $farmerMobile',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      isThreeLine: false,
                      trailing: Text(
                        _formatStatus(status),
                        style: TextStyle(color: _statusColor(status)),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class CropDetailsScreen extends StatelessWidget {
  final String cropName;
  final int quantityKg;
  final String location;
  final int pricePerKg;
  final String farmerName;

  const CropDetailsScreen({
    super.key,
    required this.cropName,
    required this.quantityKg,
    required this.location,
    required this.pricePerKg,
    required this.farmerName,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(cropName)),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 12),
            Text('Quantity: $quantityKg kg'),
            Text('Price: ₹ $pricePerKg / kg'),
            Text('Location: $location'),
            const SizedBox(height: 12),
            detailItem('👤', 'Farmer Name', farmerName),
          ],
        ),
      ),
    );
  }

  Widget detailItem(String icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Text(icon),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(value),
            ],
          ),
        ],
      ),
    );
  }
}

class ViewCropDetailsScreen extends StatelessWidget {
  final String name;
  final String status;
  final String qtyKg;
  final String pricePerKg;
  final String location;
  final String mobile;
  final String farmerId;
  final int?
      index; // index into cropsData so edit can update correct item (legacy)
  final String? cropId; // Firestore crop ID
  final bool isBuyer;

  const ViewCropDetailsScreen({
    super.key,
    required this.name,
    required this.status,
    required this.qtyKg,
    required this.pricePerKg,
    required this.location,
    required this.mobile,
    required this.farmerId,
    this.index,
    this.cropId,
    this.isBuyer = false,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);

    Widget sectionTitle(String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(t, style: const TextStyle(fontWeight: FontWeight.w900)),
        );

    Widget infoTile(
      IconData ic,
      String title,
      String value, {
      VoidCallback? onTap,
    }) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  Icon(ic, color: Colors.black54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          value,
                          style: TextStyle(
                            color: onTap == null
                                ? Colors.black87
                                : const Color(0xFF1D4ED8),
                            decoration: onTap == null
                                ? TextDecoration.none
                                : TextDecoration.underline,
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

    return Scaffold(
      appBar: AppBar(title: Text(name)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              sectionTitle('Crop Information'),
              infoTile(
                Icons.spa,
                'Name',
                name,
                onTap: isBuyer
                    ? () => openPublicProfile(
                          context,
                          userId: farmerId,
                          fallbackRole: 'farmer',
                        )
                    : null,
              ),
              infoTile(Icons.scale, 'Quantity', qtyKg),
              infoTile(Icons.currency_rupee, 'Price', pricePerKg),
              infoTile(Icons.location_on, 'Location', location),
              const SizedBox(height: 12),
              sectionTitle('Farmer Contact'),
              infoTile(
                Icons.phone,
                'Farmer Mobile',
                mobile,
                onTap: isBuyer
                    ? () => openPublicProfile(
                          context,
                          userId: farmerId,
                          fallbackRole: 'farmer',
                        )
                    : null,
              ),
              const SizedBox(height: 12),
              sectionTitle('Farmer Rating'),
              FarmerReviewSummaryCard(farmerId: farmerId),
              const SizedBox(height: 12),
              FarmerFeedbackList(
                farmerId: farmerId,
                limit: 3,
                emptyLabel: 'No feedback yet for this farmer.',
              ),
              const SizedBox(height: 18),
              if (isBuyer)
                Column(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet<void>(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(20)),
                          ),
                          builder: (_) => FarmerRatingSheet(
                            farmerId: farmerId,
                            farmerName: name,
                          ),
                        );
                      },
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Rate Farmer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: green,
                        side: const BorderSide(color: green),
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ConfirmOrderScreen(
                              cropName: name,
                              pricePerKg: pricePerKg,
                              location: location,
                              farmerMobile: mobile,
                              farmerId: farmerId,
                              cropId: cropId,
                              availableQuantityKg: qtyKg,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Confirm Order'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: green,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                      ),
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Navigate to AddCropScreen in edit mode with values parsed
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AddCropScreen(
                                initialName: name,
                                initialQty: qtyKg.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                ),
                                initialPrice: pricePerKg.replaceAll(
                                  RegExp(r'[^0-9.]'),
                                  '',
                                ),
                                initialLocation: location,
                                cropId: cropId,
                                index: index,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Crop'),
                        style: ElevatedButton.styleFrom(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Crop'),
                              content: const Text(
                                'Are you sure you want to delete this crop? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(ctx).pop();
                                    try {
                                      if (cropId != null) {
                                        // Delete from Firestore
                                        await CropService.deleteCrop(cropId!);
                                      }
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text('Crop deleted'),
                                        ),
                                      );
                                      Navigator.of(
                                        context,
                                      ).pop(); // back to My Crops
                                    } catch (e) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content:
                                              Text('Error deleting crop: $e'),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(color: Colors.redAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete Crop'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: green,
                          side: const BorderSide(color: Colors.redAccent),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class FarmerReviewSummaryCard extends StatelessWidget {
  final String farmerId;

  const FarmerReviewSummaryCard({super.key, required this.farmerId});

  @override
  Widget build(BuildContext context) {
    if (farmerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('farmer_reviews')
          .where('farmerId', isEqualTo: farmerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final reviews = snapshot.data?.docs ?? const [];
        final total = reviews.fold<double>(0, (sum, doc) {
          final value = doc.data()['rating'];
          if (value is num) return sum + value.toDouble();
          return sum;
        });
        final average = reviews.isEmpty ? 0.0 : total / reviews.length;

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE0F2E9)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),
                  const SizedBox(width: 10),
                  Text(
                    reviews.isEmpty
                        ? 'No ratings yet'
                        : '${average.toStringAsFixed(1)} / 5',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                reviews.isEmpty
                    ? 'Buyers can leave a rating and feedback.'
                    : '${reviews.length} review${reviews.length == 1 ? '' : 's'} from buyers',
                style: const TextStyle(color: Colors.black54),
              ),
            ],
          ),
        );
      },
    );
  }
}

class FarmerFeedbackList extends StatelessWidget {
  final String farmerId;
  final int limit;
  final String emptyLabel;

  const FarmerFeedbackList({
    super.key,
    required this.farmerId,
    this.limit = 5,
    this.emptyLabel = 'No feedback yet.',
  });

  @override
  Widget build(BuildContext context) {
    if (farmerId.isEmpty) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('farmer_reviews')
          .where('farmerId', isEqualTo: farmerId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox.shrink();
        }

        final reviews = [...?snapshot.data?.docs]..sort((a, b) {
            final aCreatedAt = a.data()['createdAt'];
            final bCreatedAt = b.data()['createdAt'];
            final aMillis = aCreatedAt is Timestamp
                ? aCreatedAt.millisecondsSinceEpoch
                : 0;
            final bMillis = bCreatedAt is Timestamp
                ? bCreatedAt.millisecondsSinceEpoch
                : 0;
            return bMillis.compareTo(aMillis);
          });

        if (reviews.isEmpty) {
          return Text(
            emptyLabel,
            style: const TextStyle(color: Colors.black54),
          );
        }

        final visibleReviews = reviews.take(limit).toList();
        return Column(
          children: visibleReviews.map((doc) {
            final data = doc.data();
            final rating = (data['rating'] is num)
                ? (data['rating'] as num).toDouble()
                : 0.0;
            final buyerName = (data['buyerName'] ?? 'Buyer').toString();
            final feedback = (data['feedback'] ?? '').toString().trim();

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE0F2E9)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        buyerName,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.star, size: 18, color: Colors.amber),
                        ],
                      ),
                    ],
                  ),
                  if (feedback.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      feedback,
                      style: const TextStyle(color: Colors.black87),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class FarmerRatingSheet extends StatefulWidget {
  final String farmerId;
  final String farmerName;

  const FarmerRatingSheet({
    super.key,
    required this.farmerId,
    required this.farmerName,
  });

  @override
  State<FarmerRatingSheet> createState() => _FarmerRatingSheetState();
}

class _FarmerRatingSheetState extends State<FarmerRatingSheet> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSaving = false;
  int _rating = 0;

  String get _reviewDocId {
    final buyerId = FirebaseAuth.instance.currentUser?.uid ?? 'anonymous';
    return '${widget.farmerId}_$buyerId';
  }

  @override
  void initState() {
    super.initState();
    _loadExistingReview();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingReview() async {
    final buyerId = FirebaseAuth.instance.currentUser?.uid;
    if (buyerId == null || widget.farmerId.isEmpty) return;

    final doc = await FirebaseFirestore.instance
        .collection('farmer_reviews')
        .doc(_reviewDocId)
        .get();
    final data = doc.data();
    if (!mounted || data == null) return;

    setState(() {
      _rating = (data['rating'] is num) ? (data['rating'] as num).round() : 0;
      _feedbackController.text = (data['feedback'] ?? '').toString();
    });
  }

  Future<void> _submitReview() async {
    final buyer = FirebaseAuth.instance.currentUser;
    if (buyer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit a rating.')),
      );
      return;
    }

    if (_rating < 1 || _rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating out of 5.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final buyerProfile = await FirebaseFirestore.instance
          .collection('buyers')
          .doc(buyer.uid)
          .get();
      final buyerName = (buyerProfile.data()?['name'] ??
              buyer.displayName ??
              buyer.email ??
              'Buyer')
          .toString();

      await FirebaseFirestore.instance
          .collection('farmer_reviews')
          .doc(_reviewDocId)
          .set({
            'farmerId': widget.farmerId,
            'farmerName': widget.farmerName,
            'buyerId': buyer.uid,
            'buyerName': buyerName,
            'rating': _rating,
            'feedback': _feedbackController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating submitted successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Rate ${widget.farmerName}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Give a rating out of 5 and share your feedback.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starValue = index + 1;
                return IconButton(
                  onPressed: _isSaving
                      ? null
                      : () => setState(() => _rating = starValue),
                  icon: Icon(
                    starValue <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 34,
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _feedbackController,
              enabled: !_isSaving,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Feedback',
                hintText: 'Share your experience with this farmer',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSaving ? null : _submitReview,
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Submit Rating'),
            ),
          ],
        ),
      ),
    );
  }
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _mobileController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  Role _role = Role.farmer;
  bool _useEmail = true; // true = email, false = mobile

  @override
  void dispose() {
    _emailController.dispose();
    _mobileController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();
    final identifier = _useEmail
        ? _emailController.text.trim()
        : _mobileController.text.trim();

    if (identifier.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')),
        );
      }
      return;
    }

    if (password != confirmPassword) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passwords do not match')),
        );
      }
      return;
    }

    if (password.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Password must be at least 6 characters')),
        );
      }
      return;
    }

    // Validate email format if using email
    if (_useEmail) {
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(identifier)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enter a valid email address')),
          );
        }
        return;
      }
    } else {
      // Validate mobile number
      final mobileRegex = RegExp(r'^\d{10}$');
      if (!mobileRegex.hasMatch(identifier)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Mobile number must be exactly 10 digits')),
          );
        }
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      String authEmail = _useEmail ? identifier : 'user$identifier@agri.local';

      print('=== REGISTRATION DEBUG ===');
      print('Attempting registration with: $authEmail');
      print('Using ${_useEmail ? 'email' : 'mobile'} mode');
      print('Password length: ${password.length}');

      // Create user account with email (or generated email from mobile)
      final userCredential =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: authEmail,
        password: password,
      );

      print('✓ User created successfully: ${userCredential.user!.uid}');

      // Store user info and role in Firestore users collection
      try {
        final userRole = _role == Role.buyer ? 'buyer' : 'farmer';
        final userData = {
          'role': userRole,
          'registrationType': _useEmail ? 'email' : 'mobile',
          'createdAt': FieldValue.serverTimestamp(),
        };

        if (!_useEmail) {
          userData['mobile'] = identifier;
        }

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(userData, SetOptions(merge: true));
        print('✓ User role and info saved to Firestore');
      } catch (firestoreError) {
        print('⚠ Firestore write warning: $firestoreError');
        // Don't fail registration if Firestore write fails
        // User is already created in Auth
      }

      if (mounted) {
        print('Navigating to profile screen...');
        // Navigate to appropriate profile screen based on role
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => _role == Role.farmer
                ? const FarmerProfileDetailsScreen()
                : const BuyerProfileDetailsScreen(),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      print('❌ FirebaseAuthException: Code=${e.code}, Message=${e.message}');
      if (mounted) {
        String errorMessage =
            'Registration failed: ${e.message ?? "Unknown error"}';

        if (e.code == 'configuration-not-found') {
          errorMessage =
              'Firebase setup incomplete!\n\n1. Go to Firebase Console\n2. Select agriconnect-1fdd3\n3. Go to Authentication → Sign-in method\n4. Enable Email/Password\n5. Click Save';
        } else if (e.code == 'email-already-in-use') {
          errorMessage = _useEmail
              ? 'Email already registered. Try login instead.'
              : 'Mobile number already registered. Try login instead.';
        } else if (e.code == 'weak-password') {
          errorMessage =
              'Password too weak. Use 8+ chars with letters, numbers & symbols.';
        } else if (e.code == 'invalid-email') {
          errorMessage = 'Invalid email format. Use: user@example.com';
        } else if (e.code == 'operation-not-allowed') {
          errorMessage =
              'Email/Password auth disabled in Firebase.\n\nEnable it:\n1. Firebase Console\n2. Authentication\n3. Sign-in method\n4. Email/Password → Enable';
        } else if (e.code == 'user-disabled') {
          errorMessage = 'This account has been disabled.';
        } else if (e.code == 'too-many-requests') {
          errorMessage = 'Too many attempts. Wait 15 minutes then try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 6),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ General Exception: ${e.runtimeType}');
      print('❌ Full error: $e');
      print('❌ Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            duration: const Duration(seconds: 5),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF16A34A);
    const lightGrey = Color(0xFFF5F5F5);
    const blue = Color(0xFF1D4ED8);

    final labelStyle = const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      color: Colors.black87,
    );

    InputDecoration inputDecoration(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.black45, fontSize: 16),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          filled: true,
          fillColor: lightGrey,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: green, width: 2),
          ),
        );

    Widget roleCard({
      required String label,
      required IconData icon,
      required bool selected,
      required Color selectedBorder,
      required Color selectedBg,
      required Color unselectedBorder,
      required Color unselectedBg,
      required VoidCallback onTap,
    }) {
      final Color borderColor = selected ? selectedBorder : unselectedBorder;
      final Color bgColor = selected ? selectedBg : unselectedBg;
      final Color textColor = selected ? selectedBorder : Colors.black87;
      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor, width: 1.6),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: textColor),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with rounded bottom
              Stack(
                children: [
                  Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      color: green,
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(24),
                        bottomRight: Radius.circular(24),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0x33000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                        const Expanded(
                          child: Center(
                            child: Text(
                              'Register',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                ],
              ),

              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'I am a:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        roleCard(
                          label: 'Farmer',
                          icon: Icons.agriculture,
                          selected: _role == Role.farmer,
                          selectedBorder: green,
                          selectedBg: const Color(0xFFE9F8EF),
                          unselectedBorder: Colors.grey.shade300,
                          unselectedBg: Colors.white,
                          onTap: () => setState(() => _role = Role.farmer),
                        ),
                        const SizedBox(width: 12),
                        roleCard(
                          label: 'Buyer',
                          icon: Icons.shopping_cart,
                          selected: _role == Role.buyer,
                          selectedBorder: blue,
                          selectedBg: const Color(0xFFEFF4FF),
                          unselectedBorder: Colors.grey.shade300,
                          unselectedBg: Colors.white,
                          onTap: () => setState(() => _role = Role.buyer),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Register with:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _useEmail = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: _useEmail
                                    ? const Color(0xFFE9F8EF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      _useEmail ? green : Colors.grey.shade300,
                                  width: _useEmail ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.email_outlined,
                                    color: _useEmail ? green : Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Email',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _useEmail ? green : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _useEmail = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: !_useEmail
                                    ? const Color(0xFFE9F8EF)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color:
                                      !_useEmail ? green : Colors.grey.shade300,
                                  width: !_useEmail ? 1.6 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.phone_outlined,
                                    color: !_useEmail ? green : Colors.black54,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Mobile',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color:
                                          !_useEmail ? green : Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    if (_useEmail) ...[
                      Text('Email', style: labelStyle),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(fontSize: 18),
                        decoration: inputDecoration('Enter your email'),
                      ),
                    ] else ...[
                      Text('Mobile Number', style: labelStyle),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _mobileController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(fontSize: 18),
                        maxLength: 10,
                        decoration:
                            inputDecoration('Enter 10-digit mobile number'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Text('Password', style: labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 18),
                      decoration:
                          inputDecoration('Enter password (min 6 chars)'),
                    ),
                    const SizedBox(height: 16),
                    Text('Confirm Password', style: labelStyle),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      style: const TextStyle(fontSize: 18),
                      decoration: inputDecoration('Confirm password'),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _handleRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: green,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: Colors.black26,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Register'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text(
                            'Already have an account? ',
                            style: TextStyle(fontSize: 14),
                          ),
                          InkWell(
                            onTap: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: green,
                              ),
                            ),
                          ),
                        ],
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
}

class FarmerPreOrdersScreen extends StatefulWidget {
  const FarmerPreOrdersScreen({super.key});

  @override
  State<FarmerPreOrdersScreen> createState() => _FarmerPreOrdersScreenState();
}

class _FarmerPreOrdersScreenState extends State<FarmerPreOrdersScreen> {
  String _formatDisplayDate(dynamic value) {
    if (value == null) return '-';
    if (value is Timestamp) {
      return value.toDate().toLocal().toString().split(' ').first;
    }
    if (value is DateTime) {
      return value.toLocal().toString().split(' ').first;
    }
    return value.toString();
  }

  String _formatStatus(String status) {
    if (status.isEmpty) return 'Ordered';
    return status[0].toUpperCase() + status.substring(1);
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'accepted':
        return Colors.blue;
      case 'rejected':
        return Colors.redAccent;
      default:
        return const Color(0xFF16A34A);
    }
  }

  Duration? _timeLeft(dynamic createdAt) {
    final created = createdAt is Timestamp
        ? createdAt.toDate()
        : createdAt is DateTime
            ? createdAt
            : null;
    if (created == null) return null;
    return created.add(const Duration(hours: 10)).difference(DateTime.now());
  }

  String _formatTimeLeft(Duration? remaining) {
    if (remaining == null) return '10h remaining';
    if (remaining.isNegative) return 'Expired';
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    return '${hours}h ${minutes}m left';
  }

  Future<void> _updatePreOrderStatus({
    required String docId,
    required String status,
    required String farmerId,
  }) async {
    await FirebaseFirestore.instance.collection('pre_orders').doc(docId).update({
      'status': status,
      'respondedFarmerId': farmerId,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final farmerId = FirebaseAuth.instance.currentUser?.uid;

    if (farmerId == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pre-order Requests')),
        body: const Center(child: Text('No user logged in.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Pre-order Requests')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('pre_orders').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final orders = [...?snapshot.data?.docs]
            ..removeWhere((doc) {
              final data = doc.data();
              final selectedFarmer = (data['selectedFarmer'] ?? '').toString();
              final visibleToAll = data['visibleToAllFarmers'] == true;
              final matchesFarmer =
                  selectedFarmer.isEmpty || selectedFarmer == farmerId;
              return !(visibleToAll || matchesFarmer);
            })
            ..sort((a, b) {
              final aCreatedAt = a.data()['createdAt'];
              final bCreatedAt = b.data()['createdAt'];
              final aMillis = aCreatedAt is Timestamp
                  ? aCreatedAt.millisecondsSinceEpoch
                  : 0;
              final bMillis = bCreatedAt is Timestamp
                  ? bCreatedAt.millisecondsSinceEpoch
                  : 0;
              return bMillis.compareTo(aMillis);
            });

          if (orders.isEmpty) {
            return const Center(child: Text('No pre-order requests found.'));
          }

          return ListView.builder(
            itemCount: orders.length,
            padding: const EdgeInsets.all(12),
            itemBuilder: (context, index) {
              final doc = orders[index];
              final data = doc.data();
              final status = (data['status'] ?? 'pending').toString();
              final remaining = _timeLeft(data['createdAt']);
              final isExpired = status == 'pending' &&
                  remaining != null &&
                  remaining.isNegative;
              final buyerId = (data['uid'] ?? '').toString();

              if (isExpired) {
                Future.microtask(() {
                  _updatePreOrderStatus(
                    docId: doc.id,
                    status: 'expired',
                    farmerId: farmerId,
                  );
                });
              }

              final effectiveStatus = isExpired ? 'expired' : status;
              final canRespond = effectiveStatus == 'pending';
              final statusColor = effectiveStatus == 'accepted'
                  ? Colors.blue
                  : effectiveStatus == 'rejected'
                      ? Colors.redAccent
                      : effectiveStatus == 'expired'
                          ? Colors.grey
                          : Colors.orange;

              return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: buyerId.isEmpty
                    ? null
                    : FirebaseFirestore.instance
                        .collection('buyers')
                        .doc(buyerId)
                        .get(),
                builder: (context, buyerSnapshot) {
                  final buyerData = buyerSnapshot.data?.data();
                  final buyerName = (buyerData?['name'] ?? 'Buyer').toString();
                  final buyerMobile =
                      (buyerData?['mobile'] ?? '-').toString();

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  (data['cropName'] ?? 'Unknown crop').toString(),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              Text(
                                effectiveStatus[0].toUpperCase() +
                                    effectiveStatus.substring(1),
                                style: TextStyle(
                                  color: statusColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Qty: ${data['quantityKg'] ?? '-'} kg\n'
                            'Target: ${_formatDisplayDate(data['targetDate'])}\n'
                            'Price: ${data['targetPrice'] ?? '-'}\n'
                            'Response Window: ${_formatTimeLeft(remaining)}',
                          ),
                          if (buyerId.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            InkWell(
                              onTap: () => openPublicProfile(
                                context,
                                userId: buyerId,
                                fallbackRole: 'buyer',
                              ),
                              child: Text(
                                'Buyer Name: $buyerName',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            InkWell(
                              onTap: () => openPublicProfile(
                                context,
                                userId: buyerId,
                                fallbackRole: 'buyer',
                              ),
                              child: Text(
                                'Buyer Mobile: $buyerMobile',
                                style: const TextStyle(
                                  color: Color(0xFF1D4ED8),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                          if (canRespond) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      await _updatePreOrderStatus(
                                        docId: doc.id,
                                        status: 'accepted',
                                        farmerId: farmerId,
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Pre-order request accepted.'),
                                        ),
                                      );
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF16A34A),
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Accept'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () async {
                                      await _updatePreOrderStatus(
                                        docId: doc.id,
                                        status: 'rejected',
                                        farmerId: farmerId,
                                      );
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content:
                                              Text('Pre-order request rejected.'),
                                        ),
                                      );
                                    },
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
