// lib/main.dart — Doma Camote Classifier (UI v10 — final polish)
// Changes:
//   • Removed horizontal scanning line from Scan page.
//   • Made corner brackets thicker (strokeWidth 4.0).
//   • Minor UI polish for consistency.
//   • Save Detection button works; no auto‑save.
//   • Full dataset included.

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:camera/camera.dart';

List<CameraDescription> _cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  try {
    _cameras = await availableCameras();
  } catch (e) {
    debugPrint('Camera: $e');
  }
  runApp(const DomaApp());
}

// ============================================================================
// UNIFIED DESIGN TOKENS — GREEN PALETTE ONLY
// ============================================================================

class C {
  static const primary = Color(0xFF1A7A4C);
  static const primaryDark = Color(0xFF0F5233);
  static const primaryDeep = Color(0xFF0A3D26);
  static const primaryMid = Color(0xFF2ECC82);
  static const primarySoft = Color(0xFF4CAF7D);
  static const primaryLight = Color(0xFFE6F4ED);
  static const primaryTint = Color(0xFFF2FAF6);

  static const bg = Color(0xFFF6F7F9);
  static const surface = Color(0xFFFFFFFF);

  static const border = Color(0xFFE8ECF0);
  static const borderMid = Color(0xFFCDD3DA);

  static const textPrimary = Color(0xFF0F1923);
  static const textSec = Color(0xFF5A6475);
  static const textMuted = Color(0xFF9AA3B0);

  static const err = Color(0xFFD93025);
  static const errLight = Color(0xFFFEF1F0);
  static const warn = Color(0xFFCA8500);
  static const warnLight = Color(0xFFFFF8E6);

  static const white = Colors.white;
  static const camOverlayDark = Color(0xFF071A10);

  static const double radiusCard = 16.0;
  static const double radiusInner = 10.0;
  static const double radiusPill = 20.0;
  static const double paddingCard = 18.0;
  static const double paddingPage = 16.0;
}

// ============================================================================
// TYPOGRAPHY
// ============================================================================

class T {
  static const display = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w800,
    color: C.textPrimary,
    letterSpacing: -0.4,
    height: 1.15,
  );
  static const title = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    color: C.textPrimary,
    letterSpacing: -0.2,
  );
  static const heading = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: C.textPrimary,
  );
  static const subhead = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: C.textPrimary,
  );
  static const body = TextStyle(
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    color: C.textSec,
    height: 1.55,
  );
  static const caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: C.textMuted,
  );
  static const label = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.w600,
    color: C.textSec,
  );
}

// ============================================================================
// VARIETY ACCENTS
// ============================================================================

Color _accent(String cls) {
  switch (cls.toLowerCase()) {
    case 'minamon':
      return const Color(0xFFDE9F00);
    case 'tapol':
      return const Color(0xFF6B3BA9);
    case 'kadabaw':
      return const Color(0xFFC40950);
    case 'kadulaw':
      return const Color(0xFFD85C1C);
    default:
      return C.primary;
  }
}

Color _accentLight(String cls) => C.primaryLight;

IconData _varietyIcon(String cls) {
  switch (cls.toLowerCase()) {
    case 'kadulaw':
      return Icons.eco;
    case 'minamon':
      return Icons.spa;
    case 'kadabaw':
      return Icons.grass;
    case 'tapol':
      return Icons.local_florist;
    default:
      return Icons.eco;
  }
}

// ============================================================================
// DATA MODELS
// ============================================================================

class CamoteRecipe {
  final String name, description, prepTime, cookTime, difficulty, imagePath;
  final List<String> ingredients, steps, tips;
  final int servings, calories;
  const CamoteRecipe({
    required this.name,
    required this.description,
    required this.prepTime,
    required this.cookTime,
    required this.difficulty,
    required this.imagePath,
    required this.ingredients,
    required this.steps,
    required this.tips,
    required this.servings,
    required this.calories,
  });
}

class IntakeGuideline {
  final String dailyMax, weeklyMax, servingSize, bestTime;
  final List<String> limitations, cautions;
  const IntakeGuideline({
    required this.dailyMax,
    required this.weeklyMax,
    required this.servingSize,
    required this.bestTime,
    required this.limitations,
    required this.cautions,
  });
}

class MedicalInfo {
  final String glycemicIndex,
      glycemicLoad,
      fiber,
      potassium,
      vitaminA,
      vitaminC,
      calories100g,
      carbs100g;
  final List<String> medicinalUses, drugInteractions, contraindications;
  const MedicalInfo({
    required this.glycemicIndex,
    required this.glycemicLoad,
    required this.fiber,
    required this.potassium,
    required this.vitaminA,
    required this.vitaminC,
    required this.calories100g,
    required this.carbs100g,
    required this.medicinalUses,
    required this.drugInteractions,
    required this.contraindications,
  });
}

class CamoteVariety {
  final String name,
      commonName,
      scientificName,
      skinColor,
      fleshColor,
      shape,
      texture,
      imagePath,
      description;
  final List<String> benefits, dishes, imagePaths;
  final List<CamoteRecipe> recipes;
  final IntakeGuideline intake;
  final List<String> targetedPeople;
  final MedicalInfo medicalInfo;
  const CamoteVariety({
    required this.name,
    required this.commonName,
    required this.scientificName,
    required this.skinColor,
    required this.fleshColor,
    required this.shape,
    required this.texture,
    required this.imagePath,
    required this.description,
    required this.benefits,
    required this.dishes,
    required this.imagePaths,
    required this.recipes,
    required this.intake,
    required this.targetedPeople,
    required this.medicalInfo,
  });
}

// ============================================================================
// VARIETY DATA (FULL LIST)
// ============================================================================

