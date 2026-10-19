import 'package:flutter_test/flutter_test.dart';
import 'package:oberta/online/online_services.dart';
import 'package:oberta/online/supabase_online.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gli errori veri di Supabase, nelle parole della UI, col motivo tecnico.
void main() {
  OnlineException translate(Object error, [SignInDoor? door]) => translateOnlineError(error, door);

  test('Apple spento sul server: lo si dice chiaro, e il motivo resta', () {
    const error = AuthApiException(
      'Unsupported provider: provider is not enabled',
      statusCode: '400',
      code: 'validation_failed',
    );
    final translated = translate(error, SignInDoor.apple);
    expect(translated.failure, OnlineFailure.appleDisabled);
    expect(translated.reason, contains('validation_failed'));
    expect(translated.reason, contains('provider is not enabled'));
    expect(translate(const AuthException('x', code: 'provider_disabled'), SignInDoor.google).failure,
        OnlineFailure.googleDisabled);
  });

  test('l\'account di prova: email spenta, password sbagliata, password debole', () {
    expect(
      translate(const AuthApiException('Email logins are disabled', code: 'email_provider_disabled'), SignInDoor.email)
          .failure,
      OnlineFailure.emailDisabled,
    );
    expect(
      translate(const AuthApiException('Invalid login credentials', code: 'invalid_credentials'), SignInDoor.email)
          .failure,
      OnlineFailure.wrongPassword,
    );
    expect(
      translate(const AuthApiException('User already registered', code: 'user_already_exists'), SignInDoor.email)
          .failure,
      OnlineFailure.wrongPassword,
    );
    expect(
      translate(AuthWeakPasswordException(message: 'weak', statusCode: '422', reasons: const ['length'])).failure,
      OnlineFailure.weakPassword,
    );
    expect(
      translate(const AuthApiException('Unable to validate email address: invalid format'), SignInDoor.email).failure,
      OnlineFailure.invalidEmail,
    );
  });

  test('un errore che non si conosce resta «qualcosa è andato storto», col suo motivo', () {
    final translated = translate(const AuthApiException('boom', statusCode: '500', code: 'unexpected_failure'));
    expect(translated.failure, OnlineFailure.unknown);
    expect(translated.reason, 'unexpected_failure · 500 · boom');
    expect(translate(StateError('strano')).reason, contains('strano'));
  });

  test('il database: nome preso o non valido', () {
    expect(translate(const PostgrestException(message: 'dup', code: '23505')).failure, OnlineFailure.handleTaken);
    expect(translate(const PostgrestException(message: 'check', code: '23514')).failure, OnlineFailure.invalidHandle);
    expect(translate(const PostgrestException(message: 'room_full')).failure, OnlineFailure.roomFull);
  });

  test('le segnalazioni: troppe di fila, o un motivo che il server non conosce', () {
    expect(translate(const PostgrestException(message: 'too_many_reports')).failure, OnlineFailure.tooManyReports);
    expect(translate(const PostgrestException(message: 'invalid_report')).failure, OnlineFailure.notAllowed);
  });
}
