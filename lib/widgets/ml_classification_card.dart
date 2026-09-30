import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MLClassificationCard extends StatefulWidget {
  final int itemId;
  final String category;
  final String subcategory;
  final String season;
  final String color;
  final String initialOccasion;
  final ValueChanged<String>? onOccasionUpdated;

  const MLClassificationCard({
    super.key,
    required this.itemId,
    required this.category,
    required this.subcategory,
    required this.season,
    required this.color,
    this.initialOccasion = "",
    this.onOccasionUpdated,
  });

  @override
  State<MLClassificationCard> createState() => _MLClassificationCardState();
}

class _MLClassificationCardState extends State<MLClassificationCard> {
  bool _isLoading = true;
  String? _errorMessage;
  String _predictedOccasion = "Casual";
  double _confidence = 0.0;
  String _confidencePercentage = "0%";
  String _algorithm = "Decision Tree (scikit-learn)";
  String _explanation = "";
  Map<String, double> _probabilities = {};

  @override
  void initState() {
    super.initState();
    _fetchClassification();
  }

  Future<void> _fetchClassification() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await ApiService.classifyOccasion(
        category: widget.category,
        subcategory: widget.subcategory,
        season: widget.season,
        color: widget.color,
        itemId: widget.itemId > 0 ? widget.itemId : null,
      );

      if (!mounted) return;

      if (res != null && res["success"] == true) {
        final probsRaw = res["probabilities"] as Map<String, dynamic>? ?? {};
        final Map<String, double> parsedProbs = {};
        probsRaw.forEach((k, v) {
          parsedProbs[k] = (v as num).toDouble();
        });

        setState(() {
          _isLoading = false;
          _predictedOccasion = res["predicted_occasion"] ?? "Casual";
          _confidence = (res["confidence"] as num?)?.toDouble() ?? 0.0;
          _confidencePercentage = res["confidence_percentage"] ?? "${(_confidence * 100).toInt()}%";
          _algorithm = res["algorithm"] ?? "Decision Tree";
          _explanation = res["explanation"] ?? "";
          _probabilities = parsedProbs;
        });

        if (widget.onOccasionUpdated != null) {
          widget.onOccasionUpdated!(_predictedOccasion);
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = res?["message"] ?? "Could not run ML classification. Please try again.";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = "Network error: unable to reach ML classifier.";
      });
    }
  }

  Color _getOccasionColor(String occasion) {
    switch (occasion.toLowerCase()) {
      case "formal":
        return const Color(0xFF0F766E); // Deep Teal
      case "party":
        return const Color(0xFFE11D48); // Rose / Ruby
      case "casual":
      default:
        return const Color(0xFF2563EB); // Royal Blue
    }
  }

  IconData _getOccasionIcon(String occasion) {
    switch (occasion.toLowerCase()) {
      case "formal":
        return Icons.business_center_outlined;
      case "party":
        return Icons.celebration_outlined;
      case "casual":
      default:
        return Icons.local_cafe_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final occasionColor = _getOccasionColor(_predictedOccasion);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: const Icon(Icons.account_tree_outlined, size: 16, color: Color(0xFF16A34A)),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    "MACHINE LEARNING CLASSIFICATION",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _algorithm.contains("Decision Tree") ? "Decision Tree" : _algorithm,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                ),
              ),
            ],
          ),


          const SizedBox(height: 14),

          // Body: Loading, Error, or ML Output
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F766E)),
                  ),
                  SizedBox(width: 12),
                  Text(
                    "Evaluating clothing attributes with Decision Tree...",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 12, color: Colors.redAccent),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _fetchClassification,
                    icon: const Icon(Icons.refresh, size: 14),
                    label: const Text("Retry ML Classification", style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF0F766E),
                      side: const BorderSide(color: Color(0xFF0F766E)),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prediction Result Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: occasionColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: occasionColor.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getOccasionIcon(_predictedOccasion), size: 18, color: occasionColor),
                          const SizedBox(width: 6),
                          Text(
                            _predictedOccasion,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: occasionColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Model Confidence",
                                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                              ),
                              Text(
                                _confidencePercentage,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: occasionColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 5),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _confidence.clamp(0.0, 1.0),
                              minHeight: 6,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor: AlwaysStoppedAnimation<Color>(occasionColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Probability breakdown pills
                if (_probabilities.isNotEmpty) ...[
                  const Text(
                    "CLASS PROBABILITIES",
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF)),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: _probabilities.entries.map((entry) {
                      final isWinner = entry.key.toLowerCase() == _predictedOccasion.toLowerCase();
                      final pct = "${(entry.value * 100).toInt()}%";
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isWinner ? occasionColor.withOpacity(0.08) : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isWinner ? occasionColor.withOpacity(0.4) : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: Text(
                          "${entry.key}: $pct",
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                            color: isWinner ? occasionColor : const Color(0xFF6B7280),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                ],

                // Explanation rationale
                if (_explanation.isNotEmpty)
                  Text(
                    _explanation,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), height: 1.4),
                  ),

                const SizedBox(height: 8),

                // Algorithm Info footer & Re-classify action
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Trained on Scikit-Learn Decision Tree",
                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontStyle: FontStyle.italic),
                    ),
                    InkWell(
                      onTap: _fetchClassification,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Icon(Icons.refresh, size: 12, color: Color(0xFF0F766E)),
                            SizedBox(width: 3),
                            Text(
                              "Re-evaluate",
                              style: TextStyle(fontSize: 11, color: Color(0xFF0F766E), fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}