const List<CamoteVariety> camoteVarieties = [
  // ── KADULAW (Orange) ──────────────────────────────────────────────────────
  CamoteVariety(
    name: 'Kadulaw',
    commonName: 'Orange Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Light orange to peach',
    fleshColor: 'Deep orange',
    shape: 'Elongated / Fusiform',
    texture: 'Smooth / Firm',
    imagePath: 'assets/images/orange_camote.jpg',
    description:
        'Light-orange to peach skin with vibrant deep-orange flesh. '
        'The variety highest in beta-carotene, important for vision, '
        'immune function, and skin health.',
    benefits: [
      'Exceptional beta-carotene source (>900 µg RAE/100 g)',
      'High antioxidant capacity',
      'Supports immune function via vitamin A and C',
      'Promotes healthy skin and vision',
      'Manganese supports bone metabolism',
      'Potassium supports healthy blood pressure',
    ],
    dishes: [
      'Camote Cue',
      'Camote Fries',
      'Steamed Camote',
      'Ginataang Bilo-Bilo',
      'Sweet Potato Pie',
    ],
    imagePaths: [
      'assets/images/orange_camote.jpg',
      'assets/images/kadulaw2.png',
      'assets/images/kadulaw3.png',
      'assets/images/kadulaw4.png',
      'assets/images/kadulaw5.png',
    ],
    recipes: [
      CamoteRecipe(
        name: 'Classic Camote Cue',
        description: 'Caramelised camote skewers — the classic street snack.',
        prepTime: '10 min',
        cookTime: '20 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/kadulaw2.png',
        servings: 4,
        calories: 210,
        ingredients: [
          '500 g Kadulaw camote, peeled & sliced 1-inch thick',
          '½ cup brown sugar',
          '2 cups cooking oil',
          'Bamboo skewers',
        ],
        steps: [
          'Peel and cut camote into 1-inch thick rounds.',
          'Heat oil in a deep pan over medium heat.',
          'Fry camote slices until golden, about 8 minutes.',
          'Sprinkle brown sugar and let it melt into the oil.',
          'Turn each piece to coat evenly with caramel.',
          'Skewer while warm and serve immediately.',
        ],
        tips: [
          'Use firm camote — soft pieces disintegrate in hot oil.',
          'Do not overcrowd the pan; fry in batches.',
        ],
      ),
      CamoteRecipe(
        name: 'Orange Camote Soup',
        description: 'Velvety soup with ginger and coconut milk.',
        prepTime: '15 min',
        cookTime: '30 min',
        difficulty: 'Medium',
        imagePath: 'assets/images/kadulaw3.png',
        servings: 4,
        calories: 185,
        ingredients: [
          '600 g Kadulaw camote, cubed',
          '1 can (400 ml) coconut milk',
          '1 tsp fresh ginger, grated',
          '1 onion, roughly chopped',
          '2 cloves garlic, minced',
          '2 cups vegetable broth',
          'Salt and pepper to taste',
        ],
        steps: [
          'Sauté onion and garlic until fragrant.',
          'Add camote cubes and ginger; stir 2 minutes.',
          'Pour in broth; simmer 20 minutes until soft.',
          'Blend smooth with an immersion blender.',
          'Stir in coconut milk; season with salt and pepper.',
          'Simmer 5 more minutes and serve hot.',
        ],
        tips: [
          'Add chili flakes for a spicy lift.',
          'Garnish with toasted coconut and pumpkin seeds.',
        ],
      ),
      CamoteRecipe(
        name: 'Baked Camote Fries & Garlic Aioli',
        description: 'Crispy oven fries with a 2-ingredient aioli dip.',
        prepTime: '10 min',
        cookTime: '35 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/kadulaw4.png',
        servings: 3,
        calories: 195,
        ingredients: [
          '400 g Kadulaw camote, cut into sticks',
          '2 tbsp olive oil',
          '1 tsp smoked paprika',
          '½ tsp garlic powder',
          'Salt to taste',
          '3 tbsp mayonnaise + 1 garlic clove (aioli)',
        ],
        steps: [
          'Preheat oven to 220 °C (425 °F).',
          'Toss camote sticks with oil, paprika, garlic powder, and salt.',
          'Spread in a single layer on a lined baking sheet.',
          'Bake 30–35 minutes, flipping halfway, until crispy.',
          'Mix mayo with minced garlic for aioli.',
          'Serve hot with aioli on the side.',
        ],
        tips: ['Pat dry before oiling — moisture prevents crispiness.'],
      ),
    ],
    intake: IntakeGuideline(
      dailyMax: '150–200 g (1 medium camote)',
      weeklyMax: '700–900 g (4–5 servings/week)',
      servingSize: '100–150 g per serving',
      bestTime: 'Morning or midday, with a meal containing some fat',
      limitations: [
        'Diabetics: limit to 1 serving/day and monitor glucose',
        'Low-potassium diet: consult your doctor first',
        'Daily excess may cause harmless skin yellowing',
        'Limit if prone to calcium-oxalate kidney stones',
      ],
      cautions: [
        'Medium GI (44–61) — pair with protein or fat',
        'High fibre — increase intake gradually',
        'Potassium-restricted diets need medical guidance',
      ],
    ),
    targetedPeople: [
      'Children — vitamin A supports vision and immunity',
      'Pregnant women — provitamin A supports fetal development',
      'Older adults — antioxidants reduce oxidative aging',
      'Athletes — sustained energy from complex carbs',
      'People with vitamin A deficiency',
      'Individuals with iron-deficiency anaemia',
    ],
    medicalInfo: MedicalInfo(
      glycemicIndex: '44–61 (Medium)',
      glycemicLoad: '≈10.8 per 100 g',
      fiber: '3.0 g / 100 g',
      potassium: '337 mg / 100 g',
      vitaminA: '961 µg RAE / 100 g (107% DV)',
      vitaminC: '2.4 mg / 100 g',
      calories100g: '86 kcal',
      carbs100g: '20.1 g',
      medicinalUses: [
        'Supports night vision, prevents vitamin A deficiency',
        'Anti-inflammatory properties',
        'Potassium helps regulate blood pressure',
        'Fibre promotes gut motility and microbiome diversity',
        'Antioxidants may reduce chronic disease risk',
      ],
      drugInteractions: [
        'Beta-blockers: elevated potassium may interact',
        'Warfarin: vitamin K content may affect anticoagulation',
        'Insulin/oral hypoglycaemics: monitor glucose closely',
      ],
      contraindications: [
        'Hyperkalaemia (high blood potassium) — limit quantity',
        'Chronic kidney disease — potassium restriction often needed',
        'Hypervitaminosis A — rare with food sources alone',
      ],
    ),
  ),

  // ── MINAMON (Yellow) ──────────────────────────────────────────────────────
  CamoteVariety(
    name: 'Minamon',
    commonName: 'Yellow Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Yellow to tan',
    fleshColor: 'Bright yellow',
    shape: 'Bent / Curved',
    texture: 'Lumpy / Slightly Gritty',
    imagePath: 'assets/images/yellow_camote.jpg',
    description:
        'Yellow-to-tan skin, characteristically curved shape, bright yellow '
        'flesh with mild, earthy sweetness. Rich in complex carbohydrates '
        'and fibre — the go-to energy staple.',
    benefits: [
      'Complex carbs provide long-lasting energy',
      'High fibre supports digestion and cholesterol',
      'Potassium supports cardiovascular health',
      'Prebiotic fibre nourishes gut bacteria',
      'Manganese supports bone metabolism',
      'Filling yet weight-friendly',
    ],
    dishes: [
      'Camote Cue',
      'Nilupak',
      'Minatamis na Camote',
      'Nilagang Camote',
      'Camote Porridge',
    ],
    imagePaths: [
      'assets/images/yellow_camote.jpg',
      'assets/images/minamon2.png',
      'assets/images/minamon3.png',
      'assets/images/minamon4.png',
      'assets/images/minamon5.png',
    ],
    recipes: [
      CamoteRecipe(
        name: 'Nilupak (Camote Mash)',
        description: 'Traditional mashed camote with margarine and milk.',
        prepTime: '5 min',
        cookTime: '25 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/minamon2.png',
        servings: 6,
        calories: 175,
        ingredients: [
          '500 g Minamon camote, boiled and peeled',
          '3 tbsp margarine or butter',
          '4 tbsp sweetened condensed milk',
          'Grated fresh coconut for topping',
          'Pinch of salt',
        ],
        steps: [
          'Boil camote until very soft, about 20 minutes.',
          'Peel and mash while still hot.',
          'Mix in margarine, condensed milk, and salt.',
          'Shape into oval mounds using plastic wrap.',
          'Top with grated fresh coconut.',
          'Serve warm on banana leaves.',
        ],
        tips: [
          'Fresh coconut gives authentic texture.',
          'Serve on banana leaves for a traditional touch.',
        ],
      ),
      CamoteRecipe(
        name: 'Minatamis na Camote',
        description: 'Sweet camote simmered in pandan syrup.',
        prepTime: '10 min',
        cookTime: '30 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/minamon3.png',
        servings: 4,
        calories: 230,
        ingredients: [
          '400 g Minamon camote, cut into 2-inch cubes',
          '1 cup white sugar',
          '2 cups water',
          '2 pandan leaves, knotted',
          '1 tsp vanilla extract',
        ],
        steps: [
          'Boil sugar and water, stirring until dissolved.',
          'Add pandan leaves and vanilla.',
          'Add camote cubes; simmer 25 minutes on low heat.',
          'Simmer until pieces turn slightly translucent.',
          'Serve warm or chilled.',
        ],
        tips: [
          'Add saba banana for extra flavour.',
          'Refrigerate leftovers up to 3 days.',
        ],
      ),
      CamoteRecipe(
        name: 'Ginger Camote Porridge',
        description: 'Hearty congee-style breakfast with ginger.',
        prepTime: '10 min',
        cookTime: '40 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/minamon4.png',
        servings: 4,
        calories: 155,
        ingredients: [
          '300 g Minamon camote, diced small',
          '1 cup glutinous rice, rinsed',
          '5 cups water or chicken broth',
          '1 tbsp fresh ginger, sliced',
          'Spring onions and toasted garlic to garnish',
          'Fish sauce to taste',
        ],
        steps: [
          'Bring rinsed rice and liquid to a boil.',
          'Add ginger and camote cubes.',
          'Simmer 35 minutes, stirring frequently.',
          'Season with fish sauce to taste.',
          'Top with spring onions and toasted garlic.',
          'Serve hot with calamansi wedges.',
        ],
        tips: ['Add more water if porridge thickens too much.'],
      ),
    ],
    intake: IntakeGuideline(
      dailyMax: '150–200 g (1 medium camote)',
      weeklyMax: '600–800 g (4 servings/week)',
      servingSize: '100–150 g per serving',
      bestTime: 'Morning — complex carbs fuel the day',
      limitations: [
        'Diabetics: limit to ½ serving with protein',
        'Avoid using as sole carb source long-term',
        'Increase fibre intake gradually',
        'Not suitable for infants under 6 months',
      ],
      cautions: [
        'Cook thoroughly — raw camote is hard to digest',
        'Avoid repeated deep frying in the same oil',
        'Watch portions on calorie-restricted plans',
      ],
    ),
    targetedPeople: [
      'Students & young adults — sustained brain fuel',
      'Manual workers — reliable physical energy',
      'People with sluggish digestion',
      'Individuals managing high cholesterol',
      'Vegetarians and vegans',
      'Seniors experiencing constipation',
    ],
    medicalInfo: MedicalInfo(
      glycemicIndex: '44–61 (Medium)',
      glycemicLoad: '≈11.0 per 100 g',
      fiber: '3.3 g / 100 g',
      potassium: '337 mg / 100 g',
      vitaminA: '4 µg RAE / 100 g',
      vitaminC: '2.4 mg / 100 g',
      calories100g: '86 kcal',
      carbs100g: '20.1 g',
      medicinalUses: [
        'Regulates bowel movement via fibre',
        'Helps maintain healthy cholesterol levels',
        'Prebiotic effect supports gut microbiome',
        'Stable blood sugar via low glycaemic load',
        'Potassium supports muscle function',
      ],
      drugInteractions: [
        'Laxatives: added fibre may intensify effect',
        'Anti-diabetic medications: may need dose adjustment',
        'ACE inhibitors: monitor potassium levels',
      ],
      contraindications: [
        'IBS — high fibre may worsen symptoms',
        'Fructose malabsorption — may cause gas and bloating',
        'Bowel obstruction — high-fibre foods contraindicated',
      ],
    ),
  ),

  // ── TAPOL (White/Purple flesh) ────────────────────────────────────────────
  CamoteVariety(
    name: 'Tapol',
    commonName: 'White Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'White to cream',
    fleshColor: 'Pale purple to white',
    shape: 'Round / Oblong',
    texture: 'Smooth / Firm',
    imagePath: 'assets/images/white_camote.jpg',
    description:
        'White-to-cream skin, round shape, mild flavour — the most versatile '
        'of the four varieties. Has the lowest glycaemic index, making it '
        'ideal for blood sugar management.',
    benefits: [
      'Lowest glycaemic index of the four varieties',
      'Mild flavour, very versatile for cooking',
      'Easy to digest',
      'Manganese and copper support bone density',
      'Iron contributes to red blood cell production',
      'Good for convalescent and post-operative diets',
    ],
    dishes: [
      'Turon na Camote',
      'White Camote Pastry',
      'Camote Pie',
      'Camote Halaya',
      'White Camote Dumplings',
    ],
    imagePaths: [
      'assets/images/white_camote.jpg',
      'assets/images/tapol2.png',
      'assets/images/tapol3.png',
      'assets/images/tapol4.png',
      'assets/images/tapol5.png',
    ],
    recipes: [
      CamoteRecipe(
        name: 'Camote Halaya',
        description: 'Smooth, creamy camote jam — a dessert classic.',
        prepTime: '15 min',
        cookTime: '45 min',
        difficulty: 'Medium',
        imagePath: 'assets/images/tapol2.png',
        servings: 8,
        calories: 145,
        ingredients: [
          '500 g Tapol camote, boiled and mashed',
          '1 can sweetened condensed milk',
          '1 can (400 ml) coconut milk',
          '½ cup unsalted butter',
          '½ cup sugar',
          'Pinch of salt',
        ],
        steps: [
          'Boil and mash camote until completely smooth.',
          'Combine with condensed milk in a heavy pan.',
          'Cook over medium heat, stirring constantly.',
          'Add coconut milk, butter, and sugar.',
          'Stir 30–35 minutes until it pulls from the pan.',
          'Pour into greased molds; cool before unmolding.',
        ],
        tips: [
          'Never stop stirring — the bottom burns quickly.',
          'Grease molds with butter before pouring.',
        ],
      ),
      CamoteRecipe(
        name: 'Turon na Camote',
        description: 'Crispy wrapper filled with camote and jackfruit.',
        prepTime: '20 min',
        cookTime: '15 min',
        difficulty: 'Medium',
        imagePath: 'assets/images/tapol3.png',
        servings: 5,
        calories: 220,
        ingredients: [
          '300 g Tapol camote, boiled and cut into fingers',
          '100 g jackfruit strips (langka)',
          '10 lumpia wrappers',
          '½ cup brown sugar',
          'Cooking oil for frying',
        ],
        steps: [
          'Sprinkle brown sugar across a flat lumpia wrapper.',
          'Place camote and jackfruit in the middle.',
          'Roll tightly, seal edges with water.',
          'Fry in hot oil until golden, 4–5 minutes.',
          'Drain and roll in remaining caramelised sugar.',
        ],
        tips: [
          'Seal rolls tightly to keep oil out.',
          'Use firm, not mushy, camote.',
        ],
      ),
      CamoteRecipe(
        name: 'Camote Pie Cups',
        description: 'Custard tart cups with silky camote filling.',
        prepTime: '25 min',
        cookTime: '35 min',
        difficulty: 'Hard',
        imagePath: 'assets/images/tapol4.png',
        servings: 12,
        calories: 195,
        ingredients: [
          '400 g Tapol camote, steamed and mashed',
          '2 large eggs',
          '½ cup sugar',
          '¼ cup butter, melted',
          '½ cup evaporated milk',
          '1 tsp vanilla extract',
          '12 pre-made tart shells',
        ],
        steps: [
          'Preheat oven to 180 °C (350 °F).',
          'Beat camote, eggs, sugar, butter, milk, vanilla smooth.',
          'Taste and adjust sweetness.',
          'Spoon filling into tart shells.',
          'Bake 30–35 minutes until set and golden.',
          'Cool completely before serving.',
        ],
        tips: ['Taste filling before baking and adjust sweetness.'],
      ),
    ],
    intake: IntakeGuideline(
      dailyMax: '150–250 g (1–2 servings)',
      weeklyMax: '800 g – 1 kg (5–6 servings/week)',
      servingSize: '100–150 g per serving',
      bestTime: 'Any meal — low GI suits any time of day',
      limitations: [
        'Safe for most people in moderate amounts',
        'May tolerate slightly larger portions than other varieties',
        'Avoid as sole carbohydrate source long-term',
      ],
      cautions: [
        'Always cook thoroughly before eating',
        'Avoid frequent deep-frying',
        'Rare nightshade-family sensitivity — monitor tolerance',
      ],
    ),
    targetedPeople: [
      'Diabetics — lowest glycaemic impact of the four',
      'Children recovering from illness',
      'Elderly with sensitive digestion',
      'Individuals on weight management plans',
      'People with mild IBS',
      'Post-operative patients',
    ],
    medicalInfo: MedicalInfo(
      glycemicIndex: '41–55 (Low to Medium)',
      glycemicLoad: '≈8.5 per 100 g',
      fiber: '2.5 g / 100 g',
      potassium: '296 mg / 100 g',
      vitaminA: '2 µg RAE / 100 g',
      vitaminC: '2.0 mg / 100 g',
      calories100g: '76 kcal',
      carbs100g: '17.6 g',
      medicinalUses: [
        'Ideal for blood sugar management',
        'Manganese and copper support bone density',
        'Gentle prebiotic effect',
        'Iron aids red blood cell production',
        'Suitable for recovery-phase diets',
      ],
      drugInteractions: [
        'Generally low risk of drug interactions',
        'Iron supplements: space apart from high-fibre meals',
        'Diabetes medications: favourable dietary adjunct',
      ],
      contraindications: [
        'Rare oxalate sensitivity — may affect kidney stones',
        'Large quantities may cause mild gas',
      ],
    ),
  ),

  // ── KADABAW (Purple skin) ──────────────────────────────────────────────────
  CamoteVariety(
    name: 'Kadabaw',
    commonName: 'Violet Sweet Potato',
    scientificName: 'Ipomoea batatas',
    skinColor: 'Purple to reddish-violet',
    fleshColor: 'Yellow to cream',
    shape: 'Irregular',
    texture: 'Rough / Rustic',
    imagePath: 'assets/images/purple_camote.jpg',
    description:
        'Striking violet skin with contrasting yellow-cream flesh. Highest '
        'in anthocyanins among the four varieties — antioxidants studied for '
        'brain, heart, and cancer-preventive benefits.',
    benefits: [
      'Highest in anthocyanins of the four varieties',
      'Strong anti-inflammatory properties',
      'Supports cognitive health',
      'Reduces cardiovascular risk markers',
      'Studied for cancer-preventive properties',
      'Helps lower systemic inflammation',
    ],
    dishes: [
      'Camote Mash',
      'Nilagang Camote',
      'Minatamis na Camote',
      'Camote Cue',
      'Boiled Camote',
    ],
    imagePaths: [
      'assets/images/purple_camote.jpg',
      'assets/images/kadabaw2.png',
      'assets/images/kadabaw3.png',
      'assets/images/kadabaw4.png',
      'assets/images/kadabaw5.png',
    ],
    recipes: [
      CamoteRecipe(
        name: 'Roasted Kadabaw Salad',
        description: 'Roasted camote on greens with honey-calamansi dressing.',
        prepTime: '15 min',
        cookTime: '25 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/kadabaw2.png',
        servings: 4,
        calories: 165,
        ingredients: [
          '350 g Kadabaw camote, cubed',
          '2 cups mixed greens',
          '¼ red onion, thinly sliced',
          '2 tbsp olive oil',
          '2 tbsp calamansi or lemon juice',
          '1 tsp honey',
          'Salt and pepper',
          'Toasted pumpkin seeds to garnish',
        ],
        steps: [
          'Preheat oven to 200 °C (390 °F).',
          'Toss camote with 1 tbsp oil, salt, and pepper.',
          'Roast 20–25 minutes until caramelised at the edges.',
          'Whisk remaining oil, calamansi juice, and honey.',
          'Arrange greens and onion on a platter.',
          'Top with camote; drizzle dressing, add pumpkin seeds.',
        ],
        tips: [
          'Add crumbled feta for a salty contrast.',
          'Dress just before serving.',
        ],
      ),
      CamoteRecipe(
        name: 'Nilagang Kadabaw',
        description: 'Boiled camote in savoury broth with leafy greens.',
        prepTime: '10 min',
        cookTime: '35 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/kadabaw3.png',
        servings: 4,
        calories: 145,
        ingredients: [
          '400 g Kadabaw camote, cut into chunks',
          '200 g beef or pork (optional)',
          '1 onion, quartered',
          '3 cups water or broth',
          '1 cup pechay or cabbage',
          'Fish sauce and pepper to taste',
          'Spring onions to garnish',
        ],
        steps: [
          'Boil water/broth with onion.',
          'Add meat if using; simmer 20 minutes.',
          'Add camote; simmer 15 more minutes.',
          'Add leafy greens in the last 3 minutes.',
          'Season with fish sauce and pepper.',
          'Garnish with spring onions and serve hot.',
        ],
        tips: ['A vegetable-only version works just as well.'],
      ),
      CamoteRecipe(
        name: 'Anthocyanin Smoothie Bowl',
        description: 'Frozen bowl harnessing Kadabaw\'s antioxidants.',
        prepTime: '10 min',
        cookTime: '0 min',
        difficulty: 'Easy',
        imagePath: 'assets/images/kadabaw4.png',
        servings: 2,
        calories: 175,
        ingredients: [
          '200 g Kadabaw camote, boiled and frozen',
          '1 ripe banana, frozen',
          '½ cup coconut milk',
          '1 tbsp chia seeds',
          'Fresh fruits, granola, and honey to top',
        ],
        steps: [
          'Blend frozen camote, banana, and coconut milk until thick.',
          'Pour into bowls.',
          'Top with fresh fruits, granola, and chia seeds.',
          'Drizzle with honey and serve immediately.',
        ],
        tips: [
          'Freeze camote the night before.',
          'Use less coconut milk for a thicker consistency.',
        ],
      ),
    ],
    intake: IntakeGuideline(
      dailyMax: '150–200 g (1 medium camote)',
      weeklyMax: '700–900 g (4–5 servings/week)',
      servingSize: '100–150 g per serving',
      bestTime: 'Morning or lunch',
      limitations: [
        'Very high daily intake may mildly stain teeth',
        'On blood thinners: monitor intake',
        'Limit if prone to calcium-oxalate kidney stones',
        'Phytates may reduce iron absorption when eaten together',
      ],
      cautions: [
        'Wash rough skin thoroughly before cooking',
        'Do not eat raw',
        'Safe for pregnant women in normal servings',
      ],
    ),
    targetedPeople: [
      'Adults 40+ — supports cognitive aging',
      'People at risk of heart disease',
      'Cancer-risk reduction focus',
      'Athletes — anti-inflammatory recovery aid',
      'Individuals with metabolic syndrome',
      'High oxidative-stress populations (e.g. smokers)',
    ],
    medicalInfo: MedicalInfo(
      glycemicIndex: '44–61 (Medium)',
      glycemicLoad: '≈10.5 per 100 g',
      fiber: '3.0 g / 100 g',
      potassium: '345 mg / 100 g',
      vitaminA: '5 µg RAE / 100 g',
      vitaminC: '2.5 mg / 100 g',
      calories100g: '88 kcal',
      carbs100g: '20.5 g',
      medicinalUses: [
        'May reduce neuroinflammation and support memory',
        'May lower LDL cholesterol',
        'Anti-tumour properties studied (in vitro)',
        'Reduces systemic inflammation markers',
        'Supports liver antioxidant pathways',
      ],
      drugInteractions: [
        'Anticoagulants: mild effect — monitor INR',
        'Chemotherapy: discuss antioxidant timing with oncologist',
        'Anti-platelet drugs: cumulative effect possible',
      ],
      contraindications: [
        'Calcium-oxalate kidney stones — limit oxalate-rich foods',
        'Severe iron-deficiency anaemia',
        'Known Ipomoea batatas allergy (very rare)',
      ],
    ),
  ),
];

