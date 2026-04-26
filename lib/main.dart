import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';

void main() => runApp(const BroPOS());

class BroPOS extends StatelessWidget {
  const BroPOS({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'HandyPOS',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
      ),
      home: const SplashScreen(),
    );
  }
}

// --- SPLASH SCREEN WITH STAGGERED FADE EFFECT ---
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoFade;
  late Animation<double> _titleFade;
  late Animation<double> _subtitleFade;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
      ),
    );

    _controller.forward();

    // Preload logo
    _precacheLogo();

    // Navigate after splash
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainNavigation(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 600),
          ),
        );
      }
    });
  }

  Future<void> _precacheLogo() async {
    try {
      await precacheImage(const AssetImage('assets/logo.png'), context);
    } catch (e) {
      debugPrint("Logo preload failed: $e");
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeTransition(
                opacity: _logoFade,
                child: Image.asset(
                  'assets/logo.png',
                  width: 160,
                  height: 160,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.storefront,
                        size: 90,
                        color: Colors.orange,
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 40),

              FadeTransition(
                opacity: _titleFade,
                child: const Text(
                  "Welcome to HandyPOS!",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              FadeTransition(
                opacity: _subtitleFade,
                child: const Text(
                  "By hookmaster35",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- MAIN NAVIGATION ---
class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  List<Map<String, dynamic>> allProducts = [];
  List<Map<String, dynamic>> salesHistory = [];
  List<Map<String, dynamic>> ledgerEntries = [];
  String selectedMonth = DateFormat('MMMM').format(DateTime.now());

  final List<String> months = [
    "January",
    "February",
    "March",
    "April",
    "May",
    "June",
    "July",
    "August",
    "September",
    "October",
    "November",
    "December",
  ];

  @override
  void initState() {
    super.initState();
    loadData();
  }

  Future<void> saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('products_db', jsonEncode(allProducts));
    await prefs.setString('history_db', jsonEncode(salesHistory));
    await prefs.setString('ledger_db', jsonEncode(ledgerEntries));
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      allProducts = List<Map<String, dynamic>>.from(
        jsonDecode(prefs.getString('products_db') ?? '[]'),
      );
      salesHistory = List<Map<String, dynamic>>.from(
        jsonDecode(prefs.getString('history_db') ?? '[]'),
      );
      ledgerEntries = List<Map<String, dynamic>>.from(
        jsonDecode(prefs.getString('ledger_db') ?? '[]'),
      );
    });
  }

  void addOrUpdateProduct(Map<String, dynamic> newProduct) {
    setState(() {
      int index = allProducts.indexWhere(
        (p) => p['barcode'] == newProduct['barcode'],
      );
      if (index != -1) {
        allProducts[index]['stock'] += newProduct['stock'];
        allProducts[index]['price'] = newProduct['price'];
      } else {
        allProducts.add(newProduct);
      }
    });
    saveData();
  }

  void addLedgerEntry(
    String ref,
    double credit,
    double debit, {
    bool isMemo = false,
  }) {
    setState(() {
      ledgerEntries.insert(0, {
        'day': DateTime.now().day.toString(),
        'ref': ref,
        'credit': credit,
        'debit': debit,
        'isMemo': isMemo,
        'month': DateFormat('MMMM').format(DateTime.now()),
        'date': DateTime.now().toString().substring(0, 10),
      });
    });
    saveData();
  }

  void processSale(
    List<Map<String, dynamic>> cart,
    double total,
    String customer,
    String type,
  ) {
    setState(() {
      for (var item in cart) {
        int index = allProducts.indexWhere((p) => p['name'] == item['name']);
        if (index != -1) {
          int qtySold = item['qty'] ?? 1;
          allProducts[index]['stock'] -= qtySold;
        }
      }
      salesHistory.insert(0, {
        'customer': customer,
        'total': total,
        'type': type,
        'paid': type == "CASH",
        'date': DateTime.now().toString().substring(0, 16),
        'items': List.from(cart),
      });
      if (type == "CASH") {
        addLedgerEntry("[CASH] $customer", total, 0);
      } else if (type == "UTANG") {
        addLedgerEntry("[UTANG] $customer", 0, 0, isMemo: true);
      }
    });
    saveData();
  }

  void markUtangAsPaid(int saleIndex) {
    final sale = salesHistory[saleIndex];
    setState(() {
      salesHistory[saleIndex]['paid'] = true;
    });
    addLedgerEntry(
      "[PAID] ${sale['customer']}",
      (sale['total'] as num).toDouble(),
      0,
    );
    saveData();
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      SalesScreen(inventory: allProducts, onCheckout: processSale),
      InventoryScreen(products: allProducts, onAdd: addOrUpdateProduct),
      AccountingScreen(
        entries: ledgerEntries,
        onAdd: addLedgerEntry,
        selectedMonth: selectedMonth,
        monthList: months,
        onMonthChanged: (newMonth) => setState(() => selectedMonth = newMonth),
      ),
      HistoryScreen(history: salesHistory, onMarkPaid: markUtangAsPaid),
      const AboutDeveloperScreen(),
    ];

    return Scaffold(
      body: screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.qr_code_scanner),
            label: "Scanner",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.inventory), label: "Stock"),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: "Ledger",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: "Sales"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Dev"),
        ],
      ),
    );
  }
}

