import 'package:flutter/material.dart';

import '../theme.dart';

class SettingsPanel extends StatefulWidget {
  const SettingsPanel({
    super.key,
    required this.apiKeyController,
    required this.apiUrlController,
    required this.modelController,
    required this.onSave,
    required this.onReset,
  });

  final TextEditingController apiKeyController;
  final TextEditingController apiUrlController;
  final TextEditingController modelController;
  final VoidCallback onSave;
  final VoidCallback onReset;

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  bool _warned = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBlack,
      child: Container(
        width: 440,
        height: double.infinity,
        decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: kWhite))),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('设置', style: TextStyle(color: kWhite, fontSize: 18)),
                OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('关闭')),
              ],
            ),
            const SizedBox(height: 24),
            SettingsField(
                label: 'API Key',
                controller: widget.apiKeyController,
                obscure: true),
            SettingsField(label: 'API 地址', controller: widget.apiUrlController),
            SettingsField(label: '模型', controller: widget.modelController),
            const Text('人设 Prompt',
                style: TextStyle(color: kWhite, fontSize: 13)),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => setState(() => _warned = true),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: _warned ? const Color(0xFFFF2D2D) : kWhite),
                foregroundColor: _warned ? const Color(0xFFFF2D2D) : kWhite,
                shape: const RoundedRectangleBorder(),
                alignment: Alignment.center,
                minimumSize: const Size.fromHeight(160),
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: Text(
                '不准偷窥魔女的秘密',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: _warned ? 20 : 16,
                  height: 1.2,
                  fontWeight: _warned ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                OutlinedButton(
                    onPressed: widget.onReset, child: const Text('重置')),
                OutlinedButton(
                    onPressed: widget.onSave, child: const Text('保存')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsField extends StatelessWidget {
  const SettingsField(
      {super.key,
      required this.label,
      required this.controller,
      this.obscure = false});

  final String label;
  final TextEditingController controller;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: kWhite, fontSize: 13)),
          const SizedBox(height: 8),
          TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: kWhite),
            decoration: const InputDecoration(
              enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kWhite),
                  borderRadius: BorderRadius.zero),
              focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: kWhite),
                  borderRadius: BorderRadius.zero),
              contentPadding: EdgeInsets.all(10),
            ),
          ),
        ],
      ),
    );
  }
}
