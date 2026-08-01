import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final storeId = 'parkf6a474f2d115ea';
  final storePass = 'parkf6a474f2d115ea@ssl';
  final txnId = "TXN_${DateTime.now().millisecondsSinceEpoch}";

  final response = await http.post(
    Uri.parse('https://sandbox.sslcommerz.com/gwprocess/v4/api.php'),
    body: {
      'store_id': storeId,
      'store_passwd': storePass,
      'total_amount': '100.0',
      'currency': 'BDT',
      'tran_id': txnId,
      'success_url': 'http://localhost/success',
      'fail_url': 'http://localhost/fail',
      'cancel_url': 'http://localhost/cancel',
      'cus_name': 'Parkfinity User',
      'cus_email': 'user@parkfinity.com',
      'cus_add1': 'Dhaka',
      'cus_city': 'Dhaka',
      'cus_postcode': '1000',
      'cus_country': 'Bangladesh',
      'cus_phone': '01700000000',
      'shipping_method': 'NO',
      'product_name': 'Wallet Recharge',
      'product_category': 'Service',
      'product_profile': 'general',
    },
  );

  print('Status code: ${response.statusCode}');
  print('Body: ${response.body}');
}
