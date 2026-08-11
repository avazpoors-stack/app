import 'dart:convert';

/// مدل‌های دامنهٔ «بدنه» — همهٔ ماژول‌ها از همین تعریف‌ها استفاده می‌کنند
/// (قرارداد اینترفیس نقشهٔ راه ۲.۵: مدل‌های مشترک در core).

enum EnergyLevel { high, normal, low }

extension EnergyLevelX on EnergyLevel {
  String get labelFa => switch (this) {
        EnergyLevel.high => 'زیاد 🔥',
        EnergyLevel.normal => 'معمولی 🙂',
        EnergyLevel.low => 'کم 😴',
      };

  String get descFa => switch (this) {
        EnergyLevel.high => 'پرانرژی؛ برنامهٔ کامل امروز',
        EnergyLevel.normal => 'حالت معمولی؛ برنامهٔ امروز',
        EnergyLevel.low => 'روز خسته‌ای؛ تمرین کوتاه ۱۰ دقیقه‌ای',
      };

  static EnergyLevel fromName(String? name) => switch (name) {
        'high' => EnergyLevel.high,
        'low' => EnergyLevel.low,
        _ => EnergyLevel.normal,
      };
}

enum CoachTone { direct, supportive, playful }

extension CoachToneX on CoachTone {
  String get labelFa => switch (this) {
        CoachTone.direct => 'مستقیم',
        CoachTone.supportive => 'حمایتگر',
        CoachTone.playful => 'شوخ',
      };

  String get descFa => switch (this) {
        CoachTone.direct => 'جدی و کوتاه',
        CoachTone.supportive => 'همدل و تشویق‌کننده',
        CoachTone.playful => 'بازیگوش با کمی طعنه',
      };

  static CoachTone fromName(String? name) => switch (name) {
        'direct' => CoachTone.direct,
        'playful' => CoachTone.playful,
        _ => CoachTone.supportive,
      };
}

class Exercise {
  const Exercise({
    required this.id,
    required this.nameFa,
    required this.muscle,
    required this.equipment,
    required this.tipFa,
    this.corrective = false,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
        id: json['id'] as String,
        nameFa: json['nameFa'] as String,
        muscle: json['muscle'] as String? ?? '',
        equipment: json['equipment'] as String? ?? '',
        tipFa: json['tipFa'] as String? ?? '',
        corrective: json['corrective'] as bool? ?? false,
      );

  final String id;
  final String nameFa;
  final String muscle;
  final String equipment;
  final String tipFa;
  final bool corrective;
}

class SessionExercise {
  const SessionExercise({
    required this.exerciseId,
    required this.sets,
    required this.reps,
    required this.restSec,
  });

  factory SessionExercise.fromJson(Map<String, dynamic> json) =>
      SessionExercise(
        exerciseId: json['exerciseId'] as String,
        sets: json['sets'] as int,
        reps: json['reps'] as int,
        restSec: json['restSec'] as int? ?? 60,
      );

  final String exerciseId;
  final int sets;
  final int reps;
  final int restSec;
}

class ProgramSession {
  const ProgramSession({
    required this.id,
    required this.name,
    required this.exercises,
  });