// ============================================================================
// DETECTION MODELS (unchanged)
// ============================================================================

class _Det {
  final Rect box;
  final int cls;
  final double score;
  const _Det(this.box, this.cls, this.score);
}

class _ScanResult {
  final DetectionResult? winner;
  final _ScanState state;
  const _ScanResult({this.winner, this.state = _ScanState.ok});
  bool get found => winner != null && state == _ScanState.ok;
}

enum _ScanState { ok, notFound, multipleVariants }

class DetectionResult {
  final String className;
  final double confidence, x, y, width, height;
  DetectionResult({
    required this.className,
    required this.confidence,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  Map<String, dynamic> toJson() => {
    'className': className,
    'confidence': confidence,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
  factory DetectionResult.fromJson(Map<String, dynamic> j) => DetectionResult(
    className: j['className'],
    confidence: j['confidence'],
    x: j['x'],
    y: j['y'],
    width: j['width'],
    height: j['height'],
  );
}

class DetectionLog {
  final String id, imagePath;
  final List<DetectionResult> results;
  final DateTime timestamp;
  DetectionLog({
    required this.id,
    required this.imagePath,
    required this.results,
    required this.timestamp,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'imagePath': imagePath,
    'results': results.map((r) => r.toJson()).toList(),
    'timestamp': timestamp.toIso8601String(),
  };
  factory DetectionLog.fromJson(Map<String, dynamic> j) => DetectionLog(
    id: j['id'],
    imagePath: j['imagePath'],
    results: (j['results'] as List)
        .map((r) => DetectionResult.fromJson(r))
        .toList(),
    timestamp: DateTime.parse(j['timestamp']),
  );
}

class DetectionLogger {
  static const _k = 'detection_logs';
  static Future<void> save(DetectionLog log) async {
    final p = await SharedPreferences.getInstance();
    final l = p.getStringList(_k) ?? [];
    l.insert(0, jsonEncode(log.toJson()));
    await p.setStringList(_k, l);
  }

  static Future<List<DetectionLog>> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(_k) ?? [];
    final result = <DetectionLog>[];
    for (final s in raw) {
      try {
        result.add(DetectionLog.fromJson(jsonDecode(s)));
      } catch (e) {
        debugPrint('[Doma] skip corrupt log: $e');
      }
    }
    return result;
  }

  static Future<void> delete(String id) async {
    final p = await SharedPreferences.getInstance();
    final l = (p.getStringList(_k) ?? [])
        .where((s) => DetectionLog.fromJson(jsonDecode(s)).id != id)
        .toList();
    await p.setStringList(_k, l);
  }

  static Future<void> clearAll() async =>
      (await SharedPreferences.getInstance()).remove(_k);
}

// ============================================================================
// RESHAPE HELPER (unchanged)
// ============================================================================

extension ReshapeF on Float32List {
  List<dynamic> r4(List<int> s) {
    final b = s[0], h = s[1], w = s[2], c = s[3];
    return List.generate(
      b,
      (_) => List.generate(
        h,
        (y) => List.generate(
          w,
          (x) => List.generate(
            c,
            (ch) => this[(y * w + x) * c + ch],
            growable: false,
          ),
          growable: false,
        ),
        growable: false,
      ),
      growable: false,
    );
  }
}

// ============================================================================
// CLASSIFIER (unchanged)
// ============================================================================

class CamoteClassifier {
  Interpreter? _interp;
  int _inSz = 640;

  static const double _rawGate = 0.70;
  static const double _displayGate = 0.70;
  static const double _iouThres = 0.45;
  static const double _minAspect = 0.25;
  static const double _maxAspect = 4.0;
  static const double _minArea = 0.02;
  static const double _maxArea = 0.90;
  static const List<String> labels = ['kadabaw', 'kadulaw', 'minamon', 'tapol'];

  Future<void> loadModel() async {
    try {
      _interp = await Interpreter.fromAsset(
        'assets/best_float32.tflite',
        options: InterpreterOptions()
          ..threads = 4
          ..useNnApiForAndroid = true,
      );
      final inShape = _interp!.getInputTensor(0).shape;
      if (inShape.length == 4 && inShape[1] > 0) _inSz = inShape[1];
    } catch (e) {
      debugPrint('[Doma] load err: $e');
    }
  }

  void dispose() => _interp?.close();

  Future<_ScanResult> detect(File f) async {
    try {
      if (_interp == null) await loadModel();
      if (_interp == null) return const _ScanResult(state: _ScanState.notFound);
      final bytes = await f.readAsBytes();
      if (bytes.isEmpty) return const _ScanResult(state: _ScanState.notFound);
      img.Image? im = img.decodeImage(bytes);
      if (im == null || im.width < 32 || im.height < 32)
        return const _ScanResult(state: _ScanState.notFound);
      im = _enhance(im);
      return _infer(im);
    } catch (e, st) {
      debugPrint('[Doma] detect err: $e\n$st');
      return const _ScanResult(state: _ScanState.notFound);
    }
  }

  img.Image _enhance(img.Image src) {
    const maxDim = 1920;
    img.Image p = src;
    if (src.width > maxDim || src.height > maxDim) {
      final s = maxDim / math.max(src.width, src.height);
      p = img.copyResize(
        src,
        width: (src.width * s).round(),
        height: (src.height * s).round(),
        interpolation: img.Interpolation.linear,
      );
    }
    double sR = 0, sG = 0, sB = 0;
    int cnt = 0;
    for (int y = 0; y < p.height; y += 4)
      for (int x = 0; x < p.width; x += 4) {
        final px = p.getPixel(x, y);
        sR += px.r.toDouble();
        sG += px.g.toDouble();
        sB += px.b.toDouble();
        cnt++;
      }
    final avg = (sR + sG + sB) / (cnt * 3.0);
    final bF = avg < 100
        ? 1.04
        : avg > 180
        ? 1.01
        : 1.02;
    final cF = avg < 100
        ? 1.10
        : avg > 180
        ? 1.04
        : 1.06;
    final out = img.Image(width: p.width, height: p.height);
    for (int y = 0; y < p.height; y++)
      for (int x = 0; x < p.width; x++) {
        final px = p.getPixel(x, y);
        double r = px.r.toDouble() * bF,
            g = px.g.toDouble() * bF,
            b = px.b.toDouble() * bF;
        r = 128 + (r - 128) * cF;
        g = 128 + (g - 128) * cF;
        b = 128 + (b - 128) * cF;
        out.setPixel(
          x,
          y,
          img.ColorRgb8(
            r.clamp(0, 255).round(),
            g.clamp(0, 255).round(),
            b.clamp(0, 255).round(),
          ),
        );
      }
    return out;
  }

  Float32List _letterbox(img.Image im) {
    final sz = _inSz, w = im.width, h = im.height;
    final out = Float32List(sz * sz * 3);
    final sc = math.min(sz / w, sz / h);
    final nW = (w * sc).floor(), nH = (h * sc).floor();
    final pX = ((sz - nW) / 2).floor(), pY = ((sz - nH) / 2).floor();
    const pv = 114.0 / 255.0;
    final inv = 1.0 / sc;
    for (int y = 0; y < sz; y++)
      for (int x = 0; x < sz; x++) {
        final p = (y * sz + x) * 3;
        if (x < pX || x >= pX + nW || y < pY || y >= pY + nH) {
          out[p] = pv;
          out[p + 1] = pv;
          out[p + 2] = pv;
        } else {
          final sx = (x - pX) * inv, sy = (y - pY) * inv;
          final x0 = math.max(0, math.min(w - 1, (sx - 0.5).floor()));
          final y0 = math.max(0, math.min(h - 1, (sy - 0.5).floor()));
          final x1 = math.max(0, math.min(w - 1, x0 + 1));
          final y1 = math.max(0, math.min(h - 1, y0 + 1));
          final fx = (sx - x0 - 0.5).clamp(0.0, 1.0),
              fy = (sy - y0 - 0.5).clamp(0.0, 1.0);
          final q00 = im.getPixel(x0, y0), q10 = im.getPixel(x1, y0);
          final q01 = im.getPixel(x0, y1), q11 = im.getPixel(x1, y1);
          double bi(a, b, c, d) =>
              (a * (1 - fx) * (1 - fy) +
                      b * fx * (1 - fy) +
                      c * (1 - fx) * fy +
                      d * fx * fy)
                  .clamp(0, 255);
          out[p] = bi(q00.r, q10.r, q01.r, q11.r) / 255.0;
          out[p + 1] = bi(q00.g, q10.g, q01.g, q11.g) / 255.0;
          out[p + 2] = bi(q00.b, q10.b, q01.b, q11.b) / 255.0;
        }
      }
    return out;
  }

  _ScanResult _infer(img.Image image) {
    final nCls = labels.length;
    final input = _letterbox(image);
    final oShape = _interp!.getOutputTensor(0).shape;
    final isSimple =
        oShape.length == 3 &&
        (oShape[2] == 6 || (oShape[1] == 6 && oShape[2] > 6));
    final raw = isSimple
        ? _decodeSimple(oShape, input)
        : _decodeYolo(oShape, nCls, input);
    final mapped = _unmap(raw, image.width.toDouble(), image.height.toDouble());
    final nmsed = _nms(mapped);
    if (nmsed.isEmpty) return const _ScanResult(state: _ScanState.notFound);
    final classes = nmsed.map((d) => d.cls).toSet();
    if (classes.length > 1)
      return const _ScanResult(state: _ScanState.multipleVariants);
    final w = nmsed.first;
    if (w.score < _displayGate)
      return const _ScanResult(state: _ScanState.notFound);
    final r = DetectionResult(
      className: labels[w.cls.clamp(0, labels.length - 1)],
      confidence: w.score,
      x: w.box.left,
      y: w.box.top,
      width: w.box.width,
      height: w.box.height,
    );
    return _ScanResult(winner: r, state: _ScanState.ok);
  }

  List<_Det> _decodeYolo(List<int> shape, int nCls, Float32List input) {
    final sz = _inSz, CC = 4 + nCls;
    late bool tr;
    late int N;
    if (shape.length == 3 && shape[1] == CC) {
      tr = true;
      N = shape[2];
    } else if (shape.length == 3 && shape[2] == CC) {
      tr = false;
      N = shape[1];
    } else if (shape.length == 2 && shape[1] == CC) {
      tr = false;
      N = shape[0];
    } else {
      tr = true;
      N = shape.length == 3 ? shape[2] : shape[0];
    }
    final buf = tr
        ? List.generate(
            1,
            (_) => List.generate(CC, (_) => List<double>.filled(N, 0.0)),
          )
        : List.generate(
            1,
            (_) => List.generate(N, (_) => List<double>.filled(CC, 0.0)),
          );
    _interp!.run(input.r4([1, sz, sz, 3]), buf);
    List<List<double>> preds;
    if (tr) {
      preds = List.generate(N, (i) => List<double>.filled(CC, 0.0));
      for (int c = 0; c < CC; c++)
        for (int n = 0; n < N; n++) preds[n][c] = buf[0][c][n];
    } else {
      preds = buf[0].cast<List<double>>();
    }
    return _parse(preds, nCls, sz);
  }

  List<_Det> _decodeSimple(List<int> shape, Float32List input) {
    final sz = _inSz;
    late int rows;
    late bool cf;
    if (shape.length == 3 && shape[2] == 6) {
      rows = shape[1];
      cf = false;
    } else {
      rows = shape[2];
      cf = true;
    }
    final buf = List.generate(
      1,
      (_) => cf
          ? List.generate(6, (_) => List<double>.filled(rows, 0.0))
          : List.generate(rows, (_) => List<double>.filled(6, 0.0)),
    );
    _interp!.run(input.r4([1, sz, sz, 3]), buf);
    final rows2d = cf
        ? List.generate(rows, (i) => List.generate(6, (c) => buf[0][c][i]))
        : buf[0].cast<List<double>>();
    final dets = <_Det>[];
    for (final row in rows2d) {
      if (row.length < 6) continue;
      final x1 = row[0], y1 = row[1], x2 = row[2], y2 = row[3];
      final raw = row[4];
      if (raw < _rawGate) continue;
      final score = _cal(raw);
      if (score < _displayGate || x2 <= x1 || y2 <= y1) continue;
      final cls = row[5].round().clamp(0, labels.length - 1);
      if (!_boxOk(x1, y1, x2, y2, 1.0)) continue;
      dets.add(_Det(Rect.fromLTRB(x1, y1, x2, y2), cls, score));
    }
    dets.sort((a, b) => b.score.compareTo(a.score));
    return dets.length > 200 ? dets.sublist(0, 200) : dets;
  }

  List<_Det> _parse(List<List<double>> preds, int nCls, int sz) {
    final dets = <_Det>[];
    for (final p in preds) {
      if (p.length < 4 + nCls) continue;
      double best = 0;
      int bestC = -1;
      for (int c = 0; c < nCls; c++) {
        final raw = _sig(p[4 + c]);
        if (raw > best) {
          best = raw;
          bestC = c;
        }
      }
      if (best < _rawGate || bestC < 0) continue;
      final score = _cal(best);
      if (score < _displayGate) continue;
      double cx = p[0], cy = p[1], w = p[2], h = p[3];
      if (cx.abs() <= 1.5 &&
          cy.abs() <= 1.5 &&
          w.abs() <= 1.5 &&
          h.abs() <= 1.5) {
        cx *= sz;
        cy *= sz;
        w *= sz;
        h *= sz;
      }
      double x1 = cx - w / 2, y1 = cy - h / 2, x2 = cx + w / 2, y2 = cy + h / 2;
      if (x2 <= x1 || y2 <= y1) {
        x1 = cx;
        y1 = cy;
        x2 = w;
        y2 = h;
      }
      if (x2 < -5 || y2 < -5 || x1 > sz + 5 || y1 > sz + 5) continue;
      if (!_boxOk(x1, y1, x2, y2, sz.toDouble())) continue;
      dets.add(_Det(Rect.fromLTRB(x1, y1, x2, y2), bestC, score));
    }
    dets.sort((a, b) => b.score.compareTo(a.score));
    return dets.length > 200 ? dets.sublist(0, 200) : dets;
  }

  bool _boxOk(double x1, double y1, double x2, double y2, double ds) {
    final bw = x2 - x1, bh = y2 - y1;
    if (ds > 1) {
      final mn = ds * 0.04, mx = ds * 0.92;
      if (bw < mn || bh < mn || bw > mx || bh > mx) return false;
    } else {
      final area = bw * bh;
      if (area < _minArea || area > _maxArea) return false;
    }
    final aspect = bh / (bw.abs() + 1e-9);
    return aspect >= _minAspect && aspect <= _maxAspect;
  }

  double _sig(double x) =>
      x >= 0 ? 1.0 / (1.0 + math.exp(-x)) : math.exp(x) / (1.0 + math.exp(x));
  double _cal(double s) {
    if (s < 0.70) return s;
    if (s < 0.85) return 0.70 + (s - 0.70) * 1.35;
    return 0.90 + (s - 0.85) * 1.0;
  }

  List<_Det> _unmap(List<_Det> dets, double srcW, double srcH) {
    final sz = _inSz.toDouble();
    final sc = math.min(sz / srcW, sz / srcH);
    final pX = (sz - srcW * sc) / 2.0, pY = (sz - srcH * sc) / 2.0;
    final out = <_Det>[];
    for (final d in dets) {
      final x1 = ((d.box.left - pX) / sc / srcW).clamp(0.0, 1.0);
      final y1 = ((d.box.top - pY) / sc / srcH).clamp(0.0, 1.0);
      final x2 = ((d.box.right - pX) / sc / srcW).clamp(0.0, 1.0);
      final y2 = ((d.box.bottom - pY) / sc / srcH).clamp(0.0, 1.0);
      if ((x2 - x1) < 0.01 || (y2 - y1) < 0.01) continue;
      if (!_boxOk(x1, y1, x2, y2, 1.0)) continue;
      out.add(_Det(Rect.fromLTRB(x1, y1, x2, y2), d.cls, d.score));
    }
    return out;
  }

  List<_Det> _nms(List<_Det> dets) {
    if (dets.isEmpty) return [];
    dets.sort((a, b) => b.score.compareTo(a.score));
    final sup = List<bool>.filled(dets.length, false);
    final keep = <_Det>[];
    for (int i = 0; i < dets.length; i++) {
      if (sup[i]) continue;
      keep.add(dets[i]);
      for (int j = i + 1; j < dets.length; j++) {
        if (sup[j]) continue;
        if (_iou(dets[i].box, dets[j].box) > _iouThres) sup[j] = true;
      }
    }
    return keep;
  }

  double _iou(Rect a, Rect b) {
    final il = math.max(a.left, b.left), it = math.max(a.top, b.top);
    final ir = math.min(a.right, b.right), ib = math.min(a.bottom, b.bottom);
    final iW = math.max(0.0, ir - il), iH = math.max(0.0, ib - it);
    final iA = iW * iH;
    final u = a.width * a.height + b.width * b.height - iA;
    return u <= 0 ? 0 : iA / u;
  }
}

// ============================================================================
// PAINTERS
// ============================================================================

class _BBPainter extends CustomPainter {
  final DetectionResult? det;
  final double? imageWidth;
  final double? imageHeight;
  const _BBPainter({this.det, this.imageWidth, this.imageHeight});

  @override
  void paint(Canvas canvas, Size size) {
    final d = det;
    if (d == null) return;
    final cw = size.width, ch = size.height;
    final iw = imageWidth ?? 1.0, ih = imageHeight ?? 1.0;
    final scaleX = cw / iw;
    final scaleY = ch / ih;
    final scale = math.min(scaleX, scaleY);
    final displayWidth = iw * scale;
    final displayHeight = ih * scale;
    final offsetX = (cw - displayWidth) / 2;
    final offsetY = (ch - displayHeight) / 2;

    final color = _accent(d.className);
    final boxP = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final bgP = Paint()..color = color.withOpacity(0.93);
    final r = Rect.fromLTWH(
      d.x * displayWidth + offsetX,
      d.y * displayHeight + offsetY,
      d.width * displayWidth,
      d.height * displayHeight,
    );
    canvas.drawRect(r, boxP);
    final lbl = d.className.cap;
    final tp = TextPainter(
      text: TextSpan(
        text: lbl,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    const pad = 5.0;
    final bgR = Rect.fromLTWH(
      r.left,
      math.max(0, r.top - tp.height - pad * 2),
      tp.width + pad * 2,
      tp.height + pad * 2,
    );
    canvas.drawRect(bgR, bgP);
    tp.paint(canvas, Offset(bgR.left + pad, bgR.top + pad));
  }

  @override
  bool shouldRepaint(_BBPainter o) =>
      o.det != det ||
      o.imageWidth != imageWidth ||
      o.imageHeight != imageHeight;
}

class _ArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width, size.height),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      Paint()
        ..color = C.primaryMid
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter o) => false;
}

// ── Corner bracket painter (thicker stroke) ──────────────────────────────────
class _FP extends CustomPainter {
  final double op;
  final bool busy;
  const _FP(this.op, {this.busy = false});
  @override
  void paint(Canvas c, Size s) {
    final color = busy
        ? C.primaryMid.withOpacity(math.max(op, 0.85))
        : C.primaryMid.withOpacity(op * 0.9 + 0.1);
    final p = Paint()
      ..color = color
      ..strokeWidth =
          4.0 // <-- made thicker
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const pad = 24.0, l = 32.0; // slightly longer corners
    for (final pts in [
      [Offset(pad, pad + l), Offset(pad, pad), Offset(pad + l, pad)],
      [
        Offset(s.width - pad - l, pad),
        Offset(s.width - pad, pad),
        Offset(s.width - pad, pad + l),
      ],
    ]) {
      c.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy),
        p,
      );
    }
    for (final pts in [
      [
        Offset(pad, s.height - pad - l),
        Offset(pad, s.height - pad),
        Offset(pad + l, s.height - pad),
      ],
      [
        Offset(s.width - pad - l, s.height - pad),
        Offset(s.width - pad, s.height - pad),
        Offset(s.width - pad, s.height - pad - l),
      ],
    ]) {
      c.drawPath(
        Path()
          ..moveTo(pts[0].dx, pts[0].dy)
          ..lineTo(pts[1].dx, pts[1].dy)
          ..lineTo(pts[2].dx, pts[2].dy),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_FP o) => o.op != op || o.busy != busy;
}

// ============================================================================
// UNIFIED DESIGN COMPONENTS
// ============================================================================

class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? radius;
  final Color? borderColor;
  const _Card({
    required this.child,
    this.padding,
    this.radius,
    this.borderColor,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(C.paddingCard),
    decoration: BoxDecoration(
      color: C.surface,
      borderRadius: radius ?? BorderRadius.circular(C.radiusCard),
      border: Border.all(color: borderColor ?? C.border),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 10,
          offset: Offset(0, 3),
        ),
      ],
    ),
    child: child,
  );
}