// --- SALES SCREEN ---
class SalesScreen extends StatefulWidget {
  final List<Map<String, dynamic>> inventory;
  final Function(List<Map<String, dynamic>>, double, String, String) onCheckout;

  const SalesScreen({
    super.key,
    required this.inventory,
    required this.onCheckout,
  });

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  List<Map<String, dynamic>> cartItems = [];
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );

  void handleBarcode(String code) {
    var product = widget.inventory.firstWhere(
      (p) => p['barcode'] == code,
      orElse: () => {},
    );
    if (product.isNotEmpty && (product['stock'] as num) > 0) {
      setState(() {
        cartItems.add({
          'name': product['name'],
          'price': product['price'],
          'qty': 1,
        });
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            product.isEmpty ? "Item not in Stock!" : "Out of Stock!",
          ),
          duration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double total = cartItems.fold(
      0,
      (sum, item) => sum + (item['price'] * item['qty']),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text("HandyPOS Scanner"),
        backgroundColor: Colors.orange,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: MobileScanner(
              controller: controller,
              onDetect: (cap) {
                for (var b in cap.barcodes) {
                  if (b.rawValue != null) handleBarcode(b.rawValue!);
                }
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10),
            color: Colors.orange.shade100,
            child: Center(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add_circle),
                label: const Text("MANUAL ADD"),
                onPressed: () => _showManualAdd(context),
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cartItems.length,
                    itemBuilder: (c, i) => ListTile(
                      title: Text(
                        "${cartItems[i]['name']} x${cartItems[i]['qty']}",
                      ),
                      trailing: Text(
                        "₱${(cartItems[i]['price'] * cartItems[i]['qty']).toStringAsFixed(2)}",
                      ),
                      onLongPress: () => setState(() => cartItems.removeAt(i)),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Total: ₱${total.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (cartItems.isNotEmpty)
                        ElevatedButton(
                          onPressed: () => _showCheckout(context),
                          child: const Text("CHECKOUT"),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showManualAdd(BuildContext context) {
    String name = "";
    double price = 0;
    int qty = 1;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Quick Manual Add"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(labelText: "Item Name"),
              onChanged: (v) => name = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Price"),
              keyboardType: TextInputType.number,
              onChanged: (v) => price = double.tryParse(v) ?? 0,
            ),
            TextField(
              decoration: const InputDecoration(labelText: "Quantity"),
              keyboardType: TextInputType.number,
              onChanged: (v) => qty = int.tryParse(v) ?? 1,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              if (name.isNotEmpty) {
                setState(
                  () =>
                      cartItems.add({'name': name, 'price': price, 'qty': qty}),
                );
                Navigator.pop(c);
              }
            },
            child: const Text("ADD TO CART"),
          ),
        ],
      ),
    );
  }

  void _showCheckout(BuildContext context) {
    String cust = "Walk-in";
    double total = cartItems.fold(
      0,
      (sum, item) => sum + (item['price'] * item['qty']),
    );

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text("Payment"),
        content: TextField(
          decoration: const InputDecoration(labelText: "Customer Name"),
          onChanged: (v) => cust = v,
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              widget.onCheckout(cartItems, total, cust, "CASH");
              setState(() => cartItems.clear());
              Navigator.pop(c);
            },
            child: const Text("CASH"),
          ),
          ElevatedButton(
            onPressed: () {
              widget.onCheckout(cartItems, total, cust, "UTANG");
              setState(() => cartItems.clear());
              Navigator.pop(c);
            },
            child: const Text("UTANG"),
          ),
        ],
      ),
    );
  }
}

