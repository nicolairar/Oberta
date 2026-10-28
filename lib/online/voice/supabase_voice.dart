import 'package:supabase_flutter/supabase_flutter.dart';

import 'voice_models.dart';

/// I permessi della voce dall'Edge Function `voice-token`
/// (supabase/functions/voice-token): il token della sessione dice chi
/// chiede, il server guarda stanza e partita.
class SupabaseVoiceTokens implements VoiceTokenSource {
  final SupabaseClient _client;

  SupabaseVoiceTokens(this._client);

  @override
  Future<VoiceGrant> grant(String roomId) async {
    final FunctionResponse response;
    try {
      response = await _client.functions.invoke('voice-token', body: {'room': roomId});
    } on FunctionException catch (error) {
      throw VoiceRefused(_refusal(error.status, error.details));
    } catch (_) {
      throw const VoiceRefused(VoiceRefusal.network);
    }
    final data = response.data;
    if (response.status != 200 || data is! Map) throw VoiceRefused(_refusal(response.status, data));
    return VoiceGrant.fromJson(data.cast<String, Object?>());
  }

  static VoiceRefusal _refusal(int status, Object? details) {
    final error = details is Map ? details['error'] : null;
    return switch ((status, error)) {
      (403, 'not_member') => VoiceRefusal.notMember,
      (403, _) || (501, _) || (404, _) => VoiceRefusal.unavailable,
      _ => VoiceRefusal.network,
    };
  }
}
