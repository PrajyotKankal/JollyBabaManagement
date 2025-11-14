// lib/services/parse_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/ticket_model.dart';

List<Ticket> _parseTicketsSync(String body) {
  final data = json.decode(body) as List<dynamic>;
  return data.map((e) => Ticket.fromJson(e as Map<String, dynamic>)).toList();
}

/// Use this in your service to parse in background isolate
Future<List<Ticket>> parseTickets(String body) => compute(_parseTicketsSync, body);