class _TappableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final EdgeInsetsGeometry margin;
  const _TappableCard({
    required this.child,
    required this.onTap,
    this.margin = const EdgeInsets.only(bottom: 12),
  });
  @override
  State<_TappableCard> createState() => _TappableCardState();
}

class _TappableCardState extends State<_TappableCard> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTapDown: (_) => setState(() => _pressed = true),
    onTapUp: (_) {
      setState(() => _pressed = false);
      widget.onTap();
    },
    onTapCancel: () => setState(() => _pressed = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      margin: widget.margin,
      decoration: BoxDecoration(
        color: _pressed ? C.primaryTint : C.surface,
        borderRadius: BorderRadius.circular(C.radiusCard),
        border: Border.all(
          color: _pressed ? C.primary.withOpacity(0.4) : C.border,
        ),
        boxShadow: [
          BoxShadow(
            color: _pressed
                ? C.primary.withOpacity(0.1)
                : const Color(0x08000000),
            blurRadius: _pressed ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: widget.child,
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader(this.title, {this.trailing});
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 3,
        height: 15,
        decoration: BoxDecoration(
          color: C.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(title, style: T.heading)),
      if (trailing != null) trailing!,
    ],
  );
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final IconData? icon;
  const _Pill(
    this.label, {
    this.bg = C.primaryLight,
    this.fg = C.primary,
    this.icon,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(C.radiusPill),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
        ],
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    ),
  );
}

