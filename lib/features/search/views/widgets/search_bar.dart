import 'package:flutter/material.dart';

class FeatureSearchBar extends StatelessWidget {
  const FeatureSearchBar({
    required this.controller,
    required this.onSearch,
    super.key,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: TextField(
        key: const ValueKey('qqmusic-search-field'),
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSearch,
        style: const TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: '歌曲、歌手、专辑、歌单、MV',
          hintStyle: const TextStyle(color: Color(0x66FFFFFF)),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0x99FFFFFF),
            size: 19,
          ),
          suffixIcon: IconButton(
            tooltip: '搜索',
            onPressed: () => onSearch(controller.text),
            icon: const Icon(
              Icons.arrow_forward_rounded,
              color: Color(0xFF31C27C),
              size: 19,
            ),
          ),
          filled: true,
          fillColor: const Color(0x1AFFFFFF),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
