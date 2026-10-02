import 'package:flutter/material.dart';
import 'package:url_launcher/link.dart';

class SourceMetadataLink extends StatelessWidget {
  const SourceMetadataLink({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final value = url?.trim();
    final uri = value == null ? null : Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      return SelectableText(value == null || value.isEmpty ? '—' : value);
    }

    return Link(
      uri: uri,
      target: LinkTarget.blank,
      builder: (context, followLink) => TextButton(
        onPressed: followLink,
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          alignment: Alignment.centerLeft,
          textStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(value!),
      ),
    );
  }
}