  factory ProgramSession.fromJson(Map<String, dynamic> json) =>
      ProgramSession(
        id: json['id'] as String,
        name: json['name'] as String,
        exercises: (json['exercises'] as List<dynamic>)
            .map((e) => SessionExercise.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final List<SessionExercise> exercises;
}

class WorkoutProgram {
  const WorkoutProgram({
    required this.id,
    required this.name,
    required this.level,
    required this.location,
    required this.daysPerWeek,
    required this.focus,
    required this.sessions,
  });

  factory WorkoutProgram.fromJson(Map<String, dynamic> json) => WorkoutProgram(
        id: json['id'] as String,
        name: json['name'] as String,
        level: json['level'] as String,
        location: json['location'] as String,
        daysPerWeek: json['daysPerWeek'] as int,
        focus: json['focus'] as String,
        sessions: (json['sessions'] as List<dynamic>)
            .map((s) => ProgramSession.fromJson(s as Map<String, dynamic>))
            .toList(),
      );

  final String id;
  final String name;
  final String level;
  final String location;
  final int daysPerWeek;
  final String focus;
  final List<ProgramSession> sessions;
}

class Rank {
  const Rank({required this.name, required this.emoji, required this.minPoints});

  factory Rank.fromJson(Map<String, dynamic> json) => Rank(
        name: json['name'] as String,
        emoji: json['emoji'] as String,
        minPoints: json['minPoints'] as int,
      );

  final String name;
  final String emoji;
  final int minPoints;
}

class WorkoutEntry {
  const WorkoutEntry({
    required this.date,
    required this.programId,
    required this.sessionId,
    required this.points,
  });

  factory WorkoutEntry.fromJson(Map<String, dynamic> json) => WorkoutEntry(
        date: json['date'] as String,
        programId: json['programId'] as String,
        sessionId: json['sessionId'] as String,
        points: json['points'] as int,
      );

  final String date; // yyyy-MM-dd
  final String programId;
  final String sessionId;
  final int points;

  Map<String, dynamic> toJson() => {
        'date': date,
        'programId': programId,
        'sessionId': sessionId,
        'points': points,
      };
}

class UserProgress {
  UserProgress({
    this.totalPoints = 0,
    List<WorkoutEntry>? workouts,
    this.energyLevel,
    this.energyDate,
    this.activeProgramId = 'starter',
    this.tone = CoachTone.supportive,
  }) : workouts = workouts ?? [];

  factory UserProgress.fromJson(Map<String, dynamic> json) => UserProgress(
        totalPoints: json['totalPoints'] as int? ?? 0,
        workouts: (json['workouts'] as List<dynamic>? ?? [])
            .map((w) => WorkoutEntry.fromJson(w as Map<String, dynamic>))
            .toList(),
        energyLevel: EnergyLevelX.fromName(json['energyLevel'] as String?),
        energyDate: json['energyDate'] as String?,
        activeProgramId: json['activeProgramId'] as String? ?? 'starter',
        tone: CoachToneX.fromName(json['tone'] as String?),
      );

  int totalPoints;
  final List<WorkoutEntry> workouts;
  EnergyLevel? energyLevel;
  String? energyDate; // روزی که انرژی انتخاب شده (yyyy-MM-dd)
  String activeProgramId;
  CoachTone tone;

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'workouts': workouts.map((w) => w.toJson()).toList(),
        'energyLevel': energyLevel?.name,
        'energyDate': energyDate,
        'activeProgramId': activeProgramId,
        'tone': tone.name,
      };

  String toJsonString() => jsonEncode(toJson());
}

class WorkoutResult {
  const WorkoutResult({
    required this.breakdown,
    required this.earned,
    required this.totalPoints,
    required this.streak,
    required this.rank,
    required this.isFirst,
  });

  final Map<String, int> breakdown; // sets / exercises / workout / first / streak
  final int earned;
  final int totalPoints;
  final int streak;
  final Rank rank;
  final bool isFirst;
}

// ================= P2: حساب‌ها و سینک =================

enum AccountRole { customer, seller, venue, coach, admin }

extension AccountRoleX on AccountRole {
  String get labelFa => switch (this) {
        AccountRole.customer => 'مشتری',
        AccountRole.seller => 'فروشنده',
        AccountRole.venue => 'باشگاه/مکان',
        AccountRole.coach => 'مربی',
        AccountRole.admin => 'ادمین',
      };

  String get descFa => switch (this) {
        AccountRole.customer => 'فقط تمرین و ذخیرهٔ پیشرفت',
        AccountRole.seller => 'پنل فروشگاه (فاز P5)',
        AccountRole.venue => 'ثبت باشگاه/مکان (فاز P4)',
        AccountRole.coach => 'مربی‌هاب (فاز P6)',
        AccountRole.admin => 'مدیریت سرویس',
      };

  static AccountRole fromName(String? name) => switch (name) {
        'seller' => AccountRole.seller,
        'venue' => AccountRole.venue,
        'coach' => AccountRole.coach,
        'admin' => AccountRole.admin,
        _ => AccountRole.customer,
      };
}

class UserAccount {
  const UserAccount({
    required this.phone,
    required this.name,
    required this.role,
    required this.accessToken,
    required this.refreshToken,
  });

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
        phone: json['phone'] as String,
        name: json['name'] as String? ?? '',
        role: AccountRoleX.fromName(json['role'] as String?),
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );

  final String phone;
  final String name;
  final AccountRole role;
  final String accessToken;
  final String refreshToken;

  Map<String, dynamic> toJson() => {
        'phone': phone,
        'name': name,
        'role': role.name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };
}

/// رکورد تمرین برای سینک — همان WorkoutEntry + شناسهٔ دستگاه + زمان تغییر.
class SyncEntry {
  const SyncEntry({
    required this.date,
    required this.programId,
    required this.sessionId,
    required this.points,
    required this.clientUid,
    required this.updatedAt,
  });

