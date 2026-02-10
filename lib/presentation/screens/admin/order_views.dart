import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';

// Simple model for orders (local to this file for now as per request scope)
class OrderModel {
  final String id;
  final String tableNumber;
  final double totalAmount;
  final String status;
  final List<dynamic> items; // List of maps
  final DateTime createdAt;
  final String? ownerId;

  OrderModel({
    required this.id,
    required this.tableNumber,
    required this.totalAmount,
    required this.status,
    required this.items,
    required this.createdAt,
    this.ownerId,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String id) {
    return OrderModel(
      id: id,
      tableNumber: map['tableNumber']?.toString() ?? '?',
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0.0,
      status: map['status']?.toString() ?? 'pending',
      items: (map['items'] as List?) ?? [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      ownerId: map['ownerId']?.toString(),
    );
  }
}

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  // Use a stream for real-time updates of incoming orders
  Stream<List<OrderModel>>? _ordersStream;
  bool _showCompleted = false;

  @override
  void initState() {
    super.initState();
    _initStream();
  }

  void _initStream() {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    Query query = FirebaseFirestore.instance.collection('orders')
        .where('ownerId', isEqualTo: user.id.toString());
    
    // Simple client-side toggle for status to avoid complex indexes if possible,
    // but ideally we filter by status in query. 
    // Let's filter by status in memory to avoid composite index issues for now, 
    // unless the list is huge.
    
    _ordersStream = query.snapshots().map((snapshot) {
      final orders = snapshot.docs.map((doc) {
        return OrderModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();
      
      // Sort by newest first
      orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return orders;
    });
  }

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    String? rejectionReason;
    
    // If rejecting, ask for reason
    if (newStatus == 'rejected') {
      final reasonController = TextEditingController();
      final shouldReject = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reject Order'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Please provide a reason for rejecting this order:'),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  hintText: 'e.g., Sold out, Kitchen too busy',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject Order'),
            ),
          ],
        ),
      );

      if (shouldReject != true) return;
      rejectionReason = reasonController.text.trim();
      if (rejectionReason.isEmpty) rejectionReason = 'No specific reason provided';
    }

    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
      };
      
      if (rejectionReason != null) {
        updateData['rejectionReason'] = rejectionReason;
      }

      await FirebaseFirestore.instance.collection('orders').doc(orderId).update(updateData);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Order marked as $newStatus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating order: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'preparation': return Colors.blue;
      case 'served': return Colors.purple;
      case 'completed': return Colors.green;
      case 'rejected': 
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_showCompleted ? 'Order History' : 'Active Orders'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/dashboard'),
        ),
        actions: [
          TextButton.icon(
            icon: Icon(_showCompleted ? Icons.pending_actions : Icons.history),
            label: Text(_showCompleted ? 'View Active' : 'View History'),
            onPressed: () {
              setState(() {
                _showCompleted = !_showCompleted;
              });
            },
          ),
        ],
      ),
      body: StreamBuilder<List<OrderModel>>(
        stream: _ordersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];
          
          // Filter in memory based on tab
          final orders = allOrders.where((o) {
            final isActive = ['pending', 'preparation', 'served'].contains(o.status.toLowerCase());
            return _showCompleted ? !isActive : isActive;
          }).toList();

          if (orders.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _showCompleted ? Icons.history : Icons.shopping_cart_outlined,
                    size: 64,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _showCompleted 
                      ? 'No order history yet' 
                      : 'No active orders',
                    style: TextStyle(fontSize: 18, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final status = order.status.toLowerCase();
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: status == 'pending' ? Colors.orange.withOpacity(0.5) : Colors.transparent, 
                    width: 1
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue[200]!),
                                ),
                                child: Text(
                                  'Table ${order.tableNumber}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.blue),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                DateFormat('h:mm a').format(order.createdAt),
                                style: TextStyle(color: Colors.grey[600], fontSize: 13),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusColor(status).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              status.toUpperCase(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: _getStatusColor(status),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                      ...order.items.map<Widget>((item) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                child: Center(
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '${item['quantity']}x',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item['name'] ?? 'Unknown Item',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                child: Text(
                                  '\$${(item['total'] as num).toStringAsFixed(2)}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                  textAlign: TextAlign.right,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 16),
                      const Divider(),
                      
                      // Total Row aligned with items
                      Row(
                        children: [
                          const SizedBox(width: 50), // Matches Qty column
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Total',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          SizedBox(
                            width: 80, // Matches Price column
                            child: Text(
                              '\$${order.totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16, 
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Action Buttons Row
                      if (status == 'pending')
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              onPressed: () => _updateOrderStatus(order.id, 'rejected'),
                              icon: const Icon(Icons.close, size: 18),
                              label: const Text('Reject'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                            ),
                            ElevatedButton.icon(
                              onPressed: () => _updateOrderStatus(order.id, 'preparation'),
                              icon: const Icon(Icons.outdoor_grill, size: 18),
                              label: const Text('Start Preparation'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        
                      if (status == 'preparation')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateOrderStatus(order.id, 'served'),
                            icon: const Icon(Icons.room_service, size: 18),
                            label: const Text('Mark as Served'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.purple,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),

                      if (status == 'served')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _updateOrderStatus(order.id, 'completed'),
                            icon: const Icon(Icons.check_circle, size: 18),
                            label: const Text('Mark as Completed'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
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
    );
  }
}
