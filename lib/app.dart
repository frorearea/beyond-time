import 'package:flutter/material.dart';

import 'pages/beyond_time_page.dart';

class BeyondTimeApp extends StatelessWidget {
  const BeyondTimeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '时间之外',
      home: BeyondTimePage(),
    );
  }
}
