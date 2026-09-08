// Pure Dart — no Flutter or Flame imports. Safe to unit test in isolation.

/// A single line of spoken dialogue.
class DialogueLine {
  const DialogueLine({
    required this.speaker,
    required this.text,
  });

  /// Name displayed above the text bubble, e.g. `'Elder Maro'`.
  final String speaker;

  /// The spoken text for this line.
  final String text;
}

// ─────────────────────────────────────────────────────────────────────────────

/// An ordered sequence of [DialogueLine]s shown one at a time.
///
/// ## AI hook
/// [lines] is currently a static list. When you're ready to replace it with
/// AI-generated dialogue, do the following:
///
/// ```dart
/// // TODO(ai-dialogue): Replace this factory with a network call.
/// // The call should:
/// //   1. POST the NPC context (id, world, player history) to your LLM API.
/// //   2. Stream or await the response.
/// //   3. Parse the response into a List<DialogueLine>.
/// //   4. Construct and return a DialogueSequence with those lines.
/// // Until then the static list below is used.
/// static Future<DialogueSequence> fromApi(NpcContext ctx) async {
///   final lines = await MyAiService.fetchDialogue(ctx);
///   return DialogueSequence(lines: lines, onComplete: ctx.onComplete);
/// }
/// ```
///
/// The rest of the system (NPC component, DialogueBox, MissionManager) does
/// not need to change — they consume a [DialogueSequence] regardless of how
/// it was produced.
class DialogueSequence {
  const DialogueSequence({
    required this.lines,
    this.onComplete,
  }) : assert(lines.length > 0, 'A DialogueSequence must have at least one line');

  /// All lines to display in order.
  final List<DialogueLine> lines;

  /// Optional callback invoked after the player taps past the last line.
  ///
  /// Use this to trigger mission events, unlock doors, etc.
  final void Function()? onComplete;
}
