import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:style_match/services/weather_service.dart';
import '../services/auth_service.dart';
import '../services/wardrobe_cache_service.dart';
import '../widgets/outfit_avatar.dart';

class OutfitItemOption {
  final String label;
  final IconData icon;
  const OutfitItemOption(this.label, this.icon);
}

class AIOutfitScreen extends StatefulWidget {
  final List<int>? preselectedItemIds;
  final VoidCallback? onNavigateToWardrobe;

  const AIOutfitScreen({
    super.key,
    this.preselectedItemIds,
    this.onNavigateToWardrobe,
  });

  @override
  State<AIOutfitScreen> createState() => AIOutfitScreenState();
}

class AIOutfitScreenState extends State<AIOutfitScreen> {
  String selectedOccasion = "Casual";
  String selectedSeason = "All Season";
  bool isLoading = false;
  bool isInitialLoading = true;
  List<dynamic> outfits = [];
  List<List<int>> previousOutfits = [];
  String? userEmail;
  Map<String, dynamic>? weatherData;
  String weatherText = "";
  List<dynamic> wardrobeItems = [];
  List<int> selectedItemIds = [];
  bool isCustomizerExpanded = false;

  final Set<int> _regeneratingOutfitIndices = {};
  String userGender = "Female";

  final List<OutfitItemOption> occasions = const [
    OutfitItemOption("Casual", Icons.local_cafe_outlined),
    OutfitItemOption("Work", Icons.work_outline),
    OutfitItemOption("University", Icons.school_outlined),
    OutfitItemOption("Party", Icons.celebration_outlined),
    OutfitItemOption("Date Night", Icons.favorite_border),
    OutfitItemOption("Travel", Icons.flight_outlined),
    OutfitItemOption("Formal", Icons.business_center_outlined),
    OutfitItemOption("Wedding", Icons.diamond_outlined),
  ];

