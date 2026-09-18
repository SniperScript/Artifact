import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/gmail/v1.dart' as gmail;

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

class GmailOracle {
  static final GmailOracle instance = GmailOracle._();
  GmailOracle._();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'https://www.googleapis.com/auth/gmail.send',
      'https://www.googleapis.com/auth/gmail.readonly'
    ],
  );

  // --- OMNI-VAULT TRANSMISSION ---
  Future<bool> transmitOmniVault(Map<String, String> masterVault, String userDesignation) async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return false;

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? token = auth.accessToken;
      if (token == null) return false;

      final authClient = GoogleAuthClient({'Authorization': 'Bearer $token'});
      final gmailApi = gmail.GmailApi(authClient);

      // Serialize the entire SharedPreferences state into one unbreakable payload
      String payload = json.encode(masterVault);

      StringBuffer body = StringBuffer();
      body.writeln("Greetings $userDesignation,\n");
      body.writeln("This is the secure Omni-Vault synchronization sequence. Do not alter the payload below.\n");
      body.writeln("---BEGIN OMNI-VAULT---");
      body.writeln(payload);
      body.writeln("---END OMNI-VAULT---\n");
      body.writeln("End of Transmission.\n- The Artifact");

      final String emailText = "Subject: Artifact Omni-Vault Sync [${DateTime.now().toIso8601String().split('T')[0]}]\n"
          "To: ${account.email}\n"
          "Content-Type: text/plain; charset=utf-8\n\n"
          "${body.toString()}";

      final String base64Email = base64UrlEncode(utf8.encode(emailText));
      final message = gmail.Message()..raw = base64Email;

      await gmailApi.users.messages.send(message, 'me');
      return true;
    } catch (e) {
      debugPrint("Gmail Oracle Transmission Error: $e");
      return false;
    }
  }

  // --- OMNI-VAULT RETRIEVAL ---
  Future<Map<String, String>?> retrieveOmniVault() async {
    try {
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null;

      final GoogleSignInAuthentication auth = await account.authentication;
      final String? token = auth.accessToken;
      if (token == null) return null;

      final authClient = GoogleAuthClient({'Authorization': 'Bearer $token'});
      final gmailApi = gmail.GmailApi(authClient);

      // Search the heavens for the exact vault signature
      final response = await gmailApi.users.messages.list('me', q: 'subject:"Artifact Omni-Vault Sync"');
      if (response.messages == null || response.messages!.isEmpty) return {}; // Return empty map if no backup exists

      // Fetch the absolute latest backup
      final latestMessageId = response.messages!.first.id!;
      final message = await gmailApi.users.messages.get('me', latestMessageId, format: 'full');

      // Extract and decode the text payload
      String decodedBody = _extractBody(message.payload);
      if (decodedBody.isEmpty) return null;

      // Extract the JSON payload bounded by our markers
      final startIndex = decodedBody.indexOf('---BEGIN OMNI-VAULT---');
      final endIndex = decodedBody.indexOf('---END OMNI-VAULT---');
      
      if (startIndex == -1 || endIndex == -1) return null; // Payload corrupted or tampered with

      String jsonPayload = decodedBody.substring(startIndex + 22, endIndex).trim();
      
      // Parse the JSON back into a string map
      Map<String, dynamic> rawMap = json.decode(jsonPayload);
      Map<String, String> recoveredVault = rawMap.map((key, value) => MapEntry(key, value.toString()));

      return recoveredVault;

    } catch (e) {
      debugPrint("Gmail Oracle Retrieval Error: $e");
      return null;
    }
  }

  // A spell to unwrap Google's nested email body structures
  String _extractBody(gmail.MessagePart? payload) {
    if (payload == null) return "";
    if (payload.body?.data != null) {
      String base64 = payload.body!.data!;
      while (base64.length % 4 != 0) { base64 += '='; } 
      return utf8.decode(base64Url.decode(base64));
    }
    if (payload.parts != null) {
      for (var part in payload.parts!) {
        if (part.mimeType == 'text/plain') {
          return _extractBody(part);
        }
      }
    }
    return "";
  }

  Future<void> severConnection() async {
    await _googleSignIn.signOut();
  }
}