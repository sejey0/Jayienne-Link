import 'package:flutter/material.dart';
import 'collapsible_anniversary_card.dart';

export 'collapsible_anniversary_card.dart';

/// Legacy Alias Widget forwarding to CollapsibleAnniversaryCard
class AnniversaryCardWidget extends StatelessWidget {
  final bool initialExpanded;

  const AnniversaryCardWidget({
    super.key,
    this.initialExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    return CollapsibleAnniversaryCard(initialExpanded: initialExpanded);
  }
}