  factory SyncEntry.fromJson(Map<String, dynamic> json) => SyncEntry(
        date: json['date'] as String,
        programId: json['programId'] as String,
        sessionId: json['sessionId'] as String,
        points: json['points'] as int,
        clientUid: json['clientUid'] as String? ?? '',
        updatedAt: json['updatedAt'] as String,
      );

  final String date; // yyyy-MM-dd
  final String programId;
  final String sessionId;
  final int points;
  final String clientUid;
  final String updatedAt; // ISO 8601

  Map<String, dynamic> toJson() => {
        'date': date,
        'programId': programId,
        'sessionId': sessionId,
        'points': points,
        'clientUid': clientUid,
        'updatedAt': updatedAt,
      };

  WorkoutEntry toWorkoutEntry() => WorkoutEntry(
        date: date,
        programId: programId,
        sessionId: sessionId,
        points: points,
      );
}

class SyncProfile {
  const SyncProfile({
    required this.totalPoints,
    required this.tone,
    required this.activeProgramId,
    required this.updatedAt,
  });

  factory SyncProfile.fromJson(Map<String, dynamic> json) => SyncProfile(
        totalPoints: json['totalPoints'] as int? ?? 0,
        tone: json['tone'] as String? ?? 'supportive',
        activeProgramId: json['activeProgramId'] as String? ?? 'starter',
        updatedAt: json['updatedAt'] as String? ?? '',
      );

  final int totalPoints;
  final String tone;
  final String activeProgramId;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
        'totalPoints': totalPoints,
        'tone': tone,
        'activeProgramId': activeProgramId,
        'updatedAt': updatedAt,
      };
}

class SyncState {
  const SyncState({
    required this.entries,
    required this.profile,
    required this.totalPoints,
    required this.serverTime,
  });

