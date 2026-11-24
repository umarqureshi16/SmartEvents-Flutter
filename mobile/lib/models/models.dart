import '../core/api_client.dart';
import '../core/format.dart';

String? idOf(dynamic v) {
  if (v == null) return null;
  if (v is Map) return (v['_id'] ?? v['id'])?.toString();
  return v.toString();
}

num _num(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
Map<String, dynamic> _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
List<Map<String, dynamic>> _list(dynamic v) => v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : [];

class AppUser {
  AppUser(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get name => raw['name'] as String? ?? 'You';
  String get email => raw['email'] as String? ?? '';
  String get role => raw['role'] as String? ?? 'customer';
  bool get isVendor => role == 'provider';
  bool get isAdmin => role == 'admin' || role == 'superadmin';
  num get trustScore => _num(raw['trustScore'] ?? 100);
  String? get avatar => Api.absolute(_map(raw['profile'])['avatar'] as String?);
  /// Country from the profile (sets the currency); null on servers without it.
  String? get country => _map(raw['locale'])['country'] as String?;
  String get roleLabel => const {'customer': 'Organizer', 'provider': 'Vendor', 'admin': 'Admin', 'superadmin': 'Super admin'}[role] ?? titleCase(role);
}

class EventItem {
  EventItem(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get title => raw['title'] as String? ?? 'Event';
  String get description => raw['description'] as String? ?? '';
  String get category => raw['category'] as String? ?? 'Event';
  String get location => raw['location'] as String? ?? '';
  num get price => _num(raw['price']);
  int get capacity => _num(raw['capacity']).toInt();
  DateTime? get date => parseDate(raw['date']);
  DateTime? get endDate => parseDate(raw['endDate']);
  String get status => raw['status'] as String? ?? 'upcoming';
  String? get image => Api.absolute(raw['image'] as String?);
  String? get vendorId => idOf(raw['createdBy']);
  /// The vendor's name when the API included it (vendor profile lists leave it out).
  String? get vendorName => _map(raw['createdBy'])['name'] as String?;
}

class Package {
  Package(this.raw);
  final Map<String, dynamic> raw;
  String get title => raw['title'] as String? ?? 'Package';
  num get price => _num(raw['price']);
  String get description => raw['description'] as String? ?? '';
  List<String> get includes => (raw['includes'] as List? ?? []).map((e) => '$e').toList();
}

class VendorItem {
  VendorItem(this.raw);
  final Map<String, dynamic> raw;
  Map<String, dynamic> get _user => _map(raw['userId']);
  /// The vendor's user id (what bookings and profiles are keyed by).
  String get userId => idOf(raw['userId']) ?? idOf(raw)!;
  String get name => raw['businessName'] as String? ?? _user['name'] as String? ?? 'Vendor';
  String get category => raw['category'] as String? ?? '';
  String get location => raw['location'] as String? ?? '';
  String get tagline => raw['tagline'] as String? ?? '';
  String get description => raw['description'] as String? ?? '';
  String? get cover => Api.absolute(raw['coverImage'] as String?) ??
      (gallery.isNotEmpty ? gallery.first : null);
  List<String> get gallery => [
        ...((raw['gallery'] as List?) ?? const []),
        ...((raw['portfolioImages'] as List?) ?? const []),
      ].map((e) => Api.absolute('$e')).whereType<String>().toSet().toList();
  num get rating => _num(raw['averageRating'] ?? raw['rating']);
  int get reviews => _num(raw['reviewsCount']).toInt();
  num get trustScore => _num(raw['trustScore'] ?? _user['trustScore'] ?? 70);
  num? get startingPrice => raw['startingPrice'] == null ? null : _num(raw['startingPrice']);
  bool get verified => raw['verified'] == true;
  List<Package> get packages => _list(raw['packages']).map(Package.new).toList();
  Map<String, dynamic> get stats => _map(raw['stats']);
}

class OfferEntry {
  OfferEntry(this.raw);
  final Map<String, dynamic> raw;
  String? get id => idOf(raw);
  num get price => _num(raw['price']);
  String get message => raw['message'] as String? ?? '';
  String get action => raw['action'] as String? ?? 'counter';
  String? get by => idOf(raw['offeredBy']);
  DateTime? get at => parseDate(raw['timestamp']);
  num? get previousPrice => raw['previousPrice'] == null ? null : _num(raw['previousPrice']);
  DateTime? get editedAt => parseDate(raw['editedAt']);
  bool get isFinal => action == 'accepted' || action == 'rejected';
}

class ChatMessage {
  ChatMessage(this.raw);
  final Map<String, dynamic> raw;
  String? get id => idOf(raw);
  String? get by => idOf(raw['author']);
  String get text => raw['text'] as String? ?? '';
  DateTime? get at => parseDate(raw['createdAt']);
}

class Booking {
  Booking(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get status => raw['status'] as String? ?? 'pending';
  num get offerPrice => _num(raw['offerPrice'] ?? raw['totalAmount']);
  String? get customerId => idOf(raw['customerId']);
  String? get vendorId => idOf(raw['vendorId']);
  String get customerName => _map(raw['customerId'])['name'] as String? ?? 'Organizer';
  String get vendorName => _map(raw['vendorId'])['name'] as String? ?? 'Vendor';
  Map<String, dynamic> get event => _map(raw['eventId']);
  Map<String, dynamic> get details => _map(raw['eventDetails']);
  Map<String, dynamic> get escrow => _map(raw['escrow']);
  num get listedPrice {
    final e = _num(event['price']);
    if (e > 0) return e;
    final s = _num(_map(raw['serviceId'])['price']);
    if (s > 0) return s;
    return history.isNotEmpty ? history.first.price : offerPrice;
  }

  String get title {
    if (event['title'] is String) return event['title'] as String;
    final service = _map(raw['serviceId'])['title'];
    if (service is String) return '$service package';
    final chosen = _list(raw['designConcepts']).where((c) => c['selected'] == true).map((c) => c['title']).firstWhere((t) => t != null, orElse: () => null);
    return chosen as String? ?? details['eventType'] as String? ?? 'Custom booking';
  }

  DateTime? get eventDate => parseDate(event['date'] ?? details['date']);
  DateTime? get eventEndDate => parseDate(event['endDate'] ?? details['endDate']);
  String get serviceCategory => _map(raw['serviceId'])['category'] as String? ?? '';
  /// The organizer's own event this booking belongs to (null when not filed).
  PlanRef? get plan => raw['planId'] is Map ? PlanRef(_map(raw['planId'])) : null;
  String get location => (event['location'] ?? details['location'] ?? '') as String;
  DateTime? get createdAt => parseDate(raw['createdAt']);
  List<OfferEntry> get history => _list(raw['negotiationHistory']).map(OfferEntry.new).toList();
  List<ChatMessage> get chat => _list(raw['chatMessages']).map(ChatMessage.new).toList();

  bool get isOpen => status == 'pending' || status == 'negotiating';
  bool get isAgreed => status == 'confirmed' || status == 'accepted' || status == 'completed';
  bool get isClosed => !isOpen && !isAgreed;

  String otherName(String myId) => myId == vendorId ? customerName : vendorName;

  /// True when the latest offer came from the other side (so it is my move).
  bool myTurn(String myId) {
    if (!isOpen) return false;
    final h = history;
    if (h.isEmpty) return myId == vendorId;
    return h.last.by != myId;
  }

  String get statusLabel => status == 'confirmed' ? 'Confirmed' : titleCase(status.replaceAll('_', ' '));
}

class TicketItem {
  TicketItem(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get number => raw['ticketNumber'] as String? ?? '';
  String get type => raw['ticketType'] as String? ?? 'General';
  String get status => raw['status'] as String? ?? 'valid';
  String? get qr => raw['qrCode'] as String?;
  EventItem? get event => raw['event'] is Map ? EventItem(_map(raw['event'])) : null;
}

class AppNotification {
  AppNotification(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get title => raw['title'] as String? ?? '';
  String get message => raw['message'] as String? ?? '';
  String get type => raw['type'] as String? ?? 'system';
  bool get read => raw['isRead'] == true;
  String? get relatedId => idOf(raw['relatedId']);
  DateTime? get at => parseDate(raw['createdAt']);
}

class DesignItem {
  DesignItem(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get title => raw['title'] as String? ?? 'Design';
  String get summary => raw['summary'] as String? ?? '';
  String get eventType => raw['eventType'] as String? ?? '';
  String get theme => raw['theme'] as String? ?? '';
  num get totalCost => _num(raw['totalCost']);
  String get imageUrl => Api.absolute(raw['image'] as String?) ?? Api.absolute('/api/v1/designs/$id/image')!;
  /// Picture of one part: 0 is the full setup, then each decor item.
  String partUrl(int part) => part == 0 ? imageUrl : Api.absolute('/api/v1/designs/$id/image?part=$part')!;
  List<Map<String, dynamic>> get elements => _list(raw['elements']);
  String get style => raw['style'] as String? ?? '';
  String get idea => raw['idea'] as String? ?? '';
  bool get published => raw['published'] == true;
  List<String> get palette => (raw['palette'] as List? ?? []).map((e) => '$e').toList();
}

/// The short form of an organizer's event, as it comes with a booking.
class PlanRef {
  PlanRef(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get title => raw['title'] as String? ?? 'Event';
  String get eventType => raw['eventType'] as String? ?? 'Event';
  String get location => raw['location'] as String? ?? '';
  DateTime? get date => parseDate(raw['date']);
  DateTime? get endDate => parseDate(raw['endDate']);
  num? get budget => raw['budget'] == null ? null : _num(raw['budget']);
}

class PlanTask {
  PlanTask(this.raw);
  final Map<String, dynamic> raw;
  String get id => idOf(raw)!;
  String get title => raw['title'] as String? ?? '';
  String get description => raw['description'] as String? ?? '';
  String? get category => raw['category'] as String?;
  int get daysBefore => _num(raw['daysBefore']).toInt();
  DateTime? get due => parseDate(raw['dueDate']);
  bool get done => raw['status'] == 'done';
  String? get bookingId => idOf(raw['bookingId']);
}

/// An organizer's event plan: dates (one or several days), place, budget and checklist.
class EventPlan extends PlanRef {
  EventPlan(super.raw);
  List<PlanTask> get tasks => _list(raw['tasks']).map(PlanTask.new).toList();
  int get doneCount => tasks.where((t) => t.done).length;
}
