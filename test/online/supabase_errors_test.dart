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

  test('l\'accesso con email: spento, indirizzo storto, codice, troppe mail, mail non partita', () {
    OnlineFailure email(AuthException error) => translate(error, SignInDoor.email).failure;
    expect(email(const AuthApiException('Email logins are disabled', code: 'email_provider_disabled')),
        OnlineFailure.emailDisabled);
    expect(email(const AuthApiException('Unable to validate email address: invalid format')), OnlineFailure.invalidEmail);
    expect(
      email(const AuthApiException('Token has expired or is invalid', statusCode: '403', code: 'otp_expired')),
      OnlineFailure.emailCodeWrong,
    );
    expect(
      email(const AuthApiException('For security purposes, you can only request this after 42 seconds.',
          statusCode: '429', code: 'over_email_send_rate_limit')),
      OnlineFailure.emailRateLimited,
    );
    expect(
      email(const AuthApiException('Error sending magic link email', statusCode: '500', code: 'unexpected_failure')),
      OnlineFailure.emailNotSent,
    );
    expect(email(const AuthApiException('Failed to reach hook', statusCode: '500', code: 'hook_timeout')),
        OnlineFailure.emailNotSent);
    expect(
      translate(const AuthApiException('slow down', statusCode: '429', code: 'over_request_rate_limit')).failure,
      OnlineFailure.unknown,
      reason: 'fuori dall\'email un 429 non è «troppe mail»',
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