  final List<OutfitItemOption> seasons = const [
    OutfitItemOption("All Season", Icons.auto_awesome),
    OutfitItemOption("Summer", Icons.beach_access_outlined),
    OutfitItemOption("Winter", Icons.ac_unit),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedItemIds != null) {
      selectedItemIds = List<int>.from(widget.preselectedItemIds!);
      isCustomizerExpanded = true;
    }
    loadDataAndRecommend();
  }

  Future<void> reloadWardrobe({bool forceRegenerate = false}) async {
    if (userEmail == null) return;
    final items = await ApiService.getClothes(userEmail!);
    if (items != null && mounted) {
      setState(() => wardrobeItems = items);
      if (forceRegenerate || (outfits.isEmpty && items.length >= 2)) {
        generateOutfit(silent: false);
      }
    }
  }

  Future<void> loadDataAndRecommend() async {
    setState(() => isInitialLoading = true);
    final email = await AuthService.getUserEmail();
    if (!mounted) return;
    setState(() => userEmail = email);

    Map<String, dynamic>? weather = await WeatherService.getCurrentWeather();
    if (weather == null) {
      final lastCity = await WeatherService.getLastCity();
      if (lastCity != null && lastCity.isNotEmpty) {
        weather = await WeatherService.getWeatherByCity(lastCity);
      }
    }

    if (weather != null && mounted) {
      setState(() {
        weatherData = weather;
        weatherText = WeatherService.getWeatherContext(weather!);
      });
    }

    if (userEmail != null) {
      await _fetchUserGender(userEmail!);

      List<dynamic>? items = await ApiService.getClothes(userEmail!);
      items ??= await WardrobeCacheService.getCachedClothes(userEmail!);

      if (mounted) {
        setState(() {
          wardrobeItems = items ?? [];
          isInitialLoading = false;
        });
      }

      if (items != null && items.length >= 2) {
        await generateOutfit(isAutoTodayLook: true);
      }
    } else {
      if (mounted) setState(() => isInitialLoading = false);
    }
  }

  Future<void> _fetchUserGender(String email) async {
    try {
      final profile = await ApiService.getProfile(email);
      if (profile != null && profile["success"] == true && mounted) {
        setState(() {
          userGender = profile["gender"]?.toString() ?? "Female";
        });
      }
    } catch (e) {
      debugPrint("Error fetching user gender: $e");
    }
  }

  Future<void> generateOutfit({bool isAutoTodayLook = false, bool silent = false}) async {
    if (userEmail == null) return;
    if (wardrobeItems.length < 2) {
      if (!isAutoTodayLook && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Add at least 2 items to your wardrobe to get recommendations.")),
        );
      }
      return;
    }

    if (!silent) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final data = await ApiService.generateOutfit(
        userEmail!,
        selectedOccasion,
        selectedSeason,
        weatherText,
        previousOutfits,
        selectedItemIds,
      );

      if (!mounted) return;

      if (data != null && data["success"] == true) {
        final newOutfits = data["outfits"] as List<dynamic>? ?? [];
        setState(() {
          outfits = newOutfits;
        });

        for (var outfit in newOutfits) {
          final items = outfit["items"] as List<dynamic>? ?? [];
          final itemIds = items
              .map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0)
              .where((id) => id != 0)
              .toList();
          if (itemIds.isNotEmpty) {
            previousOutfits.add(itemIds);
          }
        }
      } else {
        if (!isAutoTodayLook) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data?["message"] ?? "Could not generate outfit combination.")),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      if (!isAutoTodayLook) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Connection error. Please check backend connection.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> tryAnotherOutfit() async {
    if (outfits.isNotEmpty) {
      final currentHeroItems = (outfits[0]["items"] as List<dynamic>?) ?? [];
      final itemIds = currentHeroItems
          .map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0)
          .where((id) => id != 0)
          .toList();
      if (itemIds.isNotEmpty && !previousOutfits.contains(itemIds)) {
        previousOutfits.add(itemIds);
      }
    }
    await generateOutfit();
  }

  void _changeOccasion(String occasion) {
    if (selectedOccasion == occasion) return;
    setState(() {
      selectedOccasion = occasion;
      previousOutfits.clear();
    });
    generateOutfit();
  }

  Future<void> regenerateOutfitOption(int index, List<int> currentOutfitItemIds) async {
    if (userEmail == null) return;

    if (currentOutfitItemIds.isNotEmpty) {
      previousOutfits.add(currentOutfitItemIds);
    }

    setState(() {
      _regeneratingOutfitIndices.add(index);
    });

    try {
      final data = await ApiService.generateOutfit(
        userEmail!,
        selectedOccasion,
        selectedSeason,
        weatherText,
        previousOutfits,
        selectedItemIds,
      );

      if (data != null && data["success"] == true && mounted) {
        final List<dynamic> newOutfits = data["outfits"] ?? [];
        if (newOutfits.isNotEmpty) {
          setState(() {
            outfits[index] = newOutfits[0];
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Outfit option refreshed!"),
              backgroundColor: Color(0xFF0F766E),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("No alternate combinations found in closet.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to refresh outfit combination.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _regeneratingOutfitIndices.remove(index);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.canPop(context);

    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      appBar: canPop
          ? AppBar(
              backgroundColor: const Color(0xFFFAF7F2),
              elevation: 0,
              centerTitle: true,
              title: const Text(
                "Personal Stylist",
                style: TextStyle(color: Color(0xFF171717), fontWeight: FontWeight.bold, fontSize: 18),
              ),
              iconTheme: const IconThemeData(color: Color(0xFF171717)),
            )
          : null,
      body: RefreshIndicator(
        color: const Color(0xFF0F766E),
        onRefresh: () async {
          await loadDataAndRecommend();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!canPop) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Today's Stylist",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF171717),
                            letterSpacing: -0.5,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          "Personalized looks from your wardrobe",
                          style: TextStyle(fontSize: 13, color: Color(0xFF737373)),
                        ),
                      ],
                    ),
                    if (wardrobeItems.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.checkroom, size: 14, color: Color(0xFF0F766E)),
                            const SizedBox(width: 4),
                            Text(
                              "${wardrobeItems.length} items",
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F766E),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],

              _buildWeatherBar(),
              const SizedBox(height: 16),
              _buildOccasionBar(),
              const SizedBox(height: 16),

              if (isInitialLoading || (isLoading && outfits.isEmpty))
                _buildStylistLoadingState()
              else if (wardrobeItems.length < 2)
                _buildWardrobeEmptyState()
              else if (outfits.isNotEmpty) ...[
                _buildTodaysLookHeroCard(outfits[0]),
                if (outfits.length > 1) ...[
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      const Text(
                        "Alternative Looks",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF171717),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "${outfits.length - 1} more",
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  for (int i = 1; i < outfits.length; i++)
                    _outfitCard(outfits[i], i),
                ],
              ] else
                _buildNoRecommendationsState(),

              const SizedBox(height: 16),
              _buildCustomizerAccordion(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeatherBar() {
    final hasWeather = weatherData != null;
    final city = hasWeather ? (weatherData!["city"] ?? "Unknown") : "";
    final temp = hasWeather ? (weatherData!["temp"]?.toStringAsFixed(0) ?? "0") : "";
    final desc = hasWeather ? (weatherData!["description"] ?? "") : "";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          )
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasWeather ? const Color(0xFF0F766E).withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasWeather ? Icons.wb_sunny_outlined : Icons.location_on_outlined,
              color: hasWeather ? const Color(0xFF0F766E) : Colors.orange,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      hasWeather ? "$city, $temp°C" : "Set Location",
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF171717),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F766E).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedSeason,
                        style: const TextStyle(fontSize: 10, color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  hasWeather ? desc : "Tap to set location for weather-based styling",
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_location_alt_outlined, color: Color(0xFF0F766E), size: 20),
            onPressed: _showCityInputDialog,
            tooltip: "Change City",
          ),
        ],
      ),
    );
  }

  Widget _buildOccasionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.tune, color: Color(0xFF0F766E), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                text: "Occasion: ",
                style: const TextStyle(fontSize: 13, color: Color(0xFF737373)),
                children: [
                  TextSpan(
                    text: selectedOccasion,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: _showChangeOccasionSheet,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0F766E),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Change",
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodaysLookHeroCard(dynamic outfit) {
    final items = (outfit["items"] as List<dynamic>?) ?? [];
    final description = outfit["description"]?.toString() ?? "A personalized look crafted from your wardrobe.";
    final isFallback = outfit["is_fallback"] == true;
    final fallbackExplanation = outfit["missing_pieces_explanation"]?.toString();
    final styleConcept = outfit["style_concept"]?.toString() ?? "Today's Curated Look";
    final stylingTip = outfit["styling_tip"]?.toString() ?? "";

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F766E).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          )
        ],
        border: Border.all(color: const Color(0xFFE6EFEB), width: 1.5),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFFF0FAF9),
                border: Border(bottom: BorderSide(color: Color(0xFFD8EEEA))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F766E),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "TODAY'S LOOK",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F766E),
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFD8EEEA))),
                    child: Text(
                      selectedOccasion,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F766E),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            if (isFallback && fallbackExplanation != null && fallbackExplanation.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFFFF7ED),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFC2410C), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fallbackExplanation,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFC2410C), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              styleConcept,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF171717),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Curated based on your style and today's weather",
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      ),
                      _saveButton(items, description),
                    ],
                  ),
                  const SizedBox(height: 16),

                  OutfitAvatar(items: items),
                  const SizedBox(height: 16),

                  if (stylingTip.isNotEmpty) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFAF9F6),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFEBEAE5)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(Icons.lightbulb_outline, color: Color(0xFF0F766E), size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Stylist Tip",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F766E),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  stylingTip,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.35),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  Text(
                    description,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF374151), height: 1.4),
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _showChangeOccasionSheet,
                          icon: const Icon(Icons.tune, size: 16),
                          label: const Text("Change Occasion"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF0F766E),
                            side: const BorderSide(color: Color(0xFF0F766E), width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: isLoading ? null : tryAnotherOutfit,
                          icon: isLoading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.refresh, size: 16, color: Colors.white),
                          label: const Text("Try Another", style: TextStyle(color: Colors.white)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0F766E),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _outfitCard(dynamic outfit, int index) {
    final items = (outfit["items"] as List<dynamic>?) ?? [];
    final description = outfit["description"]?.toString() ?? "An alternative curated look.";
    final isFallback = outfit["is_fallback"] == true;
    final fallbackExplanation = outfit["missing_pieces_explanation"]?.toString();
    final styleConcept = outfit["style_concept"]?.toString() ?? "Alternative Look $index";
    final stylingTip = outfit["styling_tip"]?.toString() ?? "";
    final List<int> itemIds = items
        .map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0)
        .where((id) => id != 0)
        .toList();
    final isRegenerating = _regeneratingOutfitIndices.contains(index);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            if (isFallback && fallbackExplanation != null && fallbackExplanation.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: const Color(0xFFFFF7ED),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(0xFFC2410C), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fallbackExplanation,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFC2410C), height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          styleConcept,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF171717),
                          ),
                        ),
                      ),
                      _saveButton(items, description),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutfitAvatar(items: items),
                  if (stylingTip.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      stylingTip,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), height: 1.3),
                    ),
                  ],
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: OutlinedButton(
                      onPressed: isRegenerating ? null : () => regenerateOutfitOption(index, itemIds),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF0F766E),
                        side: const BorderSide(color: Color(0xFF0F766E), width: 1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text("Cycle This Alternative", style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
            if (isRegenerating)
              Positioned.fill(
                child: Container(
                  color: Colors.white.withValues(alpha: 0.85),
                  child: const Center(
                    child: CircularProgressIndicator(color: Color(0xFF0F766E)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStylistLoadingState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, size: 36, color: Color(0xFF0F766E)),
          ),
          const SizedBox(height: 20),
          const Text(
            "Styling Today's Look...",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
          ),
          const SizedBox(height: 6),
          const Text(
            "Analyzing your wardrobe pieces, style profile, and weather to craft the perfect combination.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 24),
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              color: Color(0xFF0F766E),
              strokeWidth: 2.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWardrobeEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF0F766E).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.checkroom_outlined, size: 40, color: Color(0xFF0F766E)),
          ),
          const SizedBox(height: 18),
          const Text(
            "Add Clothes to Get Recommendations",
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
          ),
          const SizedBox(height: 6),
          const Text(
            "Style Match curates outfits directly from your own digital wardrobe. Add at least 2 pieces (e.g. Tops & Bottoms) to unlock Today's Look.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: widget.onNavigateToWardrobe,
            icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.white, size: 18),
            label: const Text("Go to Wardrobe", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoRecommendationsState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const Icon(Icons.sentiment_dissatisfied_outlined, size: 40, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              "No combinations found",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            const Text(
              "Try changing the occasion or adding more versatile items to your wardrobe.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => generateOutfit(),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
              child: const Text("Retry Recommendation", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeOccasionSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFAF7F2),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                "Change Occasion",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
              ),
              const SizedBox(height: 4),
              const Text(
                "Select what you're dressing for today. Style Match will curate a tailored look.",
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: occasions.map((occ) {
                  final isSelected = selectedOccasion == occ.label;
                  return InkWell(
                    onTap: () {
                      Navigator.pop(ctx);
                      _changeOccasion(occ.label);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF0F766E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected ? const Color(0xFF0F766E) : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                        boxShadow: [
                          if (isSelected)
                            BoxShadow(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            occ.icon,
                            size: 18,
                            color: isSelected ? Colors.white : const Color(0xFF0F766E),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            occ.label,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF171717),
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCustomizerAccordion() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: isCustomizerExpanded,
          onExpansionChanged: (val) => setState(() => isCustomizerExpanded = val),
          leading: const Icon(Icons.settings_suggest_outlined, color: Color(0xFF0F766E)),
          title: const Text(
            "Refine & Specific Item Styling",
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
          ),
          subtitle: Text(
            selectedItemIds.isNotEmpty ? "${selectedItemIds.length} item(s) selected" : "Optional wardrobe anchors",
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Season Context", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: seasons.map((sea) {
                      final isSel = selectedSeason == sea.label;
                      return ChoiceChip(
                        label: Text(sea.label),
                        selected: isSel,
                        selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                        labelStyle: TextStyle(
                          color: isSel ? const Color(0xFF0F766E) : Colors.black87,
                          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => selectedSeason = sea.label);
                            generateOutfit();
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Style Around Specific Items", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      if (selectedItemIds.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            setState(() => selectedItemIds.clear());
                            generateOutfit();
                          },
                          child: const Text("Clear", style: TextStyle(fontSize: 12, color: Color(0xFFE11D48), fontWeight: FontWeight.w600)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildStylingItemSelector(),
                  const SizedBox(height: 16),
                  if (selectedItemIds.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => generateOutfit(),
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                        child: const Text("Apply Custom Filter", style: TextStyle(color: Colors.white, fontSize: 13)),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton(List<dynamic> items, String desc) {
    return GestureDetector(
      onTap: () => _showSaveOutfitSheet(items, desc),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: const BoxDecoration(color: Color(0xFFFDE8E8), shape: BoxShape.circle),
        child: const Icon(Icons.favorite, color: Color(0xFFE11D48), size: 18),
      ),
    );
  }

  void _showSaveOutfitSheet(List<dynamic> items, String desc) {
    final ids = items.map((i) => int.tryParse(i["id"]?.toString() ?? "") ?? 0).where((id) => id != 0).toList();
    List<String> selectedTags = [];
    final List<String> availableTags = ["Casual", "Formal", "Work", "Party", "Weekend", "Sporty", "Vacation", "University"];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAF7F2),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: MediaQuery.of(bottomSheetContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Save to Lookbook",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Categorize this outfit in your personal Lookbook:",
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTags.map((tag) {
                      final isSelected = selectedTags.contains(tag);
                      return FilterChip(
                        label: Text(tag),
                        selected: isSelected,
                        selectedColor: const Color(0xFF0F766E).withValues(alpha: 0.15),
                        checkmarkColor: const Color(0xFF0F766E),
                        labelStyle: TextStyle(
                          color: isSelected ? const Color(0xFF0F766E) : Colors.black87,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        ),
                        onSelected: (selected) {
                          setModalState(() {
                            if (selected) {
                              selectedTags.add(tag);
                            } else {
                              selectedTags.remove(tag);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(bottomSheetContext);
                        final email = userEmail ?? await AuthService.getUserEmail();
                        if (email == null || email.isEmpty) return;

                        final success = await ApiService.saveOutfit(
                          email,
                          selectedOccasion,
                          selectedSeason,
                          ids,
                          desc,
                          tags: selectedTags,
                        );
                        if (success) {
                          ApiService.getSavedOutfits(email).then((freshOutfits) {
                            if (freshOutfits.isNotEmpty) {
                              WardrobeCacheService.saveCachedSavedOutfits(email, freshOutfits);
                            }
                          });
                          navigator.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text("Outfit successfully saved to Lookbook!"),
                              backgroundColor: Color(0xFF0F766E),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        "Save Look",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCityInputDialog() {
    final controller = TextEditingController(text: weatherData?["city"] ?? "");
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text("Enter City Name"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "e.g. New York, London, Paris"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              final city = controller.text.trim();
              if (city.isNotEmpty) {
                Navigator.pop(dialogCtx);
                final weather = await WeatherService.getWeatherByCity(city);
                if (!mounted) return;
                if (weather != null) {
                  await WeatherService.saveLastCity(city);
                  if (mounted) {
                    setState(() {
                      weatherData = weather;
                      weatherText = WeatherService.getWeatherContext(weather);
                    });
                    generateOutfit();
                  }
                } else {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("City not found")),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
            child: const Text("Search", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildStylingItemSelector() {
    if (wardrobeItems.isEmpty) {
      return const Text(
        "No items in wardrobe to select.",
        style: TextStyle(fontSize: 13, color: Colors.grey),
      );
    }

    if (selectedItemIds.isEmpty) {
      return GestureDetector(
        onTap: _openWardrobePicker,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAF7F2),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8E8)),
          ),
          child: const Column(
            children: [
              Icon(Icons.checkroom, color: Color(0xFF0F766E), size: 24),
              SizedBox(height: 6),
              Text(
                "Choose Specific Pieces",
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 2),
              Text(
                "AI will complete the outfit around selected pieces",
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    final selectedItems = selectedItemIds.map((id) {
      return wardrobeItems.firstWhere(
        (item) => (int.tryParse(item["id"]?.toString() ?? "") ?? 0) == id,
        orElse: () => null,
      );
    }).where((item) => item != null).toList();

    return SizedBox(
      height: 85,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: selectedItems.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return GestureDetector(
              onTap: _openWardrobePicker,
              child: Container(
                width: 75,
                margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0F766E)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: Color(0xFF0F766E), size: 18),
                    SizedBox(height: 4),
                    Text(
                      "Add More",
                      style: TextStyle(color: Color(0xFF0F766E), fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            );
          }

          final item = selectedItems[index - 1]!;
          final imagePath = item["image_path"]?.toString() ?? "";

          return Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 75,
                margin: const EdgeInsets.only(right: 10, top: 4, bottom: 4),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  image: DecorationImage(
                    image: NetworkImage(imagePath),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: const Color(0xFFEEEEEE)),
                ),
              ),
              Positioned(
                top: 0,
                right: 6,
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedItemIds.remove(int.tryParse(item["id"]?.toString() ?? "") ?? 0);
                    });
                    generateOutfit();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 10),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openWardrobePicker() async {
    final List<int>? result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) {
        List<int> tempSelected = List<int>.from(selectedItemIds);
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFFAF7F2),
              title: const Text("Select Wardrobe Anchors", style: TextStyle(fontWeight: FontWeight.bold)),
              content: wardrobeItems.isEmpty
                  ? const SizedBox(
                      height: 100,
                      child: Center(child: Text("No wardrobe items found.")),
                    )
                  : SizedBox(
                      width: double.maxFinite,
                      height: 350,
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 0.8,
                        ),
                        itemCount: wardrobeItems.length,
                        itemBuilder: (context, idx) {
                          final item = wardrobeItems[idx];
                          final id = int.tryParse(item["id"]?.toString() ?? "") ?? 0;
                          final imagePath = item["image_path"]?.toString() ?? "";
                          final subcat = item["subcategory"]?.toString() ?? item["category"]?.toString() ?? "";
                          final isSel = tempSelected.contains(id);

                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                if (isSel) {
                                  tempSelected.remove(id);
                                } else {
                                  tempSelected.add(id);
                                }
                              });
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel ? const Color(0xFF0F766E) : Colors.transparent,
                                  width: 2.5,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    Image.network(imagePath, fit: BoxFit.cover),
                                    Positioned(
                                      bottom: 0,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        padding: const EdgeInsets.symmetric(vertical: 2),
                                        child: Text(
                                          subcat,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontSize: 9),
                                        ),
                                      ),
                                    ),
                                    if (isSel)
                                      const Positioned(
                                        top: 4,
                                        right: 4,
                                        child: Icon(Icons.check_circle, color: Color(0xFF0F766E), size: 18),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, tempSelected),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F766E)),
                  child: const Text("Confirm", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        selectedItemIds = result;
      });
      generateOutfit();
    }
  }
}