  factory SyncState.fromJson(Map<String, dynamic> json) => SyncState(
        entries: (json['entries'] as List<dynamic>? ?? [])
            .map((e) => SyncEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        profile: SyncProfile.fromJson(
            (json['profile'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
        totalPoints:
            (json['totalPoints'] as int?) ?? (json['total_points'] as int?) ?? 0,
        serverTime:
            (json['serverTime'] as String?) ?? (json['server_time'] as String?) ?? '',
      );

  final List<SyncEntry> entries;
  final SyncProfile profile;
  final int totalPoints;
  final String serverTime;

  Map<String, dynamic> toJson() => {
        'entries': entries.map((e) => e.toJson()).toList(),
        'profile': profile.toJson(),
        'totalPoints': totalPoints,
        'serverTime': serverTime,
      };
}

// ================= P3: جستجوی سراسری =================

enum SearchCategory { exercise, program, product, venue, coach }

extension SearchCategoryX on SearchCategory {
  String get labelFa => switch (this) {
        SearchCategory.exercise => 'حرکت',
        SearchCategory.program => 'برنامه',
        SearchCategory.product => 'محصول',
        SearchCategory.venue => 'مکان',
        SearchCategory.coach => 'مربی',
      };

  String get sectionFa => switch (this) {
        SearchCategory.exercise => 'حرکات تمرینی',
        SearchCategory.program => 'برنامه‌ها',
        SearchCategory.product => 'فروشگاه',
        SearchCategory.venue => 'مکان‌های ورزشی',
        SearchCategory.coach => 'مربی‌هاب',
      };

  static SearchCategory fromName(String? name) => switch (name) {
        'program' => SearchCategory.program,
        'product' => SearchCategory.product,
        'venue' => SearchCategory.venue,
        'coach' => SearchCategory.coach,
        _ => SearchCategory.exercise,
      };
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.category,
    this.source = 'local',
    this.comingSoon = false,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? (json['titleFa'] as String?) ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        category: SearchCategoryX.fromName(json['category'] as String?),
        source: json['source'] as String? ?? 'remote',
        comingSoon:
            (json['comingSoon'] as bool?) ?? (json['coming_soon'] as bool?) ?? false,
      );

  final String id;
  final String title;
  final String subtitle;
  final SearchCategory category;
  final String source; // local / remote / mock
  final bool comingSoon; // محصول/مکان/مربی تا فازهای بعد فقط پیش‌نمایش‌اند

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subtitle': subtitle,
        'category': category.name,
        'source': source,
        'comingSoon': comingSoon,
      };
}


// ================= P4: مکان‌های ورزشی =================

enum VenueCategory {
  pool,
  gym,
  martialArts,
  yoga,
  crossfit,
  ballSports,
  tennis,
  running,
  corrective,
}

extension VenueCategoryX on VenueCategory {
  String get apiName => switch (this) {
        VenueCategory.pool => 'pool',
        VenueCategory.gym => 'gym',
        VenueCategory.martialArts => 'martial_arts',
        VenueCategory.yoga => 'yoga',
        VenueCategory.crossfit => 'crossfit',
        VenueCategory.ballSports => 'ball_sports',
        VenueCategory.tennis => 'tennis',
        VenueCategory.running => 'running',
        VenueCategory.corrective => 'corrective',
      };

  String get labelFa => switch (this) {
        VenueCategory.pool => 'استخر',
        VenueCategory.gym => 'بدنسازی',
        VenueCategory.martialArts => 'رزمی',
        VenueCategory.yoga => 'یوگا/پیلاتس',
        VenueCategory.crossfit => 'کراس‌فیت/ایروبیک',
        VenueCategory.ballSports => 'توپی',
        VenueCategory.tennis => 'تنیس/راکت',
        VenueCategory.running => 'دو/پارک',
        VenueCategory.corrective => 'حرکت اصلاحی',
      };

  String get descFa => switch (this) {
        VenueCategory.pool => 'شنا، آب‌درمانی و سانس‌های آزاد',
        VenueCategory.gym => 'وزنه، دستگاه و تمرین قدرتی',
        VenueCategory.martialArts => 'بوکس، کاراته، تکواندو و MMA',
        VenueCategory.yoga => 'یوگا، پیلاتس، انعطاف و تنفس',
        VenueCategory.crossfit => 'کلاس گروهی، HIIT و کراس‌فیت',
        VenueCategory.ballSports => 'فوتبال، والیبال، بسکتبال و سالن‌های توپی',
        VenueCategory.tennis => 'تنیس، پدل، بدمینتون و راکتی',
        VenueCategory.running => 'پیست، پارک و مسیر تمرین هوازی',
        VenueCategory.corrective => 'حرکت اصلاحی و بازتوانی غیرتشخیصی',
      };

  static VenueCategory fromName(String? name) => switch (name) {
        'gym' => VenueCategory.gym,
        'martial_arts' || 'martialArts' => VenueCategory.martialArts,
        'yoga' => VenueCategory.yoga,
        'crossfit' => VenueCategory.crossfit,
        'ball_sports' || 'ballSports' => VenueCategory.ballSports,
        'tennis' => VenueCategory.tennis,
        'running' => VenueCategory.running,
        'corrective' => VenueCategory.corrective,
        _ => VenueCategory.pool,
      };
}

enum VenueStatus { pending, approved, rejected }

extension VenueStatusX on VenueStatus {
  String get labelFa => switch (this) {
        VenueStatus.pending => 'در انتظار تأیید',
        VenueStatus.approved => 'تأیید شده',
        VenueStatus.rejected => 'رد شده',
      };

  static VenueStatus fromName(String? name) => switch (name) {
        'approved' => VenueStatus.approved,
        'rejected' => VenueStatus.rejected,
        _ => VenueStatus.pending,
      };
}

class VenueTariff {
  const VenueTariff({required this.title, required this.priceToman, this.note = ''});

  factory VenueTariff.fromJson(Map<String, dynamic> json) => VenueTariff(
        title: json['title'] as String? ?? '',
        priceToman: (json['priceToman'] as int?) ?? (json['price_toman'] as int?) ?? 0,
        note: json['note'] as String? ?? '',
      );

  final String title;
  final int priceToman;
  final String note;

  Map<String, dynamic> toJson() => {
        'title': title,
        'price_toman': priceToman,
        if (note.isNotEmpty) 'note': note,
      };
}

class VenueDraft {
  const VenueDraft({
    required this.name,
    required this.category,
    required this.address,
    this.city = '',
    this.phone = '',
    this.description = '',
    this.lat,
    this.lng,
    this.tariffs = const [],
  });

  final String name;
  final VenueCategory category;
  final String address;
  final String city;
  final String phone;
  final String description;
  final double? lat;
  final double? lng;
  final List<VenueTariff> tariffs;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category.apiName,
        'city': city,
        'address': address,
        'phone': phone,
        'description': description,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'tariffs': tariffs.map((t) => t.toJson()).toList(),
      };
}

class Venue {
  const Venue({
    required this.id,
    required this.name,
    required this.category,
    required this.address,
    required this.status,
    this.city = '',
    this.phone = '',
    this.description = '',
    this.lat,
    this.lng,
    this.tariffs = const [],
    this.source = 'local',
  });

