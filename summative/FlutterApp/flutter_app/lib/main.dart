import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const SalaryPredictorApp());
}

// App Root
class SalaryPredictorApp extends StatelessWidget {
  const SalaryPredictorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Nairobi Hiring Tool',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1565C0),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
        useMaterial3: true,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBBDEFB)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFBBDEFB), width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE53935), width: 2),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          labelStyle: const TextStyle(color: Color(0xFF5C6BC0)),
          floatingLabelStyle: const TextStyle(
              color: Color(0xFF1565C0), fontWeight: FontWeight.w600),
        ),
      ),
      home: const PredictionPage(),
    );
  }
}

//Prediction Page 
class PredictionPage extends StatefulWidget {
  const PredictionPage({super.key});

  @override
  State<PredictionPage> createState() => _PredictionPageState();
}

class _PredictionPageState extends State<PredictionPage>
    with SingleTickerProviderStateMixin {
  //Controllers 
  final _formKey = GlobalKey<FormState>();
  final _experienceController = TextEditingController();

  String? _selectedGender;
  String? _selectedEducation;
  String? _selectedJobTitle;

  // State 
  bool _isLoading = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  //API config 
  static const String _apiBase =
      'https://salary-prediction-api-lbh8.onrender.com';

  // Dropdown options 
  List<String> _genders = ['Male', 'Female'];

  List<String> _educationLevels = [
    'High School',
    "Bachelor's",
    "Master's",
    'PhD',
  ];

  // fallback until a fetch gives the canonical list from the API
  List<String> _jobTitles = [
    'Software Engineer',
    'Data Scientist',
    'Data Analyst',
    'Senior Software Engineer',
    'Junior Software Engineer',
    'Marketing Analyst',
    'Product Manager',
    'Sales Associate',
  ];

  // true while we are fetching canonical lists from the API
  bool _modelInfoLoading = true;
  // true if the last fetch failed (show a Retry button)
  bool _modelInfoFailed = false;

  @override
  void initState() {
    super.initState();
  _fetchModelInfo();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
  }

  Future<void> _fetchModelInfo() async {
    // mark we're attempting a fetch
    if (mounted) setState(() { _modelInfoLoading = true; _modelInfoFailed = false; });
    try {
      final uri = Uri.parse('$_apiBase/model-info');
      // increase timeout slightly to allow for slow responses
      final resp = await http.get(uri).timeout(const Duration(seconds: 15));
      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        final gotGenders = (body['known_genders'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final gotEduc = (body['known_education_levels'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];
        final gotJobs = (body['all_job_titles'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            (body['job_titles_sample'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [];

        setState(() {
          if (gotGenders.isNotEmpty) _genders = gotGenders;
          if (gotEduc.isNotEmpty) _educationLevels = gotEduc;
          if (gotJobs.isNotEmpty) _jobTitles = gotJobs;
        });
      }
    } catch (e) {
      // keep fallbacks; record failure so UI can show a retry control
      // ignore: avoid_print
      print('Could not fetch model-info: $e');
      if (mounted) setState(() => _modelInfoFailed = true);
    } finally {
      // mark loading finished regardless of success/failure
      if (mounted) setState(() => _modelInfoLoading = false);
    }
  }

  @override
  void dispose() {
    _experienceController.dispose();
    _animController.dispose();
    super.dispose();
  }

  //API call 
  Future<void> _predict() async {
    // Validate form fields first
    if (!_formKey.currentState!.validate()) return;

    // Extra client-side validation to avoid submitting a job title
    // that isn't in the canonical list (prevents 422 from the API).
    if (_selectedJobTitle == null || !_jobTitles.contains(_selectedJobTitle)) {
      setState(() {
        _errorMessage = 'Please select a valid job title from the list.';
      });
      _animController.forward();
      return;
    }

    setState(() {
      _isLoading = true;
      _result = null;
      _errorMessage = null;
    });
    _animController.reset();

    try {
      final response = await http
          .post(
            Uri.parse('$_apiBase/predict'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'gender': _selectedGender,
              'education_level': _selectedEducation,
              'job_title': _selectedJobTitle,
              'years_of_experience':
                  double.parse(_experienceController.text.trim()),
            }),
          )
          .timeout(const Duration(seconds: 30));

      final body = jsonDecode(response.body);

      if (response.statusCode == 200) {
        setState(() {
          _result = body;
          _errorMessage = null;
        });
        _animController.forward();
      } else {
        setState(() {
          _errorMessage = body['detail']?.toString() ??
              'Prediction failed (${response.statusCode})';
        });
        _animController.forward();
      }
    } catch (e) {
      setState(() {
        _errorMessage =
            'Could not reach the API. Check your internet connection.\n\nDetail: $e';
      });
      _animController.forward();
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 140,
            pinned: true,
            backgroundColor: const Color(0xFF1565C0),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.only(left: 20, bottom: 16, right: 20),
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Salary Predictor',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  Text(
                    'Nairobi Tech Hiring Tool',
                    style: TextStyle(
                      color: Color(0xFFBBDEFB),
                      fontSize: 11,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Padding(

                    padding: const EdgeInsets.only(right: 24, top: 20),
                    child: Icon(
                      Icons.work_outline_rounded,
                      size: 80,
                      color: Color.fromRGBO(255, 255, 255, 0.08),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Mission badge ───────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFF90CAF9), width: 1),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.location_on_outlined,
                              size: 16, color: Color(0xFF1565C0)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Fair salary benchmarking for Kasarani & Nairobi tech talent',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF1565C0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Form card ───────────────────────────────────────────
                    _buildSectionLabel('Candidate Profile'),
                    const SizedBox(height: 12),

                    _buildCard(
                      child: Column(
                        children: [
                          // Gender
                          _buildDropdown(
                            label: 'Gender',
                            value: _selectedGender,
                            items: _genders,
                            icon: Icons.person_outline_rounded,
                            onChanged: (v) =>
                                setState(() => _selectedGender = v),
                            validator: (v) =>
                                v == null ? 'Please select a gender' : null,
                          ),

                          const SizedBox(height: 16),

                          // Education Level
                          _buildDropdown(
                            label: 'Education Level',
                            value: _selectedEducation,
                            items: _educationLevels,
                            icon: Icons.school_outlined,
                            onChanged: (v) =>
                                setState(() => _selectedEducation = v),
                            validator: (v) => v == null
                                ? 'Please select education level'
                                : null,
                          ),

                          const SizedBox(height: 16),

                          // Job Title
                          _buildDropdown(
                            label: 'Job Title',
                            value: _selectedJobTitle,
                            items: _jobTitles,
                            icon: Icons.badge_outlined,
                            onChanged: (v) => setState(() => _selectedJobTitle = v),
                            validator: (v) {
                              if (v == null) return 'Please select a job title';
                              if (!_jobTitles.contains(v)) return 'Select a title from the list';
                              return null;
                            },
                          ),
                          if (_modelInfoFailed)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Row(
                                children: [
                                  const Text('Could not load canonical titles.'),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _fetchModelInfo,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Years of Experience
                          TextFormField(
                            controller: _experienceController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d+\.?\d{0,1}')),
                            ],
                            decoration: InputDecoration(
                              labelText: 'Years of Experience',
                              hintText: 'e.g. 3.5',
                              prefixIcon: const Icon(
                                Icons.timeline_rounded,
                                color: Color(0xFF5C6BC0),
                              ),
                              suffixText: 'yrs',
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Please enter years of experience';
                              }
                              final val = double.tryParse(v.trim());
                              if (val == null) {
                                return 'Enter a valid number';
                              }
                              if (val < 0 || val > 50) {
                                return 'Experience must be between 0 and 50 years';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Predict button ──────────────────────────────────────
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: (_isLoading || _modelInfoLoading) ? null : _predict,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1565C0),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor:
                              const Color(0xFF90CAF9),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.auto_graph_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'Predict',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── Result display ──────────────────────────────────────
                    if (_result != null || _errorMessage != null)
                      FadeTransition(
                        opacity: _fadeAnim,
                        child: SlideTransition(
                          position: _slideAnim,
                          child: _errorMessage != null
                              ? _buildErrorCard()
                              : _buildResultCard(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Color(0xFF5C6BC0),
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(21, 101, 192, 0.07),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: child,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required void Function(String?) onChanged,
    required String? Function(String?) validator,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF5C6BC0)),
      ),
      isExpanded: true,
      icon: const Icon(Icons.keyboard_arrow_down_rounded,
          color: Color(0xFF5C6BC0)),
      items: items
          .map((item) => DropdownMenuItem(
                value: item,
                child: Text(item,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF1A1A2E))),
              ))
          .toList(),
      onChanged: onChanged,
      validator: validator,
    );
  }

  Widget _buildResultCard() {
    final usd = _result!['predicted_salary_usd'] as num;
    final kesAnnual = _result!['predicted_salary_kes_annual'] as num;
    final kesMonthly = _result!['predicted_salary_kes_monthly'] as num;
    final modelUsed = _result!['model_used'] as String? ?? 'Unknown';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionLabel('Prediction Result'),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Color.fromRGBO(21, 101, 192, 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // USD primary
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'USD',
                      style: TextStyle(
                        color: Color(0xFF90CAF9),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$${_formatNumber(usd.toDouble())}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 6, left: 6),
                      child: Text(
                        '/ year',
                        style: TextStyle(
                          color: Color(0xFF90CAF9),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(color: Colors.white24, height: 1),
                const SizedBox(height: 16),

                // KES breakdown
                Row(
                  children: [
                    Expanded(
                      child: _buildKesBox(
                        label: 'Annual (KES)',
                        value: 'KES ${_formatNumber(kesAnnual.toDouble())}',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKesBox(
                        label: 'Monthly (KES)',
                        value: 'KES ${_formatNumber(kesMonthly.toDouble())}',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Model used chip
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Color.fromRGBO(255, 255, 255, 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.memory_rounded,
                              size: 13, color: Color(0xFF90CAF9)),
                          const SizedBox(width: 5),
                          Text(
                            modelUsed,
                            style: const TextStyle(
                              color: Color(0xFFBBDEFB),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '@ KES 130/USD',
                      style: TextStyle(
                        color: Color(0xFF90CAF9),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKesBox({required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Color.fromRGBO(255, 255, 255, 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF90CAF9),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE53935), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Prediction Error',
                  style: TextStyle(
                    color: Color(0xFFB71C1C),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFE53935),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(2)}M';
    } else if (value >= 1000) {
      final parts = value.toStringAsFixed(0).split('');
      final result = StringBuffer();
      for (int i = 0; i < parts.length; i++) {
        if (i > 0 && (parts.length - i) % 3 == 0) result.write(',');
        result.write(parts[i]);
      }
      return result.toString();
    }
    return value.toStringAsFixed(2);
  }
}