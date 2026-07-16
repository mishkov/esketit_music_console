import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeModePreference {
  auto('auto', 'Auto', ThemeMode.system),
  dark('dark', 'Dark', ThemeMode.dark),
  light('light', 'Light', ThemeMode.light);

  const AppThemeModePreference(this.storageValue, this.label, this.themeMode);

  final String storageValue;
  final String label;
  final ThemeMode themeMode;

  static AppThemeModePreference fromStorageValue(String? value) {
    return AppThemeModePreference.values.firstWhere(
      (preference) => preference.storageValue == value,
      orElse: () => AppThemeModePreference.auto,
    );
  }
}

class AppThemeModeCubit extends Cubit<AppThemeModePreference> {
  AppThemeModeCubit() : super(AppThemeModePreference.auto);

  static const _preferenceKey = 'app_theme_mode';

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    emit(
      AppThemeModePreference.fromStorageValue(
        preferences.getString(_preferenceKey),
      ),
    );
  }

  Future<void> setThemeMode(AppThemeModePreference preference) async {
    emit(preference);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, preference.storageValue);
  }
}