  factory Venue.fromJson(Map<String, dynamic> json) => Venue(
        id: json['id'].toString(),
        name: json['name'] as String? ?? '',
        category: VenueCategoryX.fromName(json['category'] as String?),
        city: json['city'] as String? ?? '',
        address: json['address'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        description: json['description'] as String? ?? '',
        lat: (json['lat'] as num?)?.toDouble(),
        lng: (json['lng'] as num?)?.toDouble(),
        tariffs: (json['tariffs'] as List<dynamic>? ?? [])
            .map((t) => VenueTariff.fromJson(t as Map<String, dynamic>))
            .toList(),
        status: VenueStatusX.fromName(json['status'] as String?),
        source: json['source'] as String? ?? 'remote',
      );

  factory Venue.fromDraft(VenueDraft draft, {required String id}) => Venue(
        id: id,
        name: draft.name,
        category: draft.category,
        city: draft.city,
        address: draft.address,
        phone: draft.phone,
        description: draft.description,
        lat: draft.lat,
        lng: draft.lng,
        tariffs: draft.tariffs,
        status: VenueStatus.pending,
        source: 'local',
      );

  final String id;
  final String name;
  final VenueCategory category;
  final String city;
  final String address;
  final String phone;
  final String description;
  final double? lat;
  final double? lng;
  final List<VenueTariff> tariffs;
  final VenueStatus status;
  final String source;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.apiName,
        'city': city,
        'address': address,
        'phone': phone,
        'description': description,
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        'tariffs': tariffs.map((t) => t.toJson()).toList(),
        'status': status.name,
        'source': source,
      };
}

// ================= P5: فروشگاه ورزشی =================

class Product {
  const Product({
    required this.id,
    required this.sellerId,
    required this.name,
    required this.category,
    required this.brand,
    required this.priceToman,
    required this.stock,
    required this.approved,
    this.source = 'local',
  });

  factory Product.fromJson(Map<String, dynamic> json) => Product(
        id: json['id'].toString(),
        sellerId: (json['seller_id'] as int?) ?? (json['sellerId'] as int?) ?? 0,
        name: json['name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        brand: json['brand'] as String? ?? '',
        priceToman: (json['price_toman'] as int?) ?? (json['priceToman'] as int?) ?? 0,
        stock: json['stock'] as int? ?? 0,
        approved: json['approved'] as bool? ?? false,
        source: json['source'] as String? ?? 'remote',
      );

  factory Product.fromDraft(ProductDraft draft, {required String id, required int sellerId}) =>
      Product(
        id: id,
        sellerId: sellerId,
        name: draft.name,
        category: draft.category,
        brand: draft.brand,
        priceToman: draft.priceToman,
        stock: draft.stock,
        approved: false,
        source: 'local',
      );

  final String id;
  final int sellerId;
  final String name;
  final String category;
  final String brand;
  final int priceToman;
  final int stock;
  final bool approved;
  final String source;

  Map<String, dynamic> toJson() => {
        'id': id,
        'seller_id': sellerId,
        'name': name,
        'category': category,
        'brand': brand,
        'price_toman': priceToman,
        'stock': stock,
        'approved': approved,
        'source': source,
      };
}

class ProductDraft {
  const ProductDraft({
    required this.name,
    required this.category,
    required this.brand,
    required this.priceToman,
    required this.stock,
  });

  final String name;
  final String category;
  final String brand;
  final int priceToman;
  final int stock;

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': category,
        'brand': brand,
        'price_toman': priceToman,
        'stock': stock,
      };
}

class CartItem {
  const CartItem({required this.product, required this.quantity});

  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem(
        product: Product.fromJson(json['product'] as Map<String, dynamic>),
        quantity: json['quantity'] as int? ?? 1,
      );

  final Product product;
  final int quantity;

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'quantity': quantity,
      };
}

class OrderItemDraft {
  const OrderItemDraft({
    required this.productId,
    required this.quantity,
    required this.priceToman,
  });

  final String productId;
  final int quantity;
  final int priceToman;

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'price_toman': priceToman,
      };
}

class OrderResult {
  const OrderResult({
    required this.orderId,
    required this.status,
    required this.totalToman,
    this.paymentUrl,
  });

  factory OrderResult.fromJson(Map<String, dynamic> json) => OrderResult(
        orderId: json['order_id'] as String? ?? (json['orderId'] as String?) ?? '',
        status: json['status'] as String? ?? 'payment_pending',
        totalToman: (json['total_toman'] as int?) ?? (json['totalToman'] as int?) ?? 0,
        paymentUrl: json['payment_url'] as String? ?? json['paymentUrl'] as String?,
      );

  final String orderId;
  final String status;
  final int totalToman;
  final String? paymentUrl;

  Map<String, dynamic> toJson() => {
        'order_id': orderId,
        'status': status,
        'total_toman': totalToman,
        if (paymentUrl != null) 'payment_url': paymentUrl,
      };
}

