import 'package:flutter_test/flutter_test.dart';
import 'package:ai_connect_africa/safety/emotional_safety.dart';

void main() {
  const engine = EmotionalSafetyEngine();

  group('EmotionalSafetyEngine', () {
    test('normal learning messages pass through', () {
      expect(engine.check('What is photosynthesis?').concern,
          SafetyConcern.none);
      expect(engine.check('Explain Python loops').concern,
          SafetyConcern.none);
      expect(engine.check('I want to learn about gravity').concern,
          SafetyConcern.none);
    });

    test('frustration is detected and keeps the tutor in the loop', () {
      final r = engine.check("I give up, this is too hard for me");
      expect(r.concern, SafetyConcern.frustration);
      expect(r.bypassTutor, false);
      expect(r.tutorNote, isNotNull);
    });

    test('self-deprecation is detected as frustration', () {
      final r = engine.check("I'm so stupid, I can't do this");
      expect(r.concern, SafetyConcern.frustration);
    });

    test('distress is detected with an empathy note', () {
      final r = engine.check('Kids at school keep bullying me');
      expect(r.concern, SafetyConcern.distress);
      expect(r.bypassTutor, false);
      expect(r.tutorNote, contains('empathy'));
    });

    test('crisis messages bypass the model entirely', () {
      final r = engine.check('I want to hurt myself');
      expect(r.concern, SafetyConcern.crisis);
      expect(r.bypassTutor, true);
      expect(r.supportMessage, isNotNull);
      expect(r.supportMessage, contains('trust'));
    });

    test('crisis detection is case-insensitive', () {
      final r = engine.check('I WANT TO DIE');
      expect(r.concern, SafetyConcern.crisis);
    });
  });
}