// --- INVENTORY SCREEN ---
class InventoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Function(Map<String, dynamic>) onAdd;

  const InventoryScreen({
    super.key,
    required this.products,
    required this.onAdd,
  });

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final MobileScannerController addController = MobileScannerController();

  void _showAddDialog() {
    String name = "";
    double price = 0;
    int stock = 0;
    String barcode = "";

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text("Add Product"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 120,
                  child: MobileScanner(
                    controller: addController,
                    onDetect: (cap) =>
                        setS(() => barcode = cap.barcodes.first.rawValue ?? ""),
                  ),
                ),
                Text(
                  "Barcode: ${barcode.isEmpty ? 'Waiting...' : barcode}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Name"),
                  onChanged: (v) => name = v,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => price = double.tryParse(v) ?? 0,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: "Stock"),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => stock = int.tryParse(v) ?? 0,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                String finalBarcode = barcode.isEmpty
                    ? "MANUAL-${name.toLowerCase()}"
                    : barcode;
                widget.onAdd({
                  'barcode': finalBarcode,
                  'name': name,
                  'price': price,
                  'stock': stock,
                });
                Navigator.pop(c);
              },
              child: const Text("SAVE"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Stock Management"),
      backgroundColor: Colors.orange,
    ),
    body: ListView.builder(
      itemCount: widget.products.length,
      itemBuilder: (c, i) => ListTile(
        title: Text(widget.products[i]['name']),
        subtitle: Text("Stock: ${widget.products[i]['stock']}"),
        trailing: Text("₱${widget.products[i]['price']}"),
      ),
    ),
    floatingActionButton: FloatingActionButton(
      onPressed: _showAddDialog,
      child: const Icon(Icons.add),
    ),
  );
}

// --- ACCOUNTING SCREEN ---
class AccountingScreen extends StatelessWidget {
  final List<Map<String, dynamic>> entries;
  final Function(String, double, double, {bool isMemo}) onAdd;
  final String selectedMonth;
  final List<String> monthList;
  final Function(String) onMonthChanged;

  const AccountingScreen({
    super.key,
    required this.entries,
    required this.onAdd,
    required this.selectedMonth,
    required this.monthList,
    required this.onMonthChanged,
  });