Widget _bullet(String text, Color color) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 6),
        width: 5,
        height: 5,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 10),
      Expanded(child: Text(text, style: T.body)),
    ],
  ),
);

Widget _warnItem(String text, Color color, Color bg) => Padding(
  padding: const EdgeInsets.only(bottom: 8),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 2),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Icon(Icons.priority_high_rounded, size: 9, color: color),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: color.withOpacity(0.87),
            height: 1.5,
          ),
        ),
      ),
    ],
  ),
);

class _CharRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _CharRow(this.icon, this.label, this.value);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: C.primaryTint,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: C.primary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 96,
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(label, style: T.label),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Text(
              value,
              style: T.subhead,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// STAGGER ANIMATION
// ============================================================================

class _Stagger extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  const _Stagger({
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 60),
  });
  @override
  State<_Stagger> createState() => _StaggerState();
}

class _StaggerState extends State<_Stagger>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _fade,
    child: SlideTransition(position: _slide, child: widget.child),
  );
}

// ============================================================================
// IMAGE CAROUSEL
// ============================================================================

class _ImageCarousel extends StatefulWidget {
  final List<String> imagePaths;
  const _ImageCarousel({required this.imagePaths});
  @override
  State<_ImageCarousel> createState() => _ImageCarouselState();
}

class _ImageCarouselState extends State<_ImageCarousel> {
  final PageController _pc = PageController();
  int _current = 0;
  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(C.radiusCard),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: PageView.builder(
            controller: _pc,
            itemCount: widget.imagePaths.length,
            onPageChanged: (i) => setState(() => _current = i),
            itemBuilder: (_, i) => Image.asset(
              widget.imagePaths[i],
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: C.bg,
                child: const Center(
                  child: Icon(
                    Icons.image_not_supported,
                    size: 48,
                    color: C.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

// ============================================================================
// ANALYZING OVERLAY
// ============================================================================

class _AnalyzingOverlay extends StatefulWidget {
  const _AnalyzingOverlay();
  @override
  State<_AnalyzingOverlay> createState() => _AnalyzingOverlayState();
}

class _AnalyzingOverlayState extends State<_AnalyzingOverlay>
    with TickerProviderStateMixin {
  late AnimationController _spinCtrl, _pulseCtrl;
  late Animation<double> _pulseAnim;
  int _dotCount = 0;
  Timer? _dotTimer;
  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _dotTimer = Timer.periodic(const Duration(milliseconds: 480), (_) {
      if (mounted) setState(() => _dotCount = (_dotCount + 1) % 4);
    });
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    _pulseCtrl.dispose();
    _dotTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Positioned.fill(
    child: Container(
      color: C.camOverlayDark.withOpacity(0.88),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, child) =>
                Transform.scale(scale: _pulseAnim.value, child: child),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: C.primaryMid.withOpacity(0.3),
                      width: 2,
                    ),
                  ),
                ),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: AnimatedBuilder(
                    animation: _spinCtrl,
                    builder: (_, __) => Transform.rotate(
                      angle: _spinCtrl.value * 2 * math.pi,
                      child: CustomPaint(painter: _ArcPainter()),
                    ),
                  ),
                ),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: const AlwaysStoppedAnimation(C.primaryMid),
                    backgroundColor: C.primaryMid.withOpacity(0.18),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Analyzing',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
              SizedBox(
                width: 28,
                child: Text(
                  '.' * _dotCount,
                  style: const TextStyle(
                    color: C.primaryMid,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Scanning the camote…',
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// APP BAR HELPER
// ============================================================================

PreferredSizeWidget _appBar(String title, {List<Widget>? actions}) => AppBar(
  backgroundColor: C.surface,
  surfaceTintColor: C.surface,
  scrolledUnderElevation: 0.5,
  elevation: 0,
  shadowColor: C.border,
  title: Row(
    children: [
      Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: C.primaryLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.eco, color: C.primary, size: 20),
      ),
      const SizedBox(width: 10),
      Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: C.textPrimary,
        ),
      ),
    ],
  ),
  actions: actions,
  bottom: PreferredSize(
    preferredSize: const Size.fromHeight(1),
    child: Container(height: 1, color: C.border),
  ),
);

// ============================================================================
// APP ROOT
// ============================================================================

class DomaApp extends StatelessWidget {
  const DomaApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Doma – Camote Classifier',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      primarySwatch: Colors.green,
      scaffoldBackgroundColor: C.bg,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: C.surface,
        foregroundColor: C.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: C.surface,
      ),
    ),
    home: const SplashScreen(),
  );
}

// ============================================================================
// SPLASH SCREEN
// ============================================================================

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeIn);
    _ctrl.forward();
    Timer(const Duration(milliseconds: 1900), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 450),
          pageBuilder: (_, __, ___) => const MainNavigation(),
          transitionsBuilder: (_, anim, __, child) =>
              FadeTransition(opacity: anim, child: child),
        ),
      );
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.surface,
    body: Container(
      color: C.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _scale,
              child: FadeTransition(
                opacity: _fade,
                child: const Icon(Icons.eco, color: C.primary, size: 76),
              ),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _fade,
              child: const Text(
                'Doma App',
                style: TextStyle(
                  color: C.primary,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FadeTransition(
              opacity: _fade,
              child: Text(
                'Camote Classifier App',
                style: TextStyle(
                  color: C.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                color: C.primary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class TimeFormatter {
  static String rel(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 60) return 'Just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    if (d.inDays < 7) return '${d.inDays}d ago';
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  static String short(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    return '${m[dt.month - 1]} ${dt.day}  $h:$min ${dt.hour < 12 ? "AM" : "PM"}';
  }

  static String full(DateTime dt) {
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final min = dt.minute.toString().padLeft(2, '0');
    return '${m[dt.month - 1]} ${dt.day}, ${dt.year}  •  $h:$min ${dt.hour < 12 ? "AM" : "PM"}';
  }
}

// ============================================================================
// MAIN NAVIGATION
// ============================================================================

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});
  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _idx = 0;
  final _cls = CamoteClassifier();
  DetectionLog? _last;
  final _rKey = GlobalKey<_ResultsPageState>();
  final _hKey = GlobalKey<_DetectionsPageState>();
  @override
  void initState() {
    super.initState();
    _cls.loadModel().catchError(
      (e) => debugPrint('[Doma] model load failed: $e'),
    );
  }

  @override
  void dispose() {
    _cls.dispose();
    super.dispose();
  }

  void _onResult(DetectionLog log) {
    setState(() {
      _last = log;
      _idx = 1;
    });
    _rKey.currentState?.update(log);
    _hKey.currentState?.add(log);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(
      index: _idx,
      children: [
        ScanPage(classifier: _cls, onResult: _onResult, cameras: _cameras),
        ResultsPage(key: _rKey, result: _last),
        DetectionsPage(key: _hKey),
        const LibraryPage(),
      ],
    ),
    bottomNavigationBar: _BottomNav(
      currentIndex: _idx,
      onTap: (i) => setState(() => _idx = i),
    ),
  );
}

// ============================================================================
// BOTTOM NAV
// ============================================================================

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _BottomNav({required this.currentIndex, required this.onTap});
  static const _items = [
    (Icons.camera_alt_outlined, Icons.camera_alt, 'Scan'),
    (Icons.analytics_outlined, Icons.analytics, 'Results'),
    (Icons.history_outlined, Icons.history, 'Detections'),
    (Icons.photo_library_outlined, Icons.photo_library, 'Library'),
  ];
  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      color: C.surface,
      border: Border(top: BorderSide(color: C.border)),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_items.length, (i) {
            final sel = currentIndex == i;
            final item = _items[i];
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: sel ? C.primaryLight : Colors.transparent,
                  borderRadius: BorderRadius.circular(C.radiusPill),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      sel ? item.$2 : item.$1,
                      color: sel ? C.primary : C.textMuted,
                      size: 22,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.$3,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? C.primary : C.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    ),
  );
}

// ============================================================================
// SCAN PAGE
// ============================================================================

class ScanPage extends StatefulWidget {
  final CamoteClassifier classifier;
  final Function(DetectionLog) onResult;
  final List<CameraDescription> cameras;
  const ScanPage({
    super.key,
    required this.classifier,
    required this.onResult,
    required this.cameras,
  });
  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final _picker = ImagePicker();
  bool _busy = false;
  File? _previewFile;
  CameraController? _cam;
  bool _camReady = false;
  String? _camErr;
  bool _usingFront = false;
  late AnimationController _cornerCtrl;
  late Animation<double> _cornerAnim;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cornerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _cornerAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _cornerCtrl, curve: Curves.easeInOut));
    _initCam();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cam?.dispose();
    _cornerCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (_cam == null || !_cam!.value.isInitialized) return;
    if (s == AppLifecycleState.inactive) {
      _cam!.dispose();
      if (mounted) setState(() => _camReady = false);
    } else if (s == AppLifecycleState.resumed)
      _initCam();
  }

  Future<void> _initCam() async {
    if (widget.cameras.isEmpty) {
      if (mounted) setState(() => _camErr = 'No camera found.');
      return;
    }
    try {
      final old = _cam;
      _cam = null;
      if (mounted) setState(() => _camReady = false);
      try {
        await old?.dispose();
      } catch (_) {}
      final camDesc = (_usingFront && widget.cameras.length > 1)
          ? widget.cameras.firstWhere(
              (c) => c.lensDirection == CameraLensDirection.front,
              orElse: () => widget.cameras.first,
            )
          : widget.cameras.first;
      final c = CameraController(
        camDesc,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _cam = c;
      await c.initialize();
      if (!mounted) {
        try {
          await c.dispose();
        } catch (_) {}
        _cam = null;
        return;
      }
      try {
        await c.setFocusMode(FocusMode.auto);
        await c.setExposureMode(ExposureMode.auto);
        await c.setFlashMode(FlashMode.off);
      } catch (_) {}
      if (mounted) setState(() => _camReady = true);
    } catch (e) {
      debugPrint('[Doma] camera error: $e');
      if (mounted) setState(() => _camErr = 'Camera unavailable.');
    }
  }

  Future<void> _switchCam() async {
    if (widget.cameras.length < 2 || _busy) return;
    setState(() => _usingFront = !_usingFront);
    await _initCam();
  }

  Future<void> _capture() async {
    if (_cam == null || !_cam!.value.isInitialized || _busy) return;
    try {
      final f = await _cam!.takePicture();
      await _process(File(f.path));
    } catch (e) {
      debugPrint('[Doma] capture error: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _gallery() async {
    if (_busy) return;
    final f = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 95,
    );
    if (f != null) await _process(File(f.path));
  }

  Future<void> _process(File file) async {
    if (!mounted) return;
    setState(() => _busy = true);
    await Future.delayed(const Duration(milliseconds: 80));
    try {
      final result = await widget.classifier.detect(file);
      if (!mounted) return;
      setState(() => _busy = false);
      switch (result.state) {
        case _ScanState.notFound:
          if (mounted) _showDlg(const _NoCamoteDlg());
          return;
        case _ScanState.multipleVariants:
          if (mounted) _showDlg(const _MultipleVariantsDlg());
          return;
        case _ScanState.ok:
          break;
      }
      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/camote_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await file.copy(path);
      final winner = result.winner;
      if (winner == null) {
        if (mounted) _showDlg(const _NoCamoteDlg());
        return;
      }
      final log = DetectionLog(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        imagePath: path,
        results: [winner],
        timestamp: DateTime.now(),
      );
      widget.onResult(log);
    } catch (e, st) {
      debugPrint('[Doma] process error: $e\n$st');
      if (mounted) {
        setState(() => _busy = false);
        _showDlg(const _NoCamoteDlg());
      }
    }
  }

  void _showDlg(Widget dlg) =>
      showDialog(context: context, builder: (_) => dlg);

  Widget _camView() {
    if (_camErr != null)
      return Container(
        color: const Color(0xFF0D1F17),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white38,
                size: 48,
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  _camErr!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    if (!_camReady || _cam == null)
      return Container(
        color: const Color(0xFF0D1F17),
        child: const Center(
          child: CircularProgressIndicator(
            color: C.primaryMid,
            strokeWidth: 2.5,
          ),
        ),
      );
    final preview = _cam!.value.previewSize;
    if (preview == null)
      return Container(
        color: const Color(0xFF0D1F17),
        child: const Center(
          child: CircularProgressIndicator(
            color: C.primaryMid,
            strokeWidth: 2.5,
          ),
        ),
      );
    return OverflowBox(
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: preview.height,
          height: preview.width,
          child: CameraPreview(_cam!),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _appBar(
        'Scan',
        actions: [
          IconButton(
            icon: const Icon(Icons.menu_book_outlined),
            color: C.textSec,
            tooltip: 'How to Use',
            onPressed: () => _showDlg(const _HowToDlg()),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline),
            color: C.textSec,
            tooltip: 'About',
            onPressed: () => _showDlg(const _AboutDlg()),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (_previewFile != null && !_busy)
                  Image.file(_previewFile!, fit: BoxFit.cover)
                else
                  _camView(),
                // ── Removed horizontal scanning line ──
                if (!_busy)
                  AnimatedBuilder(
                    animation: _cornerAnim,
                    builder: (_, __) => Positioned.fill(
                      child: CustomPaint(painter: _FP(_cornerAnim.value)),
                    ),
                  ),
                if (_busy) const _AnalyzingOverlay(),
              ],
            ),
          ),
          Container(
            color: C.bg,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _ActionBtn(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: _busy ? null : _gallery,
                  busy: _busy,
                ),
                GestureDetector(
                  onTap: _busy ? null : _capture,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    width: 78,
                    height: 78,
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _busy ? C.primaryDark : C.primary,
                        width: 3.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: C.primary.withOpacity(_busy ? 0.06 : 0.22),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _busy
                          ? SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                color: C.primary,
                                strokeWidth: 2.5,
                                backgroundColor: C.primary.withOpacity(0.2),
                              ),
                            )
                          : Container(
                              width: 58,
                              height: 58,
                              decoration: const BoxDecoration(
                                color: C.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                    ),
                  ),
                ),
                _ActionBtn(
                  icon: Icons.flip_camera_ios_outlined,
                  label: 'Flip',
                  onTap: _busy ? null : _switchCam,
                  busy: _busy,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;
  const _ActionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.busy,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: busy ? C.border : C.surface,
            shape: BoxShape.circle,
            border: Border.all(
              color: busy ? C.border : C.borderMid,
              width: 1.5,
            ),
            boxShadow: busy
                ? []
                : [
                    const BoxShadow(
                      color: Color(0x0F000000),
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
          ),
          child: Icon(icon, size: 22, color: busy ? C.textMuted : C.textSec),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: busy ? C.textMuted : C.textSec,
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// SHARED DIALOG SHELL
// ============================================================================

class _WhiteDlg extends StatelessWidget {
  final Widget child;
  const _WhiteDlg({required this.child});
  @override
  Widget build(BuildContext context) => Dialog(
    backgroundColor: C.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
    child: child,
  );
}

Widget _dlgBtn(
  String label, {
  required VoidCallback onTap,
  Color bg = C.primary,
}) => SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: onTap,
    style: ElevatedButton.styleFrom(
      backgroundColor: bg,
      foregroundColor: C.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(C.radiusInner),
      ),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    ),
  ),
);

// ── Dialog widgets ────────────────────────────────────────────────────────────

class _NoCamoteDlg extends StatelessWidget {
  const _NoCamoteDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.errLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.search_off_rounded, color: C.err, size: 28),
          ),
          const SizedBox(height: 16),
          Text('No Camote Detected', style: T.title),
          const SizedBox(height: 8),
          Text(
            'Make sure it is well-lit and centred in frame.',
            textAlign: TextAlign.center,
            style: T.body,
          ),
          const SizedBox(height: 22),
          _dlgBtn('Try Again', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

class _MultipleVariantsDlg extends StatelessWidget {
  const _MultipleVariantsDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.warnLight,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: C.warn,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Multiple Varieties Detected',
            style: T.title,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Place only one camote in frame for an accurate scan.',
            textAlign: TextAlign.center,
            style: T.body,
          ),
          const SizedBox(height: 22),
          _dlgBtn('Try Again', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

class _HowToDlg extends StatelessWidget {
  const _HowToDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: C.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.menu_book_outlined,
                    color: C.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text('How to Use', style: T.title),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(Icons.close, size: 16, color: C.textSec),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _step(
                      1,
                      'Place one camote',
                      'Centre it on a plain surface.',
                    ),
                    _step(
                      2,
                      'Capture or choose',
                      'Use the shutter or gallery.',
                    ),
                    _step(
                      3,
                      'AI analysis',
                      'The variety is identified automatically.',
                    ),
                    _step(
                      4,
                      'View results',
                      'See variety, nutrition, and recipes.',
                    ),
                    _step(5, 'History & Library', 'Review past scans anytime.'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _dlgBtn('Got It', onTap: () => Navigator.pop(context)),
          ],
        ),
      ),
    ),
  );
  Widget _step(int n, String t, String d) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: const BoxDecoration(
            color: C.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$n',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t, style: T.subhead),
              const SizedBox(height: 2),
              Text(d, style: T.body),
            ],
          ),
        ),
      ],
    ),
  );
}

