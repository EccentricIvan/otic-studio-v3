import 'package:flutter_test/flutter_test.dart';

import 'package:ai_connect_africa/ai_core/tutor/school_math.dart';

void main() {
  test('250 cm to metres uses divide-by-100, not addition', () {
    final plan = trySchoolMathPlan('convert 250 cm to metres');
    expect(plan, isNotNull);
    expect(plan, contains('1 m = 100 cm'));
    expect(plan, contains('250 ÷ 100 = 2.5'));
    expect(plan, contains('Answer: 2.5 m'));
    expect(plan, isNot(contains('250 + 100')));
    expect(plan, isNot(contains('Sum:')));
  });

  test('how many metres in 250 cm', () {
    final s = solveSchoolMath('how many metres in 250 cm');
    expect(s?.answer, '2.5 m');
  });

  test('15% of 80', () {
    final s = solveSchoolMath('what is 15% of 80');
    expect(s?.numericAnswer, 12);
    expect(s?.answer, '12');
  });

  test('3/4 of 80', () {
    final s = solveSchoolMath('what is 3/4 of 80');
    expect(s?.numericAnswer, 60);
  });

  test('solve 2x + 3 = 11', () {
    final s = solveSchoolMath('solve 2x + 3 = 11');
    expect(s?.numericAnswer, 4);
    expect(s?.answer, 'x = 4');
  });

  test('PEMDAS 3 + 4 * 5', () {
    final s = solveSchoolMath('calculate 3 + 4 * 5');
    expect(s?.numericAnswer, 23);
  });

  test('rectangle area 5 by 8', () {
    final s = solveSchoolMath('area of a rectangle 5 by 8');
    expect(s?.numericAnswer, 40);
  });

  test('increase 50 by 20%', () {
    final s = solveSchoolMath('increase 50 by 20%');
    expect(s?.numericAnswer, 60);
  });

  test('numeric attempt parser', () {
    expect(extractNumericAttempt('2.5'), 2.5);
    expect(extractNumericAttempt('2.5 m'), 2.5);
    expect(extractNumericAttempt('I think 12'), 12);
  });

  test('coaching phrases are exact, not buried in a new question', () {
    expect(isMathCoachingFollowUp('Give me a hint'), isTrue);
    expect(isMathCoachingFollowUp('Show the full steps'), isTrue);
    expect(isMathCoachingFollowUp('2.5 m'), isTrue);
    expect(isMathCoachingFollowUp('what is photosynthesis'), isFalse);
    expect(isMathCoachingFollowUp('give me the answer about gravity'), isFalse);
    expect(isMathCoachingFollowUp('convert 5 km to metres'), isFalse);
  });
}