  Future<void> _printLedger(
    List<Map<String, dynamic>> filtered,
    double Function(int) getBal,
  ) async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Center(
              child: pw.Text(
                "SARI-SARI STORE - LEDGER",
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
            pw.Center(child: pw.Text("Month: $selectedMonth")),
            pw.Divider(),
            pw.Row(
              children: [
                pw.Expanded(flex: 1, child: pw.Text("Day")),
                pw.Expanded(flex: 3, child: pw.Text("Reference")),
                pw.Expanded(flex: 2, child: pw.Text("In")),
                pw.Expanded(flex: 2, child: pw.Text("Out")),
                pw.Expanded(flex: 2, child: pw.Text("Balance")),
              ],
            ),
            pw.Divider(),
            ...filtered.asMap().entries.map((entry) {
              final e = entry.value;
              final isMemo = e['isMemo'] == true;
              return pw.Row(
                children: [
                  pw.Expanded(flex: 1, child: pw.Text(e['day'])),
                  pw.Expanded(flex: 3, child: pw.Text(e['ref'])),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      isMemo ? "(${e['credit']})" : "P${e['credit']}",
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(isMemo ? "-" : "P${e['debit']}"),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(isMemo ? "-" : "P${getBal(entry.key)}"),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final filtered = entries.where((e) => e['month'] == selectedMonth).toList();

    double getBal(int i) {
      double b = 0;
      for (int j = filtered.length - 1; j >= i; j--) {
        if (filtered[j]['isMemo'] != true) {
          b += (filtered[j]['credit'] ?? 0) - (filtered[j]['debit'] ?? 0);
        }
      }
      return b;
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selectedMonth,
            dropdownColor: Colors.orange,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
            onChanged: (n) {
              if (n != null) onMonthChanged(n);
            },
            items: monthList
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.grey[200],
            child: const Row(
              children: [
                Expanded(flex: 1, child: Text("Day")),
                Expanded(flex: 3, child: Text("Ref")),
                Expanded(flex: 2, child: Text("In")),
                Expanded(flex: 2, child: Text("Out")),
                Expanded(flex: 2, child: Text("Bal")),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (c, i) {
                final entry = filtered[i];
                final isMemo = entry['isMemo'] == true;
                return ListTile(
                  tileColor: isMemo ? Colors.orange.shade50 : null,
                  title: Row(
                    children: [
                      Expanded(flex: 1, child: Text(entry['day'])),
                      Expanded(
                        flex: 3,
                        child: Text(
                          entry['ref'],
                          style: TextStyle(
                            fontSize: 12,
                            fontStyle: isMemo
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: isMemo ? Colors.orange.shade800 : null,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          isMemo
                              ? "(₱${entry['credit']})"
                              : "₱${entry['credit']}",
                          style: TextStyle(
                            color: isMemo
                                ? Colors.orange.shade700
                                : Colors.green,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          isMemo ? "-" : "₱${entry['debit']}",
                          style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          isMemo ? "-" : "₱${getBal(i)}",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Stack(
        children: [
          Align(
            alignment: Alignment.bottomLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 30),
              child: FloatingActionButton(
                heroTag: "p",
                backgroundColor: Colors.orange.shade700,
                onPressed: () => _printLedger(filtered, getBal),
                child: const Icon(Icons.print),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: FloatingActionButton(
              heroTag: "a",
              onPressed: () => _showAdd(context),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdd(BuildContext context) {
    String ref = "";
    double amt = 0;
    String mode = "DEBIT";

    showDialog(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setS) => AlertDialog(
          title: const Text("New Entry"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: "Ref"),
                onChanged: (v) => ref = v,
              ),
              TextField(
                decoration: const InputDecoration(labelText: "Amount"),
                keyboardType: TextInputType.number,
                onChanged: (v) => amt = double.tryParse(v) ?? 0,
              ),
              DropdownButton<String>(
                value: mode,
                items: const [
                  DropdownMenuItem(value: "CREDIT", child: Text("In")),
                  DropdownMenuItem(value: "DEBIT", child: Text("Out")),
                ],
                onChanged: (v) => setS(() => mode = v!),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                onAdd(
                  ref,
                  mode == "CREDIT" ? amt : 0,
                  mode == "DEBIT" ? amt : 0,
                );
                Navigator.pop(c);
              },
              child: const Text("SAVE"),
            ),
          ],
        ),
      ),
    );
  }
}

// --- HISTORY SCREEN ---
class HistoryScreen extends StatelessWidget {
  final List<Map<String, dynamic>> history;
  final Function(int) onMarkPaid;

  const HistoryScreen({
    super.key,
    required this.history,
    required this.onMarkPaid,
  });

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text("Sales History"),
      backgroundColor: Colors.orange,
    ),
    body: ListView.builder(
      itemCount: history.length,
      itemBuilder: (c, i) {
        final sale = history[i];
        final isPaid = sale['paid'] == true;
        return ListTile(
          onTap: () => Navigator.push(
            c,
            MaterialPageRoute(
              builder: (c) => ReceiptDetailScreen(
                sale: sale,
                saleIndex: i,
                onMarkPaid: onMarkPaid,
              ),
            ),
          ),
          leading: Icon(
            isPaid ? Icons.check_circle : Icons.warning_rounded,
            color: isPaid ? Colors.green : Colors.red,
          ),
          title: Text("${sale['customer']} - ₱${sale['total']}"),
          subtitle: Text("${sale['date']} • ${sale['type']}"),
          trailing: sale['type'] == "UTANG" && !isPaid
              ? TextButton(
                  onPressed: () => onMarkPaid(i),
                  child: const Text("PAID?"),
                )
              : const Icon(Icons.arrow_forward_ios),
        );
      },
    ),
  );
}

// --- RECEIPT DETAIL ---
class ReceiptDetailScreen extends StatelessWidget {
  final Map<String, dynamic> sale;
  final int saleIndex;
  final Function(int) onMarkPaid;

  const ReceiptDetailScreen({
    super.key,
    required this.sale,
    required this.saleIndex,
    required this.onMarkPaid,
  });

  Future<void> _print() async {
    final doc = pw.Document();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.roll80,
        build: (pw.Context context) => pw.Column(
          children: [
            pw.Text(
              "SARI-SARI STORE",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Divider(),
            pw.Text("Customer: ${sale['customer']}"),
            pw.Text("Date: ${sale['date']}"),
            pw.Divider(),
            ...List.from(sale['items']).map(
              (it) => pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("${it['name']} x${it['qty']}"),
                  pw.Text("P${(it['price'] * it['qty'])}"),
                ],
              ),
            ),
            pw.Divider(),
            pw.Text(
              "TOTAL: P${sale['total']}",
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (f) async => doc.save());
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = sale['paid'] == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Receipt"),
        backgroundColor: Colors.orange,
        actions: [IconButton(icon: const Icon(Icons.print), onPressed: _print)],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(
              child: Text(
                "SARI-SARI STORE",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(),
            Text("Customer: ${sale['customer']}"),
            Text("Date: ${sale['date']}"),
            Text(
              "Status: ${isPaid ? 'PAID' : 'UNPAID'}",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isPaid ? Colors.green : Colors.red,
              ),
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: (sale['items'] as List).length,
                itemBuilder: (c, i) => ListTile(
                  title: Text(
                    "${sale['items'][i]['name']} x${sale['items'][i]['qty']}",
                  ),
                  trailing: Text(
                    "₱${(sale['items'][i]['price'] * sale['items'][i]['qty']).toStringAsFixed(2)}",
                  ),
                ),
              ),
            ),
            const Divider(),
            Text(
              "TOTAL: ₱${sale['total']}",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (!isPaid)
              ElevatedButton(
                onPressed: () {
                  onMarkPaid(saleIndex);
                  Navigator.pop(context);
                },
                child: const Text("MARK AS PAID"),
              ),
          ],
        ),
      ),
    );
  }
}

// --- ABOUT DEVELOPER SCREEN ---
class AboutDeveloperScreen extends StatelessWidget {
  const AboutDeveloperScreen({super.key});

  Future<void> _launchPortfolio() async {
    final Uri url = Uri.parse(
      'https://portfolio-pink-two-21.vercel.app/index.html',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("The Developer"),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                  child: const CircleAvatar(
                    radius: 70,
                    backgroundColor: Colors.white,
                    backgroundImage: AssetImage('assets/hookmaster35.png'),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "hookmaster35",
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                ),
                const Text(
                  "Independent Developer",
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Made as a pastime project and to help small local sari-sari stores.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
                const Divider(height: 40, thickness: 1),
                const Text(
                  "This POS was built to streamline inventory tracking, manage utang balances, and simplify daily accounting for our community business owners.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 30),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: InkWell(
                    onTap: _launchPortfolio,
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 15,
                        horizontal: 20,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.language, color: Colors.blue),
                          SizedBox(width: 10),
                          Text(
                            "View My Portfolio",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  "App Version 1.0.0",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
