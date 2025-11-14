import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/ticket_service.dart';
import 'ticket_details_screen.dart';

class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  List<dynamic> tickets = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => isLoading = true);
    final result = await TicketService.fetchTickets();

    if (!mounted) return;
    setState(() {
      tickets = result;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FF),
      appBar: AppBar(
        title: Text(
          "🎫 All Tickets",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: const Color(0xFF2A2E45),
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchTickets,
        color: const Color(0xFF6D5DF6),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF6D5DF6)),
              )
            : tickets.isEmpty
                ? Center(
                    child: Text(
                      "No tickets found.",
                      style: GoogleFonts.poppins(
                        color: Colors.black45,
                        fontSize: 14,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: tickets.length,
                    itemBuilder: (context, index) {
                      final ticket = tickets[index];
                      return _ticketCard(ticket)
                          .animate()
                          .fadeIn(duration: 350.ms)
                          .slideY(begin: 0.1);
                    },
                  ),
      ),
    );
  }

  Widget _ticketCard(Map<String, dynamic> ticket) {
    return GestureDetector(
      onTap: () async {
        // 👇 open details page with smooth transition
        final result = await Get.to(
          () => TicketDetailsScreen(ticket: ticket),
          transition: Transition.cupertino,
          duration: 300.ms,
        );

        // 🔄 refresh after save
        if (result == true) _fetchTickets();
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.95),
              Colors.white.withValues(alpha: 0.90),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6D5DF6).withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: const Color(0xFF6D5DF6).withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket["customer_name"] ?? "Unnamed",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF2A2E45),
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ticket["device_model"] ?? "Unknown Device",
                    style: GoogleFonts.poppins(
                      color: Colors.black54,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.phone, size: 14, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        ticket["mobile_number"] ?? "-",
                        style: GoogleFonts.poppins(
                          color: Colors.black45,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Status Tag (Right Side)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _statusColor(ticket["status"]).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                ticket["status"] ?? "Pending",
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _statusColor(ticket["status"]),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case "Repaired":
        return const Color(0xFF4CAF50);
      case "Delivered":
        return const Color(0xFF2196F3);
      case "Cancelled":
        return const Color(0xFFF44336);
      default:
        return const Color(0xFFFFC107);
    }
  }
}
