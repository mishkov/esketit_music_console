import 'package:esketit_music_console/use_case/settings/app_theme_mode_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('defaults to auto theme mode', () async {
    final cubit = AppThemeModeCubit();

    await cubit.load();

    expect(cubit.state, AppThemeModePreference.auto);
  });

  test('persists selected theme mode', () async {
    final firstCubit = AppThemeModeCubit();
    await firstCubit.load();

    await firstCubit.setThemeMode(AppThemeModePreference.dark);

    final secondCubit = AppThemeModeCubit();
    await secondCubit.load();

    expect(secondCubit.state, AppThemeModePreference.dark);
  });
}