class _AboutDlg extends StatelessWidget {
  const _AboutDlg();
  @override
  Widget build(BuildContext context) => _WhiteDlg(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.eco, color: C.primary, size: 32),
          ),
          const SizedBox(height: 14),
          Text('Doma', style: T.display),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(C.radiusPill),
            ),
            child: const Text(
              'Version 1.0',
              style: TextStyle(
                fontSize: 12,
                color: C.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Identifies camote varieties grown in Tacloban City, Leyte.',
            textAlign: TextAlign.center,
            style: T.body,
          ),
          const SizedBox(height: 20),
          _dlgBtn('Close', onTap: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
}

// ============================================================================
// RESULTS PAGE
// ============================================================================

class ResultsPage extends StatefulWidget {
  final DetectionLog? result;
  const ResultsPage({super.key, this.result});
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage>
    with SingleTickerProviderStateMixin {
  DetectionLog? _r;
  bool _saved = false;
  double? _imageWidth, _imageHeight;
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _r = widget.result;
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    if (_r != null) {
      _ctrl.forward();
      _loadImageDimensions();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(ResultsPage old) {
    super.didUpdateWidget(old);
    if (widget.result != old.result) {
      setState(() {
        _r = widget.result;
        _saved = false;
        _imageWidth = _imageHeight = null;
      });
      _ctrl.forward(from: 0);
      if (_r != null) _loadImageDimensions();
    }
  }

  void update(DetectionLog log) {
    setState(() {
      _r = log;
      _saved = false;
      _imageWidth = _imageHeight = null;
    });
    _ctrl.forward(from: 0);
    _loadImageDimensions();
  }

  Future<void> _loadImageDimensions() async {
    if (_r == null) return;
    final file = File(_r!.imagePath);
    if (!await file.exists()) return;
    try {
      final bytes = await file.readAsBytes();
      final img.Image? decoded = img.decodeImage(bytes);
      if (decoded != null) {
        setState(() {
          _imageWidth = decoded.width.toDouble();
          _imageHeight = decoded.height.toDouble();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveDetection() async {
    if (_r == null || _saved) return;
    await DetectionLogger.save(_r!);
    setState(() => _saved = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Detection saved'),
        backgroundColor: C.primary,
        duration: Duration(seconds: 2),
      ),
    );
  }

  CamoteVariety? _v(String cls) {
    try {
      return camoteVarieties.firstWhere(
        (v) => v.name.toLowerCase() == cls.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_r == null || _r!.results.isEmpty)
      return Scaffold(
        backgroundColor: C.bg,
        appBar: _appBar('Results'),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: C.bg,
                  shape: BoxShape.circle,
                  border: Border.all(color: C.border, width: 2),
                ),
                child: const Icon(
                  Icons.analytics_outlined,
                  size: 44,
                  color: C.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Text('No results yet', style: T.heading),
              const SizedBox(height: 6),
              Text('Scan a camote to see results here', style: T.body),
            ],
          ),
        ),
      );

    final top = _r!.results.first;
    final variety = _v(top.className);
    final accentColor = _accent(top.className);
    final accentLightColor = _accentLight(top.className);

    return Scaffold(
      backgroundColor: C.bg,
      appBar: _appBar('Results'),
      body: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  height: 260,
                  width: double.infinity,
                  child: File(_r!.imagePath).existsSync()
                      ? Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              File(_r!.imagePath),
                              fit: BoxFit.contain,
                              alignment: Alignment.center,
                            ),
                            CustomPaint(
                              painter: _BBPainter(
                                det: top,
                                imageWidth: _imageWidth,
                                imageHeight: _imageHeight,
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              left: 0,
                              right: 0,
                              child: Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.transparent,
                                      C.bg.withOpacity(0.97),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : Container(
                          color: C.bg,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 56,
                            color: C.textMuted,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    C.paddingPage,
                    0,
                    C.paddingPage,
                    28,
                  ),
                  child: Column(
                    children: [
                      _Stagger(
                        index: 0,
                        child: _IdentityCard(
                          top: top,
                          variety: variety,
                          accentColor: accentColor,
                          accentLightColor: accentLightColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (variety != null) ...[
                        _Stagger(
                          index: 1,
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader('Overview'),
                                const SizedBox(height: 10),
                                Text(variety.description, style: T.body),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Stagger(
                          index: 2,
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const _SectionHeader('Characteristics'),
                                const SizedBox(height: 4),
                                const Divider(height: 1, color: C.border),
                                _CharRow(
                                  Icons.straighten,
                                  'Shape',
                                  variety.shape,
                                ),
                                const Divider(height: 1, color: C.border),
                                _CharRow(
                                  Icons.palette_outlined,
                                  'Skin Color',
                                  variety.skinColor,
                                ),
                                const Divider(height: 1, color: C.border),
                                _CharRow(
                                  Icons.circle_outlined,
                                  'Flesh Color',
                                  variety.fleshColor,
                                ),
                                const Divider(height: 1, color: C.border),
                                _CharRow(
                                  Icons.texture,
                                  'Texture',
                                  variety.texture,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Stagger(
                          index: 3,
                          child: _IntakeCard(
                            intake: variety.intake,
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Stagger(
                          index: 4,
                          child: _TargetedCard(
                            people: variety.targetedPeople,
                            accentColor: accentColor,
                            accentLightColor: accentLightColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Stagger(
                          index: 5,
                          child: _MedicalCard(
                            medical: variety.medicalInfo,
                            accentColor: accentColor,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _Stagger(
                          index: 6,
                          child: _RecipeRowCard(
                            recipes: variety.recipes,
                            accentColor: accentColor,
                          ),
                        ),
                      ],
                      _Stagger(
                        index: 7,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 18),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _saved ? null : _saveDetection,
                              icon: Icon(
                                _saved ? Icons.check_circle : Icons.add,
                              ),
                              label: Text(_saved ? 'Saved' : 'Save Detection'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _saved
                                    ? C.primaryLight
                                    : C.primary,
                                foregroundColor: _saved ? C.primary : C.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    C.radiusInner,
                                  ),
                                ),
                                textStyle: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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
      ),
    );
  }
}

// ── Identity card (no confidence bar) ────────────────────────────────────────
class _IdentityCard extends StatelessWidget {
  final DetectionResult top;
  final CamoteVariety? variety;
  final Color accentColor, accentLightColor;
  const _IdentityCard({
    required this.top,
    required this.variety,
    required this.accentColor,
    required this.accentLightColor,
  });
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accentColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withOpacity(0.28),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: const SizedBox.shrink(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(variety?.name ?? top.className.cap, style: T.display),
                  if (variety != null)
                    Text(
                      variety!.commonName,
                      style: TextStyle(
                        fontSize: 13,
                        color: accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: accentLightColor,
                borderRadius: BorderRadius.circular(C.radiusPill),
              ),
              child: Text(
                'Detected',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: accentColor,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ── Intake card ───────────────────────────────────────────────────────────────
class _IntakeCard extends StatelessWidget {
  final IntakeGuideline intake;
  final Color accentColor;
  const _IntakeCard({required this.intake, required this.accentColor});
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Daily Intake',
          trailing: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.monitor_heart_outlined,
              size: 14,
              color: C.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _intakeStat(
                'Daily Max',
                intake.dailyMax,
                Icons.today,
                accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _intakeStat(
                'Weekly Max',
                intake.weeklyMax,
                Icons.date_range,
                accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _intakeStat(
                'Serving',
                intake.servingSize,
                Icons.restaurant,
                accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _intakeStat(
                'Best Time',
                intake.bestTime,
                Icons.wb_sunny_outlined,
                accentColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(height: 1, color: C.border),
        const SizedBox(height: 12),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: C.warnLight,
                borderRadius: BorderRadius.circular(7),
              ),
              child: const Icon(
                Icons.warning_amber_outlined,
                size: 13,
                color: C.warn,
              ),
            ),
            const SizedBox(width: 8),
            Text('Cautions', style: T.subhead),
          ],
        ),
        const SizedBox(height: 8),
        ...intake.limitations.map((l) => _warnItem(l, C.warn, C.warnLight)),
        ...intake.cautions.map((c) => _warnItem(c, C.warn, C.warnLight)),
      ],
    ),
  );

  Widget _intakeStat(String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: C.bg,
          borderRadius: BorderRadius.circular(C.radiusInner),
          border: Border.all(color: C.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 5),
            Text(label, style: T.caption),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: C.textPrimary,
                height: 1.35,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
}

// ── Targeted people card – no bubbles, clean list ──────────────────────────
class _TargetedCard extends StatelessWidget {
  final List<String> people;
  final Color accentColor, accentLightColor;
  const _TargetedCard({
    required this.people,
    required this.accentColor,
    required this.accentLightColor,
  });
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader('Best Suited For'),
        const SizedBox(height: 12),
        ...people.map(
          (p) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(Icons.person_outline, size: 16, color: accentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p,
                    style: TextStyle(
                      fontSize: 13,
                      color: accentColor,
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
  );
}

// ── Medical card ──────────────────────────────────────────────────────────────
class _MedicalCard extends StatelessWidget {
  final MedicalInfo medical;
  final Color accentColor;
  const _MedicalCard({required this.medical, required this.accentColor});
  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Nutrition & Medical',
          trailing: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: C.primaryLight,
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.medical_information_outlined,
              size: 13,
              color: C.primary,
            ),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _nutBadge(
              'Calories',
              medical.calories100g,
              Icons.local_fire_department_outlined,
            ),
            _nutBadge('Carbs', medical.carbs100g, Icons.grain),
            _nutBadge('Fiber', medical.fiber, Icons.spa_outlined),
            _nutBadge('Potassium', medical.potassium, Icons.bolt_outlined),
            _nutBadge('Vitamin A', medical.vitaminA, Icons.visibility_outlined),
            _nutBadge('Vitamin C', medical.vitaminC, Icons.eco_outlined),
          ],
        ),
        const SizedBox(height: 12),
        _infoRow('Glycemic Index', medical.glycemicIndex),
        _infoRow('Glycemic Load', medical.glycemicLoad),
        const SizedBox(height: 10),
        const Divider(height: 1, color: C.border),
        const SizedBox(height: 10),
        Text('Medicinal Uses', style: T.subhead.copyWith(color: C.primary)),
        const SizedBox(height: 6),
        ...medical.medicinalUses.map((u) => _bullet(u, C.primary)),
        if (medical.drugInteractions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Drug Interactions', style: T.subhead.copyWith(color: C.warn)),
          const SizedBox(height: 6),
          ...medical.drugInteractions.map(
            (u) => _warnItem(u, C.warn, C.warnLight),
          ),
        ],
        if (medical.contraindications.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Contraindications', style: T.subhead.copyWith(color: C.err)),
          const SizedBox(height: 6),
          ...medical.contraindications.map(
            (u) => _warnItem(u, C.err, C.errLight),
          ),
        ],
      ],
    ),
  );

  Widget _nutBadge(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: C.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(C.radiusInner),
      border: Border.all(color: C.primary.withOpacity(0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: C.primary),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 9, color: C.primary.withOpacity(0.7)),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: C.primary,
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Text('$label:', style: T.label),
        const SizedBox(width: 6),
        Text(value, style: T.subhead),
      ],
    ),
  );
}

// ── Recipe row card ───────────────────────────────────────────────────────────
class _RecipeRowCard extends StatelessWidget {
  final List<CamoteRecipe> recipes;
  final Color accentColor;
  const _RecipeRowCard({required this.recipes, required this.accentColor});
  @override
  Widget build(BuildContext context) => _Card(
    padding: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            C.paddingCard,
            C.paddingCard,
            C.paddingCard,
            12,
          ),
          child: _SectionHeader(
            'Recipes',
            trailing: Text('${recipes.length}', style: T.caption),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(
              C.paddingCard,
              0,
              C.paddingCard,
              C.paddingCard,
            ),
            itemCount: recipes.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => showModalBottomSheet(
                context: ctx,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => _RecipeDetailSheet(
                  recipe: recipes[i],
                  accentColor: accentColor,
                ),
              ),
              child: Container(
                width: 160,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(C.radiusInner),
                  border: Border.all(color: C.border),
                  color: C.bg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(9),
                      ),
                      child: SizedBox(
                        height: 85,
                        width: 160,
                        child: Image.asset(
                          recipes[i].imagePath,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: accentColor.withOpacity(0.1),
                            child: Icon(
                              Icons.restaurant_menu,
                              color: accentColor,
                              size: 32,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            recipes[i].name,
                            style: T.subhead,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 10,
                                color: accentColor,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                recipes[i].cookTime,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: accentColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  recipes[i].difficulty,
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    color: accentColor,
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
            ),
          ),
        ),
      ],
    ),
  );
}

// ============================================================================
// RECIPE DETAIL BOTTOM SHEET (unchanged)
// ============================================================================

class _RecipeDetailSheet extends StatefulWidget {
  final CamoteRecipe recipe;
  final Color accentColor;
  const _RecipeDetailSheet({required this.recipe, required this.accentColor});
  @override
  State<_RecipeDetailSheet> createState() => _RecipeDetailSheetState();
}

class _RecipeDetailSheetState extends State<_RecipeDetailSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final accent = widget.accentColor;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 190,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    r.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: accent.withOpacity(0.15),
                      child: Icon(
                        Icons.restaurant_menu,
                        color: accent,
                        size: 56,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.65),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            _badge(
                              r.prepTime,
                              Icons.access_time,
                              Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            _badge(
                              r.cookTime,
                              Icons.local_fire_department,
                              Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            _badge(
                              r.difficulty,
                              Icons.bar_chart,
                              Colors.white70,
                            ),
                            const SizedBox(width: 8),
                            _badge(
                              '${r.servings} servings',
                              Icons.people_outline,
                              Colors.white70,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              color: C.surface,
              child: TabBar(
                controller: _tab,
                labelColor: accent,
                unselectedLabelColor: C.textSec,
                indicatorColor: accent,
                labelStyle: T.subhead,
                tabs: const [
                  Tab(text: 'Ingredients'),
                  Tab(text: 'Steps'),
                  Tab(text: 'Tips'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _Pill(
                        '${r.calories} kcal / serving',
                        bg: accent.withOpacity(0.1),
                        fg: accent,
                      ),
                      const SizedBox(height: 14),
                      ...r.ingredients.asMap().entries.map(
                        (e) => _Stagger(
                          index: e.key,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: accent.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${e.key + 1}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text(e.value, style: T.body)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: r.steps
                        .asMap()
                        .entries
                        .map(
                          (e) => _Stagger(
                            index: e.key,
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Column(
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: accent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${e.key + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (e.key < r.steps.length - 1)
                                        Container(
                                          width: 2,
                                          height: 28,
                                          color: accent.withOpacity(0.2),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: Text(e.value, style: T.body),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      ...r.tips.asMap().entries.map(
                        (e) => _Stagger(
                          index: e.key,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(
                                C.radiusInner,
                              ),
                              border: Border.all(
                                color: accent.withOpacity(0.18),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.lightbulb_outline,
                                  color: accent,
                                  size: 17,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.value,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: accent.withOpacity(0.87),
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: C.primaryLight,
                          borderRadius: BorderRadius.circular(C.radiusInner),
                          border: Border.all(
                            color: C.primary.withOpacity(0.18),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: C.primary,
                              size: 15,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Wash camote thoroughly and peel if the skin is damaged.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: C.primary,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
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

  Widget _badge(String label, IconData icon, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 10, color: color),
      const SizedBox(width: 3),
      Text(
        label,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

// ============================================================================
// DETECTIONS PAGE (formerly History)
// ============================================================================

class DetectionsPage extends StatefulWidget {
  const DetectionsPage({super.key});
  @override
  State<DetectionsPage> createState() => _DetectionsPageState();
}

class _DetectionsPageState extends State<DetectionsPage> {
  List<DetectionLog> _logs = [];
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _logs = await DetectionLogger.load();
    setState(() => _loading = false);
  }

  void add(DetectionLog log) => setState(() => _logs.insert(0, log));
  Future<void> _del(DetectionLog log) async {
    setState(() => _loading = true);
    await DetectionLogger.delete(log.id);
    await _load();
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => _WhiteDlg(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: C.errLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline, color: C.err, size: 28),
              ),
              const SizedBox(height: 14),
              Text(
                'Clear All Detections?',
                style: T.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This permanently deletes all saved detections.',
                textAlign: TextAlign.center,
                style: T.body,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: C.borderMid),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(C.radiusInner),
                        ),
                      ),
                      child: Text('Cancel', style: T.subhead),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _dlgBtn(
                      'Clear All',
                      onTap: () => Navigator.pop(context, true),
                      bg: C.err,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (ok == true) {
      setState(() => _loading = true);
      await DetectionLogger.clearAll();
      await _load();
    }
  }

  CamoteVariety? _v(String cls) {
    try {
      return camoteVarieties.firstWhere(
        (v) => v.name.toLowerCase() == cls.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  void _detail(DetectionLog log, DetectionResult? top, CamoteVariety? v) =>
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DetailSheet(
          log: log,
          top: top,
          variety: v,
          onDelete: () async => _del(log),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: _appBar('Detections'),
    body: Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(
            C.paddingPage,
            12,
            C.paddingPage,
            0,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: C.surface,
            borderRadius: BorderRadius.circular(C.radiusCard),
            border: Border.all(color: C.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_logs.length}',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: C.primary,
                      ),
                    ),
                    Text(
                      _logs.length == 1 ? 'detection' : 'detections',
                      style: T.caption,
                    ),
                  ],
                ),
              ),
              if (_logs.isNotEmpty)
                GestureDetector(
                  onTap: _clearAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: C.errLight,
                      borderRadius: BorderRadius.circular(C.radiusInner),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.delete_outline, color: C.err, size: 15),
                        SizedBox(width: 5),
                        Text(
                          'Clear All',
                          style: TextStyle(
                            color: C.err,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: C.primary))
              : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: C.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: C.border, width: 2),
                        ),
                        child: const Icon(
                          Icons.history,
                          size: 38,
                          color: C.textMuted,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text('No detections yet', style: T.heading),
                      const SizedBox(height: 4),
                      Text('Scan and save a camote', style: T.body),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: C.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: C.paddingPage,
                      vertical: 4,
                    ),
                    itemCount: _logs.length,
                    itemBuilder: (_, i) {
                      final log = _logs[i];
                      final top = log.results.isEmpty
                          ? null
                          : log.results.first;
                      final v = _v(top?.className ?? '');
                      return _Stagger(
                        index: i > 5 ? 5 : i,
                        child: _DetectionCard(
                          log: log,
                          top: top,
                          variety: v,
                          onTap: () => _detail(log, top, v),
                          onDelete: () => _del(log),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    ),
  );
}

class _DetectionCard extends StatelessWidget {
  final DetectionLog log;
  final DetectionResult? top;
  final CamoteVariety? variety;
  final VoidCallback onTap, onDelete;
  const _DetectionCard({
    required this.log,
    required this.top,
    required this.variety,
    required this.onTap,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => _TappableCard(
    onTap: onTap,
    margin: const EdgeInsets.only(bottom: 10),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: _accent(top?.className ?? ''),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(C.radiusCard - 1),
                bottomLeft: Radius.circular(C.radiusCard - 1),
              ),
            ),
          ),
          ClipRRect(
            child: SizedBox(
              width: 82,
              child: File(log.imagePath).existsSync()
                  ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                  : Container(
                      color: C.bg,
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 24,
                        color: C.textMuted,
                      ),
                    ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    top?.className.cap ?? 'Unknown',
                    style: T.heading,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variety != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      variety!.commonName,
                      style: const TextStyle(
                        fontSize: 12,
                        color: C.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 11,
                        color: C.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          TimeFormatter.short(log.timestamp),
                          style: T.caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        TimeFormatter.rel(log.timestamp),
                        style: const TextStyle(
                          fontSize: 11,
                          color: C.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (top != null) ...[
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: C.primaryLight,
                            borderRadius: BorderRadius.circular(C.radiusPill),
                          ),
                          child: Text(
                            '${(top!.confidence * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: C.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 10, bottom: 12, top: 12),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: C.errLight,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    size: 16,
                    color: C.err,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _DetailSheet extends StatelessWidget {
  final DetectionLog log;
  final DetectionResult? top;
  final CamoteVariety? variety;
  final Future<void> Function() onDelete;
  const _DetailSheet({
    required this.log,
    this.top,
    this.variety,
    required this.onDelete,
  });
  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: 0.87,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (_, sc) => Container(
      decoration: const BoxDecoration(
        color: C.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            decoration: BoxDecoration(
              color: C.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Detection Details', style: T.caption),
                      if (top != null) ...[
                        const SizedBox(height: 2),
                        Text(top!.className.cap, style: T.display),
                        if (variety != null)
                          Text(
                            variety!.commonName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: C.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: C.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.border),
                    ),
                    child: const Icon(Icons.close, size: 16, color: C.textSec),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: C.border),
          Expanded(
            child: ListView(
              controller: sc,
              padding: const EdgeInsets.all(20),
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(C.radiusCard),
                  child: SizedBox(
                    height: 240,
                    child: File(log.imagePath).existsSync()
                        ? Image.file(File(log.imagePath), fit: BoxFit.cover)
                        : Container(
                            color: C.bg,
                            child: const Icon(
                              Icons.image_not_supported,
                              size: 56,
                              color: C.textMuted,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                if (top != null) ...[
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _SectionHeader('Confidence'),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            const Icon(Icons.percent, color: C.primary),
                            const SizedBox(width: 8),
                            Text(
                              '${(top!.confidence * 100).toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: C.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                _Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _SectionHeader('Timestamp'),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_outlined,
                            size: 16,
                            color: C.textSec,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              TimeFormatter.full(log.timestamp),
                              style: T.subhead,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: C.textSec,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            TimeFormatter.rel(log.timestamp),
                            style: const TextStyle(
                              fontSize: 13,
                              color: C.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await onDelete();
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete this Detection'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: C.err,
                      foregroundColor: C.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(C.radiusInner),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ============================================================================
// LIBRARY PAGE
// ============================================================================

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: C.bg,
    appBar: _appBar('Library'),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(C.paddingPage),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          ...camoteVarieties.asMap().entries.map(
            (e) => _Stagger(index: e.key, child: _VarietyCard(e.value)),
          ),
        ],
      ),
    ),
  );
}

class _VarietyCard extends StatelessWidget {
  final CamoteVariety v;
  const _VarietyCard(this.v);
  @override
  Widget build(BuildContext context) {
    final accentColor = _accent(v.name);
    return _TappableCard(
      onTap: () => _show(context),
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(C.radiusCard - 1),
                  topRight: Radius.circular(C.radiusCard - 1),
                ),
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: Image.asset(
                    v.imagePath,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: C.bg,
                      child: const Center(
                        child: Icon(Icons.image, color: C.textMuted, size: 40),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(C.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        size: 11,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${v.recipes.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(v.name, style: T.heading),
                          const SizedBox(height: 2),
                          Text(
                            v.commonName,
                            style: TextStyle(
                              fontSize: 13,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: C.primaryLight,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: const Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: C.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _miniStat('GI', _giLabel(v.name), accentColor),
                    const SizedBox(width: 8),
                    _miniStat('Daily Max', _dailyMaxShort(v.name), accentColor),
                    const SizedBox(width: 8),
                    _miniStat('kcal/100g', _kcal(v.name), accentColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );

  static String _giLabel(String n) =>
      n.toLowerCase() == 'tapol' ? 'Low–Med' : 'Medium';
  static String _dailyMaxShort(String n) =>
      n.toLowerCase() == 'tapol' ? '150–250 g' : '150–200 g';
  static String _kcal(String n) {
    switch (n.toLowerCase()) {
      case 'tapol':
        return '76 kcal';
      case 'kadabaw':
        return '88 kcal';
      default:
        return '86 kcal';
    }
  }

  void _show(BuildContext context) => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LibraryDetailSheet(variety: v),
  );
}

// ============================================================================
// LIBRARY DETAIL SHEET — 5 tabs
// ============================================================================

class _LibraryDetailSheet extends StatefulWidget {
  final CamoteVariety variety;
  const _LibraryDetailSheet({required this.variety});
  @override
  State<_LibraryDetailSheet> createState() => _LibraryDetailSheetState();
}

class _LibraryDetailSheetState extends State<_LibraryDetailSheet>
    with TickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.variety;
    final accentColor = _accent(v.name);
    final accentLightColor = _accentLight(v.name);
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, sc) => Container(
        decoration: const BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: C.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(v.name, style: T.title),
                        Text(
                          v.commonName,
                          style: TextStyle(
                            fontSize: 13,
                            color: accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: C.bg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: C.border),
                      ),
                      child: const Icon(
                        Icons.close,
                        size: 16,
                        color: C.textSec,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: C.border)),
              ),
              child: TabBar(
                controller: _tab,
                labelColor: accentColor,
                unselectedLabelColor: C.textSec,
                indicatorColor: accentColor,
                isScrollable: true,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Nutrition'),
                  Tab(text: 'Intake'),
                  Tab(text: 'Recipes'),
                  Tab(text: 'For Who'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  // ── OVERVIEW ─────────────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(C.paddingPage),
                    children: [
                      _ImageCarousel(imagePaths: v.imagePaths),
                      const SizedBox(height: 16),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader('Description'),
                            const SizedBox(height: 10),
                            Text(v.description, style: T.body),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader('Characteristics'),
                            const SizedBox(height: 4),
                            const Divider(height: 1, color: C.border),
                            _CharRow(Icons.straighten, 'Shape', v.shape),
                            const Divider(height: 1, color: C.border),
                            _CharRow(
                              Icons.palette_outlined,
                              'Skin Color',
                              v.skinColor,
                            ),
                            const Divider(height: 1, color: C.border),
                            _CharRow(
                              Icons.circle_outlined,
                              'Flesh Color',
                              v.fleshColor,
                            ),
                            const Divider(height: 1, color: C.border),
                            _CharRow(Icons.texture, 'Texture', v.texture),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader('Health Benefits'),
                            const SizedBox(height: 10),
                            ...v.benefits.map((b) => _bullet(b, accentColor)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Card(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _SectionHeader('Traditional Dishes'),
                            const SizedBox(height: 10),
                            ...v.dishes.map((d) => _bullet(d, accentColor)),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // ── NUTRITION ────────────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(C.paddingPage),
                    children: [
                      _Stagger(
                        index: 0,
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader('Per 100 g Serving'),
                              const SizedBox(height: 14),
                              GridView.count(
                                crossAxisCount: 2,
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                                childAspectRatio: 2.4,
                                children: [
                                  _nutCard(
                                    'Calories',
                                    v.medicalInfo.calories100g,
                                    Icons.local_fire_department,
                                  ),
                                  _nutCard(
                                    'Carbohydrates',
                                    v.medicalInfo.carbs100g,
                                    Icons.grain,
                                  ),
                                  _nutCard(
                                    'Dietary Fiber',
                                    v.medicalInfo.fiber,
                                    Icons.spa,
                                  ),
                                  _nutCard(
                                    'Potassium',
                                    v.medicalInfo.potassium,
                                    Icons.bolt,
                                  ),
                                  _nutCard(
                                    'Vitamin A',
                                    v.medicalInfo.vitaminA,
                                    Icons.visibility,
                                  ),
                                  _nutCard(
                                    'Vitamin C',
                                    v.medicalInfo.vitaminC,
                                    Icons.eco,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Stagger(
                        index: 1,
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader('Glycaemic Profile'),
                              const SizedBox(height: 12),
                              _giRow(
                                'Glycaemic Index',
                                v.medicalInfo.glycemicIndex,
                                accentColor,
                              ),
                              _giRow(
                                'Glycaemic Load',
                                v.medicalInfo.glycemicLoad,
                                accentColor,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Stagger(
                        index: 2,
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader('Medicinal Uses'),
                              const SizedBox(height: 10),
                              ...v.medicalInfo.medicinalUses.map(
                                (u) => _bullet(u, C.primary),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (v.medicalInfo.drugInteractions.isNotEmpty)
                        _Stagger(
                          index: 3,
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  'Drug Interactions',
                                  trailing: _Pill(
                                    'Consult a doctor',
                                    bg: C.warnLight,
                                    fg: C.warn,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...v.medicalInfo.drugInteractions.map(
                                  (d) => _warnItem(d, C.warn, C.warnLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (v.medicalInfo.contraindications.isNotEmpty)
                        _Stagger(
                          index: 4,
                          child: _Card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _SectionHeader(
                                  'Contraindications',
                                  trailing: _Pill(
                                    'Important',
                                    bg: C.errLight,
                                    fg: C.err,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                ...v.medicalInfo.contraindications.map(
                                  (d) => _warnItem(d, C.err, C.errLight),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),

                  // ── INTAKE ────────────────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(C.paddingPage),
                    children: [
                      _Stagger(
                        index: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                accentColor,
                                accentColor.withOpacity(0.78),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(C.radiusCard),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Recommended Intake',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _intakeHero('Daily Max', v.intake.dailyMax),
                                  const SizedBox(width: 10),
                                  _intakeHero('Weekly Max', v.intake.weeklyMax),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  _intakeHero(
                                    'Serving Size',
                                    v.intake.servingSize,
                                  ),
                                  const SizedBox(width: 10),
                                  _intakeHero('Best Time', v.intake.bestTime),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Stagger(
                        index: 1,
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.block,
                                    size: 17,
                                    color: C.warn,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('Limitations', style: T.subhead),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...v.intake.limitations.map(
                                (l) => _warnItem(l, C.warn, C.warnLight),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Stagger(
                        index: 2,
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 17,
                                    color: C.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text('General Cautions', style: T.subhead),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ...v.intake.cautions.map(
                                (c) => _warnItem(c, C.warn, C.warnLight),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Stagger(
                        index: 3,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: C.primaryLight,
                            borderRadius: BorderRadius.circular(C.radiusCard),
                            border: Border.all(
                              color: C.primary.withOpacity(0.18),
                            ),
                          ),
                          child: const Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.health_and_safety_outlined,
                                color: C.primary,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Consult a nutritionist or physician before major dietary changes.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: C.primary,
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── RECIPES ───────────────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(C.paddingPage),
                    children: v.recipes
                        .asMap()
                        .entries
                        .map(
                          (e) => _Stagger(
                            index: e.key,
                            child: _ExpandableRecipeCard(
                              recipe: e.value,
                              accentColor: accentColor,
                            ),
                          ),
                        )
                        .toList(),
                  ),

                  // ── FOR WHO ───────────────────────────────────────────────────
                  ListView(
                    padding: const EdgeInsets.all(C.paddingPage),
                    children: [
                      _Stagger(
                        index: 0,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                accentColor.withOpacity(0.1),
                                accentLightColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(C.radiusCard),
                            border: Border.all(
                              color: accentColor.withOpacity(0.18),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    color: accentColor,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Recommended For',
                                    style: T.heading.copyWith(
                                      color: accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ...v.targetedPeople.asMap().entries.map(
                                (e) => _Stagger(
                                  index: e.key,
                                  child: Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 28,
                                          height: 28,
                                          decoration: BoxDecoration(
                                            color: accentColor,
                                            shape: BoxShape.circle,
                                          ),
                                          child: Center(
                                            child: Text(
                                              '${e.key + 1}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.only(
                                              top: 5,
                                            ),
                                            child: Text(
                                              e.value,
                                              style: T.body.copyWith(
                                                color: C.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Stagger(
                        index: 1,
                        child: _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const _SectionHeader('Health Benefits'),
                              const SizedBox(height: 10),
                              ...v.benefits.asMap().entries.map(
                                (e) => _Stagger(
                                  index: e.key,
                                  child: _bullet(e.value, accentColor),
                                ),
                              ),
                            ],
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

  Widget _nutCard(String label, String value, IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: C.primary.withOpacity(0.06),
      borderRadius: BorderRadius.circular(C.radiusInner),
      border: Border.all(color: C.primary.withOpacity(0.14)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: C.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: C.primary.withOpacity(0.7),
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: C.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _giRow(String label, String value, Color accentColor) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Expanded(child: Text(label, style: T.label)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _intakeHero(String label, String value) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(C.radiusInner),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    ),
  );
}

// ── Expandable recipe card (Library recipes tab) ──────────────────────────────
class _ExpandableRecipeCard extends StatefulWidget {
  final CamoteRecipe recipe;
  final Color accentColor;
  const _ExpandableRecipeCard({
    required this.recipe,
    required this.accentColor,
  });
  @override
  State<_ExpandableRecipeCard> createState() => _ExpandableRecipeCardState();
}

class _ExpandableRecipeCardState extends State<_ExpandableRecipeCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final r = widget.recipe;
    final accent = widget.accentColor;
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: C.surface,
          borderRadius: BorderRadius.circular(C.radiusCard),
          border: Border.all(
            color: _expanded ? accent.withOpacity(0.35) : C.border,
            width: _expanded ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _expanded
                  ? accent.withOpacity(0.1)
                  : const Color(0x08000000),
              blurRadius: _expanded ? 14 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(C.radiusCard - 1),
                    bottomLeft: Radius.circular(C.radiusCard - 1),
                  ),
                  child: SizedBox(
                    width: 90,
                    height: 90,
                    child: Image.asset(
                      r.imagePath,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: accent.withOpacity(0.1),
                        child: Icon(
                          Icons.restaurant_menu,
                          color: accent,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(r.name, style: T.subhead),
                        const SizedBox(height: 4),
                        Text(
                          r.description,
                          style: T.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _chip(r.difficulty, Icons.bar_chart, accent),
                            const SizedBox(width: 6),
                            _chip(
                              '${r.calories} kcal',
                              Icons.local_fire_department_outlined,
                              accent,
                            ),
                            const Spacer(),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: C.textMuted,
                              size: 20,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_expanded) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: const Divider(height: 1, color: C.border),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _metaItem('Prep', r.prepTime, Icons.access_time, accent),
                    Container(width: 1, height: 30, color: C.border),
                    _metaItem(
                      'Cook',
                      r.cookTime,
                      Icons.local_fire_department_outlined,
                      accent,
                    ),
                    Container(width: 1, height: 30, color: C.border),
                    _metaItem(
                      'Serves',
                      '${r.servings}',
                      Icons.people_outline,
                      accent,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(
                  'Ingredients',
                  style: T.label.copyWith(color: accent),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Column(
                  children: r.ingredients
                      .map(
                        (i) => Padding(
                          padding: const EdgeInsets.only(bottom: 5),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text(i, style: T.body)),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Text('Steps', style: T.label.copyWith(color: accent)),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  children: r.steps
                      .asMap()
                      .entries
                      .map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  color: accent,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    '${e.key + 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(e.value, style: T.body),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
  Widget _metaItem(String label, String value, IconData icon, Color color) =>
      Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 2),
          Text(label, style: T.caption),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      );
}

// ============================================================================
// EXTENSIONS
// ============================================================================

extension StringX on String {
  String get cap => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
