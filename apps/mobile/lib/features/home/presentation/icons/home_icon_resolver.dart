import 'package:flutter/material.dart';

abstract final class HomeIconResolver {
  static IconData resolve(String key) => switch (key) {
    'home' => Icons.home_outlined,
    'ac' => Icons.ac_unit,
    'plumbing' => Icons.plumbing_outlined,
    'electrical' => Icons.bolt_outlined,
    'laundry' => Icons.local_laundry_service_outlined,
    'refrigerator' => Icons.kitchen_outlined,
    'microwave' => Icons.microwave_outlined,
    'more' => Icons.grid_view_rounded,
    'verified' => Icons.verified_user_outlined,
    'pricing' => Icons.payments_outlined,
    'warranty' => Icons.event_available_outlined,
    'location' => Icons.location_on_outlined,
    'calendar' => Icons.calendar_today_outlined,
    'search' => Icons.search_rounded,
    'fast' => Icons.bolt_rounded,
    _ => Icons.handyman_outlined,
  };
}
