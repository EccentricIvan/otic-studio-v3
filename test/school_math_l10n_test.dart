import 'package:ai_connect_africa/ai_core/tutor/school_math.dart';
import 'package:ai_connect_africa/ai_core/tutor/school_math_l10n.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('protectMathProse pins numbers, fractions, and glossary terms', () {
    final p = protectMathProse('Read the fraction as 3/4 of 80.');
    expect(p.text, isNot(contains('fraction')));
    expect(p.text, isNot(contains('3/4')));
    expect(p.text, isNot(contains('80')));
    expect(p.restore(p.text), 'Read the fraction as 3/4 of 80.');
  });

  test('localizeSchoolMath translates titles and why, keeps formulas', () async {
    final solved = solveSchoolMath('what is 3/4 of 80');
    expect(solved, isNotNull);

    final localized = await localizeSchoolMath(
      solved!,
      translate: (english) async => 'LG:$english',
    );

    expect(localized.steps.first.title, startsWith('LG:'));
    expect(localized.steps.first.why, startsWith('LG:'));
    expect(localized.steps.first.formula, solved.steps.first.formula);
    expect(localized.steps.first.calc, solved.steps.first.calc);
    expect(localized.answer, solved.answer);
    expect(localized.practiceQuestion, solved.practiceQuestion);
  });

  test('restored translation keeps English terms and constants', () async {
    final step = const MathStep(
      title: 'Read the fraction as a multiplier.',
      why: "'Of' means multiply by the fraction 3/4.",
      formula: 'value = (3 / 4) × 80',
      calc: '0.75 × 80 = 60',
    );
    final math = SchoolMathSolution(
      steps: [step],
      answer: '60',
      hint: 'Write 3/4 as a fraction first.',
      practiceQuestion: 'What is 2/3 of 90?',
      numericAnswer: 60,
    );

    final localized = await localizeSchoolMath(
      math,
      translate: (english) async {
        // Pretend AfriSLM translated everything except placeholders.
        return english.replaceAll('Read the', 'Soma');
      },
    );

    expect(localized.steps.first.title, contains('fraction'));
    expect(localized.steps.first.why, contains('3/4'));
    expect(localized.steps.first.formula, 'value = (3 / 4) × 80');
    expect(localized.answer, '60');
  });
}
